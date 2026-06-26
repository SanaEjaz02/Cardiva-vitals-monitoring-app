import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/setup/profile_setup_screen.dart';
import '../screens/setup/device_pair_screen.dart';
import '../screens/setup/emergency_contact_setup_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/vitals/vital_detail_screen.dart';
import '../screens/vitals/vitals_ai_screen.dart';
import '../screens/emergency/alert_sent_screen.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/attendant_screen.dart';
import '../screens/settings/emergency_contacts_screen.dart';
import '../screens/settings/notification_preferences_screen.dart';
import '../screens/settings/help_support_screen.dart';
import '../screens/report/health_report_screen.dart';
import '../screens/device/device_connection_screen.dart';
import '../screens/device/live_monitor_screen.dart';
import '../screens/attendant/attendant_home_screen.dart';
import '../screens/attendant/attendant_main_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/profile/patient_qr_screen.dart';
import '../screens/chat/patient_chat_screen.dart';

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
  static const String vitalsAi = '/vitals/ai';
  static const String alertSent = '/emergency/sent';
  static const String chat = '/chat';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String settingsAttendants = '/settings/attendants';
  static const String emergencyContacts = '/settings/emergency-contacts';
  static const String notificationPrefs = '/settings/notification-prefs';
  static const String helpSupport = '/settings/help';
  static const String weeklyReport = '/report/weekly';
  static const String deviceConnect = '/device/connect';
  static const String liveMonitor = '/device/live';
  static const String forgotPassword = '/auth/forgot-password';
  static const String attendantHome = '/attendant/home';
  static const String attendantMain = '/attendant';
  static const String roleSelection = '/auth/role';
  static const String patientQr     = '/patient/qr';
  static const String patientChat   = '/patient/chat';

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
        chat: (ctx) => ChatbotScreen(
              initialMessage:
                  ModalRoute.of(ctx)?.settings.arguments as String?,
            ),
        notifications: (_) => const NotificationsScreen(),
        vitalsAi: (_) => const VitalsAiScreen(),
        settings: (_) => const SettingsScreen(),
        settingsAttendants: (_) => const AttendantScreen(),
        emergencyContacts: (_) => const EmergencyContactsScreen(),
        notificationPrefs: (_) => const NotificationPreferencesScreen(),
        helpSupport: (_) => const HelpSupportScreen(),
        weeklyReport: (_) => const HealthReportScreen(),
        deviceConnect: (_) => const DeviceConnectionScreen(),
        liveMonitor: (_) => const LiveMonitorScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        attendantHome: (_) => const AttendantHomeScreen(),
        attendantMain: (_) => const AttendantMainScreen(),
        roleSelection: (_) => const RoleSelectionScreen(),
        patientQr:     (_) => const PatientQrScreen(),
        patientChat:   (_) => const PatientChatScreen(),
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
