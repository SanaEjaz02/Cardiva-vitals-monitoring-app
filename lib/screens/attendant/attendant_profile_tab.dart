import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../auth/auth_screen.dart';

class AttendantProfileTab extends ConsumerStatefulWidget {
  const AttendantProfileTab({super.key});

  @override
  ConsumerState<AttendantProfileTab> createState() =>
      _AttendantProfileTabState();
}

class _AttendantProfileTabState extends ConsumerState<AttendantProfileTab> {
  bool _editMode = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProvider);
    _nameCtrl = TextEditingController(text: profile?.name ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = ref.read(userProvider);
      if (profile != null) {
        final updated = profile.copyWith(
          name: name,
          phone: _phoneCtrl.text.trim(),
        );
        ref.read(userProvider.notifier).updateProfile(updated);
        // Both saves are fire-and-forget — UI doesn't wait for server.
        FirestoreService.saveProfile(updated.toJson()).catchError((_) {});
        RealtimeDatabaseService.saveUserProfile(updated.toJson()).catchError((_) {});
        AuthService.currentUser?.updateDisplayName(name).catchError((_) {});
      }
      if (mounted) setState(() => _editMode = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.read(userProvider.notifier).clearUser();
    await AuthService.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProvider);
    final email = AuthService.currentUser?.email ?? profile?.email ?? '';
    final name = profile?.name ?? '';
    final phone = profile?.phone ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'Set your name' : name,
                  style: AppTextStyles.h1.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services_rounded,
                          color: AppColors.success, size: 12),
                      SizedBox(width: 6),
                      Text('Guardian',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Profile card
          _SectionCard(
            title: 'My Profile',
            trailing: _editMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: AppColors.primary, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => setState(() => _editMode = true),
                  ),
            children: _editMode
                ? [
                    _EditField(
                      label: 'Full Name *',
                      ctrl: _nameCtrl,
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                      label: 'Phone Number',
                      ctrl: _phoneCtrl,
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _editMode = false),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.accentTint),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Name',
                        value: name.isEmpty ? 'Not set' : name),
                    const Divider(color: AppColors.divider, height: 1),
                    _InfoRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: email.isEmpty ? 'Not set' : email),
                    const Divider(color: AppColors.divider, height: 1),
                    _InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: phone.isEmpty ? 'Not set' : phone),
                  ],
          ),
          const SizedBox(height: 12),

          // Info card — how emergency alerts work
          _SectionCard(
            title: 'Emergency Alerts',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'When a patient emergency is detected, you will receive an in-app message immediately. '
                        'Make sure your phone number is set above so you also receive an SMS alert.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No phone number set — you won\'t receive SMS alerts.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Sign out
          _SectionCard(
            title: 'Account',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: AppColors.danger, size: 18),
                ),
                title: Text('Sign Out', style: AppTextStyles.body),
                subtitle: Text('You will need to sign in again.',
                    style: AppTextStyles.caption),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowLg, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.8)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.caption
                      .copyWith(fontSize: 10, color: AppColors.textSecondary)),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboardType;

  const _EditField({
    required this.label,
    required this.ctrl,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.bgLight.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
