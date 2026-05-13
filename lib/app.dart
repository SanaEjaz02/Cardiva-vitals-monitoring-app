import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/analysis_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/user_provider.dart';
import 'router/app_router.dart';
import 'services/background_service.dart';
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
    }
  }

  // Writes user profile to SharedPreferences so the background isolate can read it
  Future<void> _writeUserProfileForBackground() async {
    final user = ref.read(userProvider);
    if (user == null) return;
    await BackgroundService.writeUserProfile(
      heightM: user.heightM,
      weightKg: user.weightKg,
      age: user.age,
      gender: user.gender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider).themeMode;

    return MaterialApp(
      title: 'Cardiva',
      debugShowCheckedModeBanner: false,
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
