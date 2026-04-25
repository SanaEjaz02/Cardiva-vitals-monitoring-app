import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import 'chatbot/chatbot_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

class MainNavScreen extends ConsumerWidget {
  const MainNavScreen({super.key});

  static const _screens = [
    DashboardScreen(),
    HistoryScreen(),
    ChatbotScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_rounded),
      activeIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.history_rounded),
      activeIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      activeIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Assistant',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline_rounded),
      activeIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(_navIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: idx,
            onTap: (i) => ref.read(_navIndexProvider.notifier).state = i,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textHint,
            selectedLabelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(fontSize: 11),
            items: _items,
          ),
        ),
      ),
    );
  }
}
