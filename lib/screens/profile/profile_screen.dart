import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => AuthService.currentUser;
  String? _photoPath;

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
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_photo_path');
    if (path != null && await File(path).exists() && mounted) {
      setState(() => _photoPath = path);
    }
  }

  void _showEditProfile() {
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
        onSave: (name, photoPath) async {
          if (name.isNotEmpty && name != _user?.displayName) {
            await _user?.updateDisplayName(name);
          }
          final prefs = await SharedPreferences.getInstance();
          if (photoPath != null) {
            await prefs.setString('profile_photo_path', photoPath);
          } else if (_photoPath != null && photoPath == null) {
            await prefs.remove('profile_photo_path');
          }
          if (mounted) setState(() => _photoPath = photoPath);
        },
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
                                : null,
                            child: _photoPath == null
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
                                AppColors.primary.withOpacity(0.25)),
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
              Row(
                children: [
                  _StatCard(label: 'Days Monitored', value: '47'),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Alerts Sent', value: '3'),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Avg Score', value: '91'),
                ],
              ),
              const SizedBox(height: 24),
              // ── Health & Safety ────────────────────────────────────
              _GroupCard(
                children: [
                  _ProfileRow(
                    icon: Icons.contacts_rounded,
                    label: 'Emergency Contacts',
                    badge: PillWidget('2', variant: PillVariant.primary),
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.emergencyContacts),
                  ),
                  _ProfileRow(
                    icon: Icons.people_rounded,
                    label: 'Attendants',
                    badge: PillWidget('1', variant: PillVariant.primary),
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.settingsAttendants),
                  ),
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
                    label: 'Device Status',
                    badge:
                        PillWidget('Connected', variant: PillVariant.success),
                    onTap: () {},
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
                    icon: Icons.settings_outlined,
                    label: 'Settings & Privacy',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.settings),
                  ),
                  _ProfileRow(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    labelColor: AppColors.danger,
                    onTap: _confirmLogout,
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
  final Future<void> Function(String name, String? photoPath) onSave;

  const _EditProfileSheet({
    required this.currentName,
    required this.currentPhotoPath,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  String? _photoPath;
  bool _saving = false;
  // Track if the user explicitly removed the photo
  bool _photoRemoved = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _photoPath = widget.currentPhotoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _initial => widget.currentName.isNotEmpty
      ? widget.currentName[0].toUpperCase()
      : 'P';

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

          // ── Name field ────────────────────────────────────────────
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
                      : () async {
                          setState(() => _saving = true);
                          final resultPath =
                              _photoRemoved ? null : _photoPath;
                          await widget.onSave(
                              _nameCtrl.text.trim(), resultPath);
                          if (mounted) Navigator.pop(context);
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
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
