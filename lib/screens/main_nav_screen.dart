import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analysis_provider.dart';
import '../providers/user_provider.dart';
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

// Page layout: 0=Dashboard  1=Vitals  2=AI  3=History  4=Profile

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_onScroll);
    // Ensure profile and analysis history are loaded for the current user.
    // This handles the case where the user logged in via the auth screen
    // (which doesn't call loadFromStore) or switched accounts.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Run independent loads in parallel for faster startup
      await Future.wait([
        ref.read(userProvider.notifier).loadFromStore(),
        ref.read(analysisHistoryProvider.notifier).ensureLoadedForCurrentUser(),
        ref.read(emergencyContactsProvider.notifier).loadFromStore(),
      ]);
    });
  }

  void _onScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) setState(() => _currentPage = page);
  }

  void _switchTab(int index) {
    _pageController.animateToPage(
      index,
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

  int get _navIndex => _currentPage.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _switchTab(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: PageView(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          children: [
            DashboardScreen(onSwitchTab: _switchTab),
            const VitalsScreen(),
            const VitalsAiScreen(),
            const HistoryScreen(),
            const ProfileScreen(),
          ],
        ),
        floatingActionButton: _currentPage <= 1
            ? GestureDetector(
                onLongPress: () => EmergencyPopup.show(context, 'manual'),
                child: CardivaFab(
                  onTap: () => Navigator.pushNamed(context, AppRouter.chat),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: CardivaBottomNav(
          activeIndex: _navIndex,
          onTap: _switchTab,
        ),
      ),
    );
  }
}
