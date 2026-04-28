import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryDeep,
                      child: Text(
                        'S',
                        style: AppTextStyles.h1White().copyWith(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Sarah Malik', style: AppTextStyles.h1),
                    Text('sarah@cardiva.app', style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () {},
                      child: Text('Edit Profile',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Stats strip
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
              // Group 1: Health & Safety
              _GroupCard(
                children: [
                  _ProfileRow(
                    icon: Icons.contacts_rounded,
                    label: 'Emergency Contacts',
                    badge: PillWidget('2', variant: PillVariant.primary),
                    onTap: () {},
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
                    onTap: () {},
                    last: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Group 2: Device & Account
              _GroupCard(
                children: [
                  _ProfileRow(
                    icon: Icons.watch_rounded,
                    label: 'Device Status',
                    badge: PillWidget('Connected', variant: PillVariant.success),
                    onTap: () {},
                  ),
                  _ProfileRow(
                    icon: Icons.download_outlined,
                    label: 'Health Report',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.weeklyReport),
                  ),
                  _ProfileRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {},
                  ),
                  _ProfileRow(
                    icon: Icons.feedback_outlined,
                    label: 'Feedback',
                    onTap: () {},
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
                    onTap: () => _confirmLogout(context),
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

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log out?', style: AppTextStyles.h2),
        content: Text(
            'You will be returned to the login screen.',
            style: AppTextStyles.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRouter.auth, (_) => false);
            },
            child: Text('Log Out',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

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
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
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
                    child: Icon(icon, color: AppColors.primary, size: 18),
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
                  if (badge != null) ...[badge!, const SizedBox(width: 8)],
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
