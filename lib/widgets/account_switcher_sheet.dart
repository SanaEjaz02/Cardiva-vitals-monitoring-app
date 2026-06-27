import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/auth/auth_screen.dart';
import '../services/account_switcher_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opens a bottom sheet that lists all accounts saved on this device and
/// lets the user switch between them (GitHub-style multi-account switcher).
Future<void> showAccountSwitcherSheet(BuildContext context) async {
  final accounts = await AccountSwitcherService.getSavedAccounts();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SwitchAccountSheet(accounts: accounts),
  );
}

class _SwitchAccountSheet extends StatelessWidget {
  final List<SavedAccount> accounts;
  const _SwitchAccountSheet({required this.accounts});

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _doSwitch(BuildContext context, SavedAccount target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Switch to ${target.name}?', style: AppTextStyles.h2),
        content: Text(
          'You will be signed out of the current account and signed in to '
          '${target.email}.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AuthService.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(prefilledEmail: target.email),
      ),
      (_) => false,
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Another Account?', style: AppTextStyles.h2),
        content: Text(
          'You will be signed out of the current account. Sign in with your '
          'other account to add it to this device.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AuthService.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Accounts on this device', style: AppTextStyles.h2),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap an account to switch',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No saved accounts yet.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                ...accounts.map((acc) {
                  final isActive = acc.uid == uid;
                  return _AccountTile(
                    account: acc,
                    isActive: isActive,
                    onTap: isActive
                        ? null
                        : () => _doSwitch(context, acc),
                  );
                }),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 22),
                ),
                title: Text('Add Another Account', style: AppTextStyles.body),
                subtitle: Text(
                  'Sign in with a different ID',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.accentTint),
                onTap: () => _addAccount(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool isActive;
  final VoidCallback? onTap;

  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryBg
            : AppColors.bgLight,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: account.isGuardian
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.primaryDeep,
          child: Text(
            account.initials,
            style: TextStyle(
              color: account.isGuardian ? AppColors.success : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account.name.isNotEmpty ? account.name : account.email,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Active',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (account.name.isNotEmpty)
              Text(account.email,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: account.isGuardian
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.primaryBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                account.isGuardian ? 'Guardian' : 'Patient',
                style: AppTextStyles.caption.copyWith(
                  color: account.isGuardian
                      ? AppColors.success
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        trailing: isActive
            ? null
            : const Icon(Icons.swap_horiz_rounded,
                color: AppColors.accentTint, size: 20),
      ),
    );
  }
}
