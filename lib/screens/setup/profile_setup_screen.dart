import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../router/app_router.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime? _dob;
  String? _gender;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _bloodType;

  bool get _isValid =>
      _nameCtrl.text.isNotEmpty &&
      _dob != null &&
      _gender != null &&
      _heightCtrl.text.isNotEmpty &&
      _weightCtrl.text.isNotEmpty &&
      _bloodType != null;

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
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(child: StepIndicator(current: 1, total: 3)),
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
                      Text('Tell us about yourself', style: AppTextStyles.h1),
                      const SizedBox(height: 6),
                      Text(
                        'This helps us personalize your health thresholds.',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      // Avatar
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
                      // DOB
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
                      // Gender chips
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
                              decoration:
                                  const InputDecoration(hintText: 'Height (cm)'),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _weightCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: 'Weight (kg)'),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Blood type dropdown
                      DropdownButtonFormField<String>(
                        value: _bloodType,
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // Next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid
                      ? () => Navigator.pushNamed(context, AppRouter.setupPair)
                      : null,
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
