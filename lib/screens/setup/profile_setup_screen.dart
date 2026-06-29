import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../router/app_router.dart';
import '../attendant/attendant_main_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Passed explicitly from auth_screen so the role is never lost
  /// even if the Riverpod state gets reset between screens.
  final UserRole? role;
  /// Passed explicitly so uid is always correct (Infinix auth delay workaround).
  final String? uid;
  final String? email;

  const ProfileSetupScreen({super.key, this.role, this.uid, this.email});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  String? _gender;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodType;

  bool _saving = false;

  // Cached at initState so Riverpod state changes can never alter the role.
  late final UserRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.role ?? UserRole.patient;
    debugPrint('[ProfileSetup] initState role=${_role.name} widget.role=${widget.role?.name}');
  }

  bool get _isGuardian => _role == UserRole.attendant;

  bool get _isValid {
    if (_isGuardian) return _nameCtrl.text.isNotEmpty;
    return _nameCtrl.text.isNotEmpty &&
        _dob != null &&
        _gender != null &&
        _heightCtrl.text.isNotEmpty &&
        _weightCtrl.text.isNotEmpty &&
        _bloodType != null;
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      // Prefer: Firebase Auth uid → widget param → Riverpod id.
      // On Infinix, Firebase Auth currentUser can be null briefly after sign-up.
      final riverpodId = ref.read(userProvider)?.id;
      final uid = firebaseUser?.uid
          ?? widget.uid
          ?? riverpodId
          ?? DateTime.now().millisecondsSinceEpoch.toString();
      final email = firebaseUser?.email
          ?? widget.email
          ?? ref.read(userProvider)?.email
          ?? '';
      final name = _nameCtrl.text.trim();
      debugPrint('[ProfileSetup] _submit uid=$uid role=${_role.name}');

      final profile = UserProfile(
        id: uid,
        name: name,
        email: email,
        phone: _phoneCtrl.text.trim(),
        dateOfBirth: _isGuardian ? DateTime(1990) : _dob!,
        gender: _isGuardian ? '' : (_gender ?? ''),
        bloodGroup: _isGuardian ? '' : (_bloodType ?? ''),
        heightCm: _isGuardian ? 0 : (double.tryParse(_heightCtrl.text) ?? 170.0),
        weightKg: _isGuardian ? 0 : (double.tryParse(_weightCtrl.text) ?? 70.0),
        role: _role,
      );

      if (firebaseUser?.displayName != name) {
        firebaseUser?.updateDisplayName(name).catchError((_) {});
      }

      ref.read(userProvider.notifier).setUser(profile);

      final profileJson = profile.toJson();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_$uid', jsonEncode(profileJson));

      // RTDB — pass uid explicitly (auth can be null on Infinix).
      RealtimeDatabaseService.saveUserProfile(profileJson, uid: uid);
      if (email.isNotEmpty) {
        RealtimeDatabaseService.saveEmailIndex(email).catchError((_) {});
      }

      // Firestore — AWAIT so the write commits before we navigate.
      // This is safe with offline persistence — the SDK writes to local disk
      // first and resolves immediately; server sync happens in background.
      try {
        await FirestoreService.saveProfile(profileJson, uid: uid)
            .timeout(const Duration(seconds: 8));
        debugPrint('[ProfileSetup] Firestore ✅ saved for $uid');
      } catch (e) {
        // Log the error but do NOT block navigation — offline persistence
        // will retry the write when the connection is restored.
        debugPrint('[ProfileSetup] Firestore ERROR (will retry offline): $e');
      }

      if (!mounted) return;

      debugPrint('[ProfileSetup] navigating → role=${_role.name}');
      if (_role == UserRole.attendant) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AttendantMainScreen()),
          (_) => false,
        );
        return;
      }
      Navigator.pushNamed(context, AppRouter.setupPair);
    } catch (e) {
      debugPrint('[ProfileSetup] _submit error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = _isGuardian;
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: isGuardian
                        ? const SizedBox.shrink()
                        : StepIndicator(current: 1, total: 3),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tell us about yourself',
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isGuardian
                            ? 'This helps personalize your guardian profile.'
                            : 'This helps us personalize your health thresholds.',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(hintText: 'Full name'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      // Phone — shown for both roles
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'Phone number (optional)'),
                      ),
                      // Health fields — patients only
                      if (!isGuardian) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickDob,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cake_outlined,
                                    color: AppColors.textSecondary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _dob == null
                                      ? 'Date of birth'
                                      : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                                  style: AppTextStyles.body.copyWith(
                                    color: _dob == null
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.expand_more_rounded,
                                    color: AppColors.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Gender', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        Row(
                          children: ['Male', 'Female', 'Other'].map((g) {
                            final selected = _gender == g;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _gender = g),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.accentTint,
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: AppTextStyles.body.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    hintText: 'Height (cm)'),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _weightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    hintText: 'Weight (kg)'),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _bloodType,
                          hint: Text('Blood type',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary)),
                          decoration: const InputDecoration(),
                          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t, style: AppTextStyles.body),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _bloodType = v),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isGuardian ? 'Continue' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
