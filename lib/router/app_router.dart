import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/setup/profile_setup_screen.dart';
import '../screens/setup/device_pair_screen.dart';
import '../screens/setup/emergency_contact_setup_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/vitals/vital_detail_screen.dart';
import '../screens/emergency/alert_sent_screen.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/attendant_screen.dart';
import '../screens/settings/emergency_contacts_screen.dart';
import '../screens/settings/notification_preferences_screen.dart';
import '../screens/settings/help_support_screen.dart';
import '../screens/report/health_report_screen.dart';

class AppRouter {
  AppRouter._();

  // ── Route name constants ───────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding1 = '/onboarding/1';
  static const String onboarding2 = '/onboarding/2';
  static const String onboarding3 = '/onboarding/3';
  static const String auth = '/auth';

  // Legacy aliases kept for compatibility
  static const String login = '/auth';
  static const String register = '/auth';

  static const String setupProfile = '/setup/profile';
  static const String setupPair = '/setup/pair';
  static const String setupContact = '/setup/contact';

  static const String dashboard = '/dashboard';
  static const String vitalsDetail = '/vitals'; // use as prefix: /vitals/:id
  static const String alertSent = '/emergency/sent';
  static const String chat = '/chat';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String settingsAttendants = '/settings/attendants';
  static const String emergencyContacts = '/settings/emergency-contacts';
  static const String notificationPrefs = '/settings/notification-prefs';
  static const String helpSupport = '/settings/help';
  static const String weeklyReport = '/report/weekly';

  // ── Static route map (no path parameters) ─────────────────────────────────
  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        onboarding1: (_) => const OnboardingScreen(slide: 1),
        onboarding2: (_) => const OnboardingScreen(slide: 2),
        onboarding3: (_) => const OnboardingScreen(slide: 3),
        auth: (_) => const AuthScreen(),
        setupProfile: (_) => const ProfileSetupScreen(),
        setupPair: (_) => const DevicePairScreen(),
        setupContact: (_) => const EmergencyContactSetupScreen(),
        dashboard: (_) => const MainNavScreen(),
        alertSent: (_) => const AlertSentScreen(),
        chat: (_) => const ChatbotScreen(),
        notifications: (_) => const NotificationsScreen(),
        settings: (_) => const SettingsScreen(),
        settingsAttendants: (_) => const AttendantScreen(),
        emergencyContacts: (_) => const EmergencyContactsScreen(),
        notificationPrefs: (_) => const NotificationPreferencesScreen(),
        helpSupport: (_) => const HelpSupportScreen(),
        weeklyReport: (_) => const HealthReportScreen(),
      };

  // ── Dynamic route generator (handles /vitals/:id) ─────────────────────────
  static Route<dynamic>? generateRoute(RouteSettings routeSettings) {
    final name = routeSettings.name ?? '';

    if (name.startsWith('/vitals/')) {
      final id = name.replaceFirst('/vitals/', '');
      return _slideRoute(
        VitalDetailScreen(vitalId: id),
        routeSettings,
      );
    }

    // Unknown — let Navigator use the routes map
    return null;
  }

  static PageRouteBuilder<T> _slideRoute<T>(
    Widget page,
    RouteSettings s,
  ) {
    return PageRouteBuilder<T>(
      settings: s,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
