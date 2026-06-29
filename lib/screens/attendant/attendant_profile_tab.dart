import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/account_switcher_sheet.dart';
import '../auth/auth_screen.dart';
import '../profile/feedback_sheet.dart';

class AttendantProfileTab extends ConsumerStatefulWidget {
  const AttendantProfileTab({super.key});

  @override
  ConsumerState<AttendantProfileTab> createState() =>
      _AttendantProfileTabState();
}

class _AttendantProfileTabState extends ConsumerState<AttendantProfileTab> {
  bool _deleting = false;

  Future<void> _showEditProfile() async {
    final profile = ref.read(userProvider);
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final phoneCtrl = TextEditingController(text: profile?.phone ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        onSave: () async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          final current = ref.read(userProvider);
          if (current == null) return;
          final updated = current.copyWith(
            name: name,
            phone: phoneCtrl.text.trim(),
          );
          ref.read(userProvider.notifier).updateProfile(updated);
          final json = updated.toJson();
          try {
            await FirestoreService.saveProfile(json)
                .timeout(const Duration(seconds: 8));
          } catch (_) {}
          RealtimeDatabaseService.saveUserProfile(json);
          AuthService.currentUser?.updateDisplayName(name).catchError((_) {});
        },
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign out?', style: AppTextStyles.h2),
        content: Text(
          'You will need to sign in again to access the guardian portal.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(userProvider.notifier).clearUser();
    await LocalChatDb.instance.clearAll();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account?', style: AppTextStyles.h2),
        content: Text(
          'This permanently deletes your account and all linked data. This cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await FirestoreService.deleteAccount();
      await RealtimeDatabaseService.deleteUserData();
      ref.read(userProvider.notifier).clearUser();
      await AuthService.currentUser?.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProvider);
    final name = profile?.name ?? '';
    final email =
        FirebaseAuth.instance.currentUser?.email ?? profile?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';

    if (_deleting) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // ── Avatar ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        AppColors.success.withValues(alpha: 0.12),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name.isEmpty ? 'Set your name' : name,
                    style: AppTextStyles.h1.copyWith(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services_rounded,
                            color: AppColors.success, size: 13),
                        SizedBox(width: 6),
                        Text(
                          'Guardian',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // ── Menu list ─────────────────────────────────────────────
            _GuardianGroup(
              children: [
                _GuardianRow(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Edit Profile',
                  onTap: _showEditProfile,
                ),
                _GuardianRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.helpSupport),
                ),
                _GuardianRow(
                  icon: Icons.rate_review_rounded,
                  label: 'Send Feedback',
                  onTap: () => showFeedbackSheet(context),
                ),
                _GuardianRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Switch Account',
                  onTap: () => showAccountSwitcherSheet(context),
                ),
                _GuardianRow(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  labelColor: AppColors.danger,
                  onTap: _confirmLogout,
                  showChevron: false,
                ),
                _GuardianRow(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete Account',
                  labelColor: AppColors.danger,
                  onTap: _confirmDeleteAccount,
                  showChevron: false,
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped card container ────────────────────────────────────────────────────

class _GuardianGroup extends StatelessWidget {
  final List<Widget> children;
  const _GuardianGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowLg,
              blurRadius: 12,
              offset: Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ── Single list row ───────────────────────────────────────────────────────────

class _GuardianRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool showChevron;
  final bool last;

  const _GuardianRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showChevron = true,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? AppColors.textPrimary;
    final iconBgColor = labelColor ?? AppColors.primary;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: last
              ? const BorderRadius.vertical(bottom: Radius.circular(18))
              : BorderRadius.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: iconBgColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                        color: color, fontWeight: FontWeight.w500),
                  ),
                ),
                if (showChevron)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.accentTint, size: 20),
              ],
            ),
          ),
        ),
        if (!last)
          const Divider(height: 1, indent: 70, color: AppColors.divider),
      ],
    );
  }
}

// ── Edit profile bottom sheet ─────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final Future<void> Function() onSave;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Profile',
              style: AppTextStyles.h2
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 20),
          TextField(
            controller: widget.nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.primary, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.primary, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSave();
                      if (context.mounted) Navigator.pop(context);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      'Save Changes',
                      style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
