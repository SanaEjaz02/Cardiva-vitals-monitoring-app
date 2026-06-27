import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_navigator.dart';
import '../providers/analysis_provider.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/atoms/bottom_nav_bar.dart';
import '../widgets/atoms/cardiva_fab.dart';
import '../router/app_router.dart';
import 'dashboard/dashboard_screen.dart';
import 'vitals/vitals_screen.dart';
import 'vitals/vitals_ai_screen.dart';
import 'chat/patient_chat_screen.dart';
import 'profile/profile_screen.dart';
import 'emergency/emergency_popup.dart';

final _chatUnreadProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return ChatService.totalUnreadStream(uid);
});

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
    // Listen for tab-switch requests from EmergencyPopup (no Riverpod needed).
    mainNavTabNotifier.addListener(_handleTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        ref.read(userProvider.notifier).loadFromStore(),
        ref.read(analysisHistoryProvider.notifier).ensureLoadedForCurrentUser(),
      ]);
    });
  }

  void _onScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) setState(() => _currentPage = page);
  }

  void _handleTabRequest() {
    final tab = mainNavTabNotifier.value;
    if (tab != null && mounted) {
      _switchTab(tab);
      mainNavTabNotifier.value = null;
    }
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
    mainNavTabNotifier.removeListener(_handleTabRequest);
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  int get _navIndex => _currentPage.clamp(0, 4);

  @override
  Widget build(BuildContext context) {
    // Show in-app banner when a new message arrives and user is not on the chat tab.
    // Skip the initial emission (previous == null) to avoid spurious alerts on login.
    ref.listen<AsyncValue<int>>(_chatUnreadProvider, (previous, next) {
      if (previous == null) return;
      final prev = previous.valueOrNull ?? 0;
      final curr = next.valueOrNull ?? 0;
      if (curr > prev && _currentPage != 3 && mounted) {
        NotificationService.showChatNotification(
          'New Message',
          'You have a new message from your guardian',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text('New message from your guardian',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white70,
              onPressed: () => _switchTab(3),
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
            const PatientChatScreen(),
            const ProfileScreen(),
          ],
        ),
        floatingActionButton: _currentPage == 3
            ? FloatingActionButton(
                heroTag: 'ai_chat_fab',
                onPressed: () => Navigator.pushNamed(context, AppRouter.chat),
                backgroundColor: AppColors.primaryDeep,
                child: const Icon(Icons.favorite_rounded, color: Colors.white),
              )
            : _currentPage <= 1
                ? GestureDetector(
                    onLongPress: () => EmergencyPopup.show(context, 'manual'),
                    child: CardivaFab(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRouter.chat),
                    ),
                  )
                : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: CardivaBottomNav(
          activeIndex: _navIndex,
          onTap: _switchTab,
          badges: {3: ref.watch(_chatUnreadProvider).valueOrNull ?? 0},
        ),
      ),
    );
  }
}
