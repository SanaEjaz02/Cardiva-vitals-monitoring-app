import 'dart:convert';
import 'dart:io';
import '../../services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/alert_class.dart';
import '../../models/user_profile.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/local_chat_db.dart';

import 'feedback_sheet.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../widgets/account_switcher_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();

  /// Opens the edit-profile sheet from anywhere (e.g. the side panel).
  static Future<void> openEditSheet(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    final userProfile = ref.read(userProvider);
    // Capture the notifier NOW — synchronously, before any await or widget
    // disposal. The WidgetRef from the side panel becomes invalid once the
    // panel is popped, so using ref inside an async callback would silently
    // fail. UserNotifier itself outlives any widget.
    final notifier = ref.read(userProvider.notifier);
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final photoPath = prefs.getString('profile_photo_path_$uid');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(
        currentName: user?.displayName ?? 'Patient',
        currentPhotoPath: photoPath,
        currentProfile: userProfile,
        onSave: (name, path, updated) async {
          if (name.isNotEmpty && name != user?.displayName) {
            user?.updateDisplayName(name);
          }
          final p = await SharedPreferences.getInstance();
          final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
          if (path != null) {
            await p.setString('profile_photo_path_$uid', path);
          } else {
            await p.remove('profile_photo_path_$uid');
          }
          if (updated != null) {
            notifier.updateProfile(updated);
            FirestoreService.saveProfile(updated.toJson()).catchError((_) {});
            RealtimeDatabaseService.saveUserProfile(updated.toJson());
            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
            await p.setString('user_profile_$uid', jsonEncode(updated.toJson()));
            if (path != null) {
              StorageService.uploadProfilePhoto(File(path)).then((uploadedUrl) {
                if (uploadedUrl != null) {
                  final withPhoto = updated.copyWith(photoUrl: uploadedUrl);
                  notifier.updateProfile(withPhoto);
                  FirestoreService.saveProfile(withPhoto.toJson())
                      .catchError((_) {});
                  RealtimeDatabaseService.saveUserProfile(withPhoto.toJson());
                  p.setString(
                      'user_profile_$uid', jsonEncode(withPhoto.toJson()));
                }
              });
            }
          }
        },
      ),
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? get _user => AuthService.currentUser;
  String? _photoPath;
  List<Map<String, dynamic>> _guardians = [];
  String? _connectedDeviceName;

  String get _displayName => _user?.displayName ?? 'Patient';
  String get _email => _user?.email ?? '—';
  String get _initial =>
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P';

  String get _providerLabel {
    final ids =
        _user?.providerData.map((p) => p.providerId).toList() ?? [];
    if (ids.contains('google.com')) return 'Signed in with Google';
    if (ids.contains('apple.com')) return 'Signed in with Apple';
    return 'Signed in with Email';
  }

  IconData get _providerIcon {
    final ids =
        _user?.providerData.map((p) => p.providerId).toList() ?? [];
    if (ids.contains('google.com')) return Icons.g_mobiledata_rounded;
    if (ids.contains('apple.com')) return Icons.apple;
    return Icons.email_outlined;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    // Photo — scoped per user so profiles never share the same picture
    final path = prefs.getString('profile_photo_path_$uid');
    if (path != null && await File(path).exists() && mounted) {
      setState(() => _photoPath = path);
    }

    // Guardians — load directly from manual_guardians (what the patient saved)
    List<Map<String, dynamic>> guardians = [];
    try {
      final manuals = await FirestoreService.loadManualGuardians();
      if (manuals != null) {
        guardians = manuals
            .map((g) => {'name': (g['name'] as String?) ?? 'Guardian'})
            .toList();
      }
    } catch (_) {}

    // Connected BLE device name
    final deviceName = prefs.getString('ble_device_name');

    if (mounted) {
      setState(() {
        _guardians = guardians;
        _connectedDeviceName = deviceName;
      });
    }
  }

  void _showEditProfile() {
    final userProfile = ref.read(userProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProfileSheet(
        currentName: _displayName,
        currentPhotoPath: _photoPath,
        currentProfile: userProfile,
        onSave: (name, photoPath, updatedProfile) async {
          if (name.isNotEmpty && name != _user?.displayName) {
            _user?.updateDisplayName(name);
          }
          final prefs = await SharedPreferences.getInstance();
          final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
          if (photoPath != null) {
            await prefs.setString('profile_photo_path_$uid', photoPath);
          } else if (_photoPath != null && photoPath == null) {
            await prefs.remove('profile_photo_path_$uid');
          }
          if (mounted) setState(() => _photoPath = photoPath);
          if (updatedProfile != null) {
            // Update Riverpod state immediately so UI reflects changes at once
            ref.read(userProvider.notifier).updateProfile(updatedProfile);
            final json = updatedProfile.toJson();
            await prefs.setString('user_profile_$uid', jsonEncode(json));
            // Always sync to Firestore + RTDB so server data doesn't overwrite
            // local changes on the next app restart (_syncRtdb runs on every launch).
            FirestoreService.saveProfile(json).catchError((_) {});
            RealtimeDatabaseService.saveUserProfile(json);
            // Upload photo to Firebase Storage in background if a new one was picked
            if (photoPath != null) {
              StorageService.uploadProfilePhoto(File(photoPath))
                  .then((uploadedUrl) {
                if (uploadedUrl != null) {
                  final withPhoto =
                      updatedProfile.copyWith(photoUrl: uploadedUrl);
                  ref.read(userProvider.notifier).updateProfile(withPhoto);
                  final photoJson = withPhoto.toJson();
                  FirestoreService.saveProfile(photoJson).catchError((_) {});
                  RealtimeDatabaseService.saveUserProfile(photoJson);
                  prefs.setString(
                      'user_profile_$uid', jsonEncode(photoJson));
                }
              });
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;

    final progress = ValueNotifier<double>(0.0);
    final statusMsg = ValueNotifier<String>('Deleting your health data...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, pct, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever_rounded,
                        color: AppColors.danger, size: 36),
                    const SizedBox(height: 16),
                    Text('Deleting Account',
                        style: AppTextStyles.h2),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: AppColors.bgLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.danger),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${(pct * 100).toInt()}%',
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.danger)),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String>(
                      valueListenable: statusMsg,
                      builder: (_, msg, __) => Text(msg,
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Step 1 (0–50%): delete Firestore + RTDB data + local cache in parallel.
    statusMsg.value = 'Deleting your health data...';
    await Future.wait([
      FirestoreService.deleteAccount()
          .timeout(const Duration(seconds: 8))
          .catchError((_) => null),
      RealtimeDatabaseService.deleteUserData()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {}),
      SharedPreferences.getInstance()
          .then((p) => p.clear())
          .catchError((_) => false),
    ]);
    progress.value = 0.5;

    // Step 2 (50–70%): clear in-memory state
    statusMsg.value = 'Clearing local data...';
    if (mounted) ref.read(userProvider.notifier).clearUser();
    await Future.delayed(const Duration(milliseconds: 300));
    progress.value = 0.7;

    // Step 3 (70–90%): delete Firebase Auth user
    statusMsg.value = 'Removing your account...';
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final providers =
          user.providerData.map((p) => p.providerId).toList();
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          try {
            if (providers.contains('google.com')) {
              final googleSignIn = GoogleSignIn();
              final googleUser = await googleSignIn.signInSilently() ??
                  await googleSignIn.signIn();
              if (googleUser != null) {
                final auth = await googleUser.authentication;
                final credential = GoogleAuthProvider.credential(
                  accessToken: auth.accessToken,
                  idToken: auth.idToken,
                );
                await user.reauthenticateWithCredential(credential);
                await user.delete();
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    progress.value = 0.9;

    // Step 4 (90–100%): sign out
    statusMsg.value = 'Signing out...';
    try {
      await LocalChatDb.instance.clearAll();
      await AuthService.signOut();
    } catch (_) {}
    progress.value = 1.0;
    statusMsg.value = 'Done!';

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRouter.auth, (_) => false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Account?', style: AppTextStyles.h2),
        content: Text(
          'This will permanently delete your account and all health data. This cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: Text('Delete Forever',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text('Log out?', style: AppTextStyles.h2),
        content: Text(
          'You will be returned to the login screen.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocalChatDb.instance.clearAll();
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRouter.auth, (_) => false);
              }
            },
            child: Text('Log Out',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    // Network photo: uploaded URL > Google sign-in photo
    final networkPhoto =
        userProfile?.photoUrl ?? _user?.photoURL;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // ── Avatar + name ──────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showEditProfile,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primaryDeep,
                            backgroundImage: _photoPath != null
                                ? FileImage(File(_photoPath!))
                                    as ImageProvider
                                : networkPhoto != null
                                    ? NetworkImage(networkPhoto)
                                    : null,
                            child: _photoPath == null && networkPhoto == null
                                ? Text(
                                    _initial,
                                    style: AppTextStyles.h1White()
                                        .copyWith(fontSize: 34),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_displayName, style: AppTextStyles.h1),
                    const SizedBox(height: 2),
                    Text(_email, style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    // Provider badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_providerIcon,
                              color: AppColors.primary, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            _providerLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _showEditProfile,
                      child: Text(
                        'Edit Profile',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Stats strip ────────────────────────────────────────
              Builder(builder: (_) {
                final records = ref.watch(analysisHistoryProvider);
                final daysMonitored = records
                    .map((r) =>
                        '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}')
                    .toSet()
                    .length;
                final alertsSent = records
                    .where((r) =>
                        r.prediction.alertClass == AlertClass.emergency ||
                        r.prediction.alertClass == AlertClass.fallAlert ||
                        r.prediction.alertClass == AlertClass.vitalsAlert)
                    .length;
                final avgScore = records.isEmpty
                    ? 0
                    : buildSummaryFromRecords(records).healthScore;
                return Row(
                  children: [
                    _StatCard(
                        label: 'Days Monitored',
                        value: '$daysMonitored'),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Alerts Sent', value: '$alertsSent'),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Avg Score', value: '$avgScore'),
                  ],
                );
              }),
              const SizedBox(height: 24),
              // ── Health & Safety ────────────────────────────────────
              _GroupCard(
                children: [
                  _ProfileRow(
                    icon: Icons.people_rounded,
                    label: 'Guardians',
                    badge: PillWidget('${_guardians.length}',
                        variant: PillVariant.primary),
                    onTap: () async {
                      await Navigator.pushNamed(
                          context, AppRouter.settingsAttendants);
                      if (mounted) _loadData();
                    },
                  ),
                  if (_guardians.isNotEmpty)
                    _GuardianSubList(guardians: _guardians),
                  _ProfileRow(
                    icon: Icons.tune_rounded,
                    label: 'Threshold Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.settings),
                  ),
                  _ProfileRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notification Preferences',
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.notificationPrefs),
                    last: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Device & Account ───────────────────────────────────
              _GroupCard(
                children: [
                  _ProfileRow(
                    icon: Icons.watch_rounded,
                    label: 'Device Connection',
                    badge: _connectedDeviceName != null
                        ? const PillWidget('Connected',
                            variant: PillVariant.success)
                        : const PillWidget('Disconnected',
                            variant: PillVariant.outline),
                    onTap: () async {
                      await Navigator.pushNamed(
                          context, AppRouter.deviceConnect);
                      if (mounted) _loadData();
                    },
                  ),
                  _ProfileRow(
                    icon: Icons.download_outlined,
                    label: 'Health Report',
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.weeklyReport),
                  ),
                  _ProfileRow(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Edit Profile',
                    onTap: _showEditProfile,
                  ),
                  _ProfileRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.helpSupport),
                  ),
                  _ProfileRow(
                    icon: Icons.rate_review_rounded,
                    label: 'Send Feedback',
                    onTap: () => showFeedbackSheet(context),
                  ),
                  _ProfileRow(
                    icon: Icons.settings_outlined,
                    label: 'Settings & Privacy',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.settings),
                  ),
                  _ProfileRow(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Switch Account',
                    onTap: () => showAccountSwitcherSheet(context),
                  ),
                  _ProfileRow(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    labelColor: AppColors.danger,
                    onTap: _confirmLogout,
                    showChevron: false,
                  ),
                  _ProfileRow(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete Account',
                    labelColor: AppColors.danger,
                    onTap: _confirmDeleteAccount,
                    last: true,
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit profile bottom sheet ──────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String? currentPhotoPath;
  final UserProfile? currentProfile;
  final Future<void> Function(String name, String? photoPath, UserProfile? profile) onSave;

  const _EditProfileSheet({
    required this.currentName,
    required this.currentPhotoPath,
    required this.onSave,
    this.currentProfile,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  String? _photoPath;
  bool _saving = false;
  bool _photoRemoved = false;

  String _gender = 'Male';
  String _bloodGroup = 'A+';
  DateTime? _dob;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    _nameCtrl = TextEditingController(text: widget.currentName);
    _heightCtrl = TextEditingController(
        text: p != null ? p.heightCm.toStringAsFixed(0) : '170');
    _weightCtrl = TextEditingController(
        text: p != null ? p.weightKg.toStringAsFixed(1) : '70.0');
    _photoPath = widget.currentPhotoPath;
    _gender = p?.gender.isNotEmpty == true ? p!.gender : 'Male';
    _bloodGroup = p?.bloodGroup.isNotEmpty == true ? p!.bloodGroup : 'A+';
    _dob = p?.dateOfBirth;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String get _initial => widget.currentName.isNotEmpty
      ? widget.currentName[0].toUpperCase()
      : 'P';

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String get _dobLabel {
    if (_dob == null) return 'Select date of birth';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${_dob!.day} ${months[_dob!.month - 1]} ${_dob!.year}';
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.primaryBg, shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary, size: 18),
              ),
              title: Text('Choose from Gallery',
                  style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.primaryBg, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary, size: 18),
              ),
              title: Text('Take a Photo', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: AppColors.dangerBg, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 18),
                ),
                title: Text('Remove Photo',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _photoPath = null;
                    _photoRemoved = true;
                  });
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = '${appDir.path}/$fileName';
    await File(picked.path).copy(destPath);

    if (mounted) {
      setState(() {
        _photoPath = destPath;
        _photoRemoved = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Profile', style: AppTextStyles.h2),
          const SizedBox(height: 24),

          // ── Avatar with camera overlay ─────────────────────────────
          GestureDetector(
            onTap: _showSourcePicker,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.primaryDeep,
                  backgroundImage:
                      _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null
                      ? Text(_initial,
                          style:
                              AppTextStyles.h1White().copyWith(fontSize: 36))
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Tap to change photo', style: AppTextStyles.caption),
          const SizedBox(height: 20),

          // ── Name ─────────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Display name',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textSecondary),
              labelStyle: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),

          // ── Height & Weight ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: const Icon(Icons.height_rounded,
                        color: AppColors.textSecondary),
                    labelStyle: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: const Icon(Icons.monitor_weight_outlined,
                        color: AppColors.textSecondary),
                    labelStyle: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Date of Birth ─────────────────────────────────────────
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(_dobLabel,
                      style: AppTextStyles.body.copyWith(
                        color: _dob == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Gender ────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue: _genders.contains(_gender) ? _gender : _genders.first,
            decoration: InputDecoration(
              labelText: 'Gender',
              prefixIcon: const Icon(Icons.wc_rounded,
                  color: AppColors.textSecondary),
              labelStyle: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            items: _genders
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v ?? _gender),
          ),
          const SizedBox(height: 14),

          // ── Blood Group ───────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue: _bloodGroups.contains(_bloodGroup)
                ? _bloodGroup
                : _bloodGroups.first,
            decoration: InputDecoration(
              labelText: 'Blood Group',
              prefixIcon: const Icon(Icons.bloodtype_outlined,
                  color: AppColors.textSecondary),
              labelStyle: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            items: _bloodGroups
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bloodGroup = v ?? _bloodGroup),
          ),
          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _saving = true);
                          final resultPath = _photoRemoved ? null : _photoPath;
                          final nav = Navigator.of(context);
                          final existing = widget.currentProfile;
                          final heightCm =
                              double.tryParse(_heightCtrl.text) ??
                                  existing?.heightCm ?? 170.0;
                          final weightKg =
                              double.tryParse(_weightCtrl.text) ??
                                  existing?.weightKg ?? 70.0;
                          // Use copyWith so role, monitoredPatientId,
                          // bandId, photoUrl are preserved from existing profile.
                          final updated = existing != null
                              ? existing.copyWith(
                                  name: _nameCtrl.text.trim(),
                                  dateOfBirth: _dob ?? existing.dateOfBirth,
                                  gender: _gender,
                                  bloodGroup: _bloodGroup,
                                  heightCm: heightCm,
                                  weightKg: weightKg,
                                )
                              : UserProfile(
                                  id: 'guest',
                                  name: _nameCtrl.text.trim(),
                                  email: '',
                                  phone: '',
                                  dateOfBirth: _dob ?? DateTime(1990),
                                  gender: _gender,
                                  bloodGroup: _bloodGroup,
                                  heightCm: heightCm,
                                  weightKg: weightKg,
                                );
                          // Close immediately — onSave runs in background
                          nav.pop();
                          widget.onSave(
                              _nameCtrl.text.trim(), resultPath, updated);
                        },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowSm,
                blurRadius: 12,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(label,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 12,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool last;
  final bool showChevron;

  const _ProfileRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.badge,
    this.onTap,
    this.last = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBg,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(icon, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: labelColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    badge!,
                    const SizedBox(width: 8)
                  ],
                  if (showChevron)
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (!last)
          const Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

class _GuardianSubList extends StatelessWidget {
  final List<Map<String, dynamic>> guardians;
  const _GuardianSubList({required this.guardians});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: guardians.map((g) {
          final name = (g['name'] as String?) ?? 'Guardian';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: AppTextStyles.body)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Saved',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
