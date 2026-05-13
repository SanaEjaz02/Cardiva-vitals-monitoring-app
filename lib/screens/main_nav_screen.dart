import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/atoms/bottom_nav_bar.dart';
import '../widgets/atoms/cardiva_fab.dart';
import '../router/app_router.dart';
import 'dashboard/dashboard_screen.dart';
import 'vitals/vitals_screen.dart';
import 'vitals/vitals_ai_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';
import 'emergency/emergency_popup.dart';

// Page layout:  0=AI  1=Dashboard  2=Vitals  3=History  4=Profile
// Swipe right from Dashboard to reveal the AI screen.

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late final PageController _pageController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _pageController.page?.round() ?? 1;
    if (page != _currentPage) setState(() => _currentPage = page);
  }

  void _switchTab(int navIndex) {
    _pageController.animateToPage(
      navIndex + 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _goToAi() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _backToDashboard() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  bool get _showNav => _currentPage > 0;
  int get _navIndex => (_currentPage - 1).clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        children: [
          VitalsAiScreen(onBack: _backToDashboard),
          DashboardScreen(onSwitchTab: _switchTab, onOpenAi: _goToAi),
          const VitalsScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _showNav && _currentPage <= 2
          ? GestureDetector(
              onLongPress: () => EmergencyPopup.show(context, 'manual'),
              child: CardivaFab(
                onTap: () => Navigator.pushNamed(context, AppRouter.chat),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _showNav
          ? CardivaBottomNav(
              activeIndex: _navIndex,
              onTap: _switchTab,
            )
          : null,
    );
  }
}
