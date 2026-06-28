import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'attendant_dashboard_tab.dart';
import 'attendant_chat_list_tab.dart';
import 'attendant_alert_history_tab.dart';
import 'attendant_profile_tab.dart';

final _guardianChatUnreadProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return ChatService.totalUnreadStream(uid);
});

class AttendantMainScreen extends ConsumerStatefulWidget {
  const AttendantMainScreen({super.key});

  @override
  ConsumerState<AttendantMainScreen> createState() =>
      _AttendantMainScreenState();
}

class _AttendantMainScreenState extends ConsumerState<AttendantMainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabConfig(
      icon: Icons.monitor_heart_outlined,
      activeIcon: Icons.monitor_heart_rounded,
      label: 'Patients',
    ),
    _TabConfig(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    _TabConfig(
      icon: Icons.warning_amber_rounded,
      activeIcon: Icons.warning_rounded,
      label: 'Alerts',
    ),
    _TabConfig(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  static const _pages = [
    AttendantDashboardTab(),
    AttendantChatListTab(),
    AttendantAlertHistoryTab(),
    AttendantProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // After first frame, check if guardian has set their name (mandatory).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfile());
  }

  void _checkProfile() {
    if (!mounted) return;
    final profile = ref.read(userProvider);
    // If profile is null or name empty, navigate to profile tab immediately
    if (profile == null || profile.name.trim().isEmpty) {
      setState(() => _currentIndex = 3); // Profile tab
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please set your name so patients can identify you.'),
          duration: Duration(seconds: 4),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show in-app banner when a new message arrives and guardian is not on the Messages tab.
    // Skip the initial emission to avoid spurious alerts on login.
    ref.listen<AsyncValue<int>>(_guardianChatUnreadProvider, (previous, next) {
      if (previous == null) return;
      final prev = previous.valueOrNull ?? 0;
      final curr = next.valueOrNull ?? 0;
      if (curr > prev && _currentIndex != 1 && mounted) {
        NotificationService.showChatNotification(
          'New Message',
          'You have a new message from your patient',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text('New message from your patient',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white70,
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            backgroundColor: AppColors.primaryDeep,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FC),
      appBar: null, // All tabs manage their own headers
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _AttendantBottomNav(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) => setState(() => _currentIndex = i),
        messageBadge:
            ref.watch(_guardianChatUnreadProvider).valueOrNull ?? 0,
      ),
    );
  }
}

class _TabConfig {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabConfig(
      {required this.icon, required this.activeIcon, required this.label});
}

class _AttendantBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_TabConfig> tabs;
  final ValueChanged<int> onTap;
  final int messageBadge;

  const _AttendantBottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    this.messageBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLg,
              blurRadius: 16,
              offset: Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final t = tabs[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            active ? t.activeIcon : t.icon,
                            color: active
                                ? AppColors.primary
                                : AppColors.accentTint,
                            size: 24,
                          ),
                          if (i == 1 && messageBadge > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  messageBadge > 99
                                      ? '99+'
                                      : '$messageBadge',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.label,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: active
                              ? AppColors.primary
                              : AppColors.accentTint,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (active)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 20,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
