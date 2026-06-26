import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../router/app_router.dart';
import '../attendant/attendant_main_screen.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

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

  bool get _isGuardian =>
      ref.read(userProvider)?.role == UserRole.attendant;

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
      final uid = firebaseUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();
      final name = _nameCtrl.text.trim();

      final existingRole = ref.read(userProvider)?.role ?? UserRole.patient;
      final isGuardian = existingRole == UserRole.attendant;

      final profile = UserProfile(
        id: uid,
        name: name,
        email: firebaseUser?.email ?? '',
        phone: isGuardian ? _phoneCtrl.text.trim() : '',
        dateOfBirth: isGuardian ? DateTime(1990) : _dob!,
        gender: isGuardian ? 'Other' : (_gender ?? 'Other'),
        bloodGroup: isGuardian ? 'A+' : (_bloodType ?? 'A+'),
        heightCm: isGuardian ? 170.0 : (double.tryParse(_heightCtrl.text) ?? 170.0),
        weightKg: isGuardian ? 70.0 : (double.tryParse(_weightCtrl.text) ?? 70.0),
        role: existingRole,
      );
      // Update Firebase display name
      if (firebaseUser?.displayName != name) {
        await firebaseUser?.updateDisplayName(name);
      }
      // Save to Riverpod state
      ref.read(userProvider.notifier).setUser(profile);
      // Save locally first (instant)
      final profileJson = profile.toJson();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_$uid', jsonEncode(profileJson));
      // Await Firestore save — retries once if the first attempt fails
      try {
        await FirestoreService.saveProfile(profileJson);
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          await FirestoreService.saveProfile(profileJson);
        } catch (e) {
          debugPrint('[ProfileSetup] Firestore saveProfile failed after retry: $e');
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);

      // Guardians skip the device-pair and contact setup steps
      if (existingRole == UserRole.attendant) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AttendantMainScreen()),
          (_) => false,
        );
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushNamed(context, AppRouter.setupPair);
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
    final isGuardian = ref.watch(userProvider)?.role == UserRole.attendant;
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
                      child: StepIndicator(
                        current: 1,
                        total: isGuardian ? 2 : 3,
                      ),
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
                        isGuardian ? 'Set up your profile' : 'Tell us about yourself',
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isGuardian
                            ? 'Add your name and phone number so patients can identify you and you receive SMS alerts.'
                            : 'This helps us personalize your health thresholds.',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: AppColors.bgLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_outlined,
                                  color: AppColors.primary, size: 32),
                            ),
                            const SizedBox(height: 6),
                            Text('Add photo',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(hintText: 'Full name'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      // Guardian: phone only. Patient: full vitals form.
                      if (isGuardian) ...[
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Phone number (e.g. 3001234567)',
                            prefixText: '+92 ',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Required for emergency SMS alerts',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ] else ...[
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
