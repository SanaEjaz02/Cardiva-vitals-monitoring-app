import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_navigator.dart';
import 'providers/analysis_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/user_provider.dart';
import 'providers/vital_provider.dart';
import 'router/app_router.dart';
import 'models/user_profile.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class CardivApp extends ConsumerStatefulWidget {
  const CardivApp({super.key});

  @override
  ConsumerState<CardivApp> createState() => _CardivAppState();
}

class _CardivAppState extends ConsumerState<CardivApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _writeUserProfileForBackground();
    // Reconnect to the last BLE device after the widget tree is ready.
    // Handles the case where the app was killed and relaunched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bleServiceProvider).reconnectFromPrefs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync any records the background service wrote while app was away
      ref.read(analysisHistoryProvider.notifier).syncFromBackground();
      // Refresh user profile for background service
      _writeUserProfileForBackground();
      // Push any reports the background isolate queued to Firestore
      ref.read(analysisHistoryProvider.notifier).syncPendingReports();
      // Reconnect BLE if connection dropped while app was in background
      final ble = ref.read(bleServiceProvider);
      if (!ble.isConnected) ble.reconnectFromPrefs();
    }
  }

  // Writes user profile + UID to SharedPreferences so the background isolate
  // can scope its storage to the correct user.
  Future<void> _writeUserProfileForBackground() async {
    final user = ref.read(userProvider);
    if (user == null) return;
    await BackgroundService.writeUserProfile(
      uid: user.id,
      heightM: user.heightM,
      weightKg: user.weightKg,
      age: user.age,
      gender: user.gender,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep healthEventProvider alive on every screen so emergency detection
    // and EmergencyTrigger fire immediately from live readings, not just when
    // the AI screen is open.
    ref.listen(healthEventProvider, (_, __) {});

    // Sync the user role into NotificationService so notification taps don't
    // route guardians to the patient-only AI analysis screen.
    ref.listen<UserProfile?>(userProvider, (_, profile) {
      if (profile != null) {
        NotificationService.setCurrentUserRole(
          profile.role == UserRole.attendant ? 'attendant' : 'patient',
        );
      }
    });

    final themeMode = ref.watch(settingsProvider).themeMode;

    return MaterialApp(
      title: 'Cardiva',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
