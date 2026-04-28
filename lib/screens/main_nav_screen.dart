import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/atoms/bottom_nav_bar.dart';
import '../widgets/atoms/cardiva_fab.dart';
import '../router/app_router.dart';
import 'dashboard/dashboard_screen.dart';
import 'vitals/vitals_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';
import 'emergency/emergency_popup.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _activeIndex = 0;

  static const _screens = [
    DashboardScreen(),
    VitalsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: IndexedStack(
        index: _activeIndex,
        children: _screens,
      ),
      floatingActionButton: _activeIndex <= 1
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 76,
              ),
              child: GestureDetector(
                onLongPress: () => EmergencyPopup.show(context, 'manual'),
                child: CardivaFab(
                  onTap: () => Navigator.pushNamed(context, AppRouter.chat),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CardivaBottomNav(
        activeIndex: _activeIndex,
        onTap: (i) => setState(() => _activeIndex = i),
      ),
    );
  }
}
