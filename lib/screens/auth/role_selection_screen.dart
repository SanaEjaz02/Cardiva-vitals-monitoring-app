import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../attendant/attendant_main_screen.dart';
import '../main_nav_screen.dart';
import '../setup/profile_setup_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  /// If true, this is shown after initial registration (go to profile setup next).
  /// If false, shown to an existing user who hasn't set a role yet (go to home).
  final bool isNewUser;

  /// Pre-selects the role the user chose on the login screen (cosmetic only).
  final UserRole? preselected;

  const RoleSelectionScreen({
    super.key,
    this.isNewUser = true,
    this.preselected,
  });

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselected;
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() => _saving = true);

    final roleStr = _selected == UserRole.attendant ? 'attendant' : 'patient';
    final fbUser = FirebaseAuth.instance.currentUser;
    final fbUid = fbUser?.uid;
    final fbEmail = fbUser?.email ?? '';

    final profile = ref.read(userProvider);
    if (profile != null) {
      final updated = profile.copyWith(role: _selected);
      ref.read(userProvider.notifier).updateProfile(updated);
      RealtimeDatabaseService.saveUserProfile(updated.toJson(), uid: fbUid);
      FirestoreService.saveProfile(updated.toJson(), uid: fbUid).catchError((_) {});
    } else {
      final stub = UserProfile(
        id: fbUid ?? '',
        name: fbUser?.displayName ?? '',
        email: fbEmail,
        phone: '',
        dateOfBirth: DateTime(1990),
        gender: '',
        bloodGroup: '',
        heightCm: 0,
        weightKg: 0,
        role: _selected!,
      );
      ref.read(userProvider.notifier).setUser(stub);
      RealtimeDatabaseService.saveUserProfile(stub.toJson(), uid: fbUid);
      FirestoreService.saveRole(roleStr, uid: fbUid).catchError((_) {});
    }

    if (!mounted) return;

    if (_selected == UserRole.attendant) {
      if (widget.isNewUser) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              role: _selected,
              uid: fbUid,
              email: fbEmail,
            ),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AttendantMainScreen()),
          (_) => false,
        );
      }
    } else if (widget.isNewUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            role: _selected,
            uid: fbUid,
            email: fbEmail,
          ),
        ),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroCard,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_heart_outlined,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Cardiva', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 40),
              Text('Who are you?', style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                'Are you monitoring your own health (Patient) or someone else\'s (Guardian)?',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // Patient card
              _RoleCard(
                selected: _selected == UserRole.patient,
                icon: Icons.favorite_rounded,
                title: 'I am a Patient',
                subtitle:
                    'Monitor my own heart health, receive AI analysis and send emergency alerts to my guardian.',
                color: AppColors.primary,
                onTap: () => setState(() => _selected = UserRole.patient),
              ),
              const SizedBox(height: 16),

              // Attendant card
              _RoleCard(
                selected: _selected == UserRole.attendant,
                icon: Icons.medical_services_rounded,
                title: 'I am a Guardian',
                subtitle:
                    'Monitor assigned patients\' health dashboards and receive emergency alerts instantly.',
                color: AppColors.success,
                onTap: () => setState(() => _selected = UserRole.attendant),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selected == null || _saving) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.divider,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  const BoxShadow(
                    color: AppColors.shadowLg,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.h2.copyWith(
                          color: selected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
