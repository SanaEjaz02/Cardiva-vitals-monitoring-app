import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/validators.dart';
import '../../models/emergency_contact.dart';
import '../../providers/user_provider.dart';
import 'widgets/debug_panel.dart';
import 'widgets/emergency_contact_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverAppBar(
            backgroundColor: AppColors.primary,
            expandedHeight: 160,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primaryLightest,
                        child: Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.name ?? 'Demo User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // â”€â”€ Profile info card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                _SectionCard(
                  title: 'Personal Information',
                  action: TextButton.icon(
                    onPressed: () =>
                        _showEditProfileDialog(context, ref, user),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: Text('Edit',
                        style: TextStyle(fontSize: 12)),
                  ),
                  child: user == null
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            _InfoRow('Blood Group', user.bloodGroup),
                            _InfoRow('Gender', user.gender),
                            _InfoRow('Phone', user.phone),
                            _InfoRow(
                              'Date of Birth',
                              DateFormatter.date(user.dateOfBirth),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),

                // â”€â”€ Emergency contacts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                _SectionCard(
                  title: 'Emergency Contacts',
                  action: IconButton(
                    icon: const Icon(Icons.add_circle_rounded,
                        color: AppColors.primary),
                    onPressed: () =>
                        _showAddContactDialog(context, ref, user?.id),
                    tooltip: 'Add contact',
                  ),
                  child: contacts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No emergency contacts added yet.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textHint),
                          ),
                        )
                      : Column(
                          children: contacts
                              .map((c) => EmergencyContactTile(
                                    contact: c,
                                    onDelete: () => ref
                                        .read(emergencyContactsProvider
                                            .notifier)
                                        .remove(c.id),
                                    onSetPrimary: () => ref
                                        .read(emergencyContactsProvider
                                            .notifier)
                                        .setPrimary(c.id),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 14),

                // â”€â”€ Debug panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                const DebugPanel(),
                const SizedBox(height: 14),

                // â”€â”€ Sign out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text('Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emergency,
                    side: const BorderSide(color: AppColors.emergencyBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog(
      BuildContext context, WidgetRef ref, String? userId) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Emergency Contact',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(ctrl: nameCtrl, label: 'Name', hint: 'Full name'),
              const SizedBox(height: 10),
              _DialogField(
                ctrl: phoneCtrl,
                label: 'Phone',
                hint: '+1234567890',
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              const SizedBox(height: 10),
              _DialogField(
                ctrl: relCtrl,
                label: 'Relation',
                hint: 'e.g. Family, Friend',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(emergencyContactsProvider.notifier).add(
                    EmergencyContact(
                      id: const Uuid().v4(),
                      userId: userId ?? 'demo-user-001',
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      relation: relCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Add', style: TextStyle()),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, user) {
    // Simplified â€” just shows a snackbar for now;
    // a full edit form can be wired in Phase 11.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile editing coming soon.',
            style: TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(userProvider.notifier).clearUser();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (_) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out', style: TextStyle()),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? 'â€”' : value,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator ?? (v) => Validators.required(v, label),
        style: TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle:
              TextStyle(fontSize: 12, color: AppColors.textHint),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
