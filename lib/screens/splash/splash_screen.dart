import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../router/app_router.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/auth_screen.dart';
import '../main_nav_screen.dart';

// Widget tree:
// Scaffold (bgWhite)
// └── Center
//     └── FadeTransition (_entryFade)
//         └── Column (min / center / center)
//             ├── Container 96×96 (circle, gradient, shadow)
//             │   └── Icon (monitor_heart_outlined, white, 48)
//             ├── SizedBox(20)
//             ├── Text "Cardiva"
//             ├── SizedBox(8)
//             ├── Text "Your heart, always watched"
//             ├── SizedBox(60)
//             └── _BouncingDots
//                 └── AnimatedBuilder → Row → 3× Transform.translate → Container 8×8

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _entryController.forward();

    // Resolve the startup destination in parallel with the minimum display
    // timer so the splash never adds latency beyond its visual purpose.
    _resolveStartupRoute();
  }

  /// Determines the first screen to show after the splash:
  ///
  ///   Signed in           → MainNavScreen  (Home)
  ///   Signed out, first launch → OnboardingScreen
  ///   Signed out, returning  → AuthScreen
  ///
  /// Firebase Auth restores sessions from the platform's secure store
  /// (iOS Keychain / Android EncryptedSharedPreferences).  We wait for
  /// [AuthService.checkSession] to resolve rather than reading
  /// [currentUser] synchronously, because Firebase needs a moment after
  /// cold start to load the cached credential.
  Future<void> _resolveStartupRoute() async {
    // Run the minimum display timer and the Firebase session check together.
    bool isSignedIn = false;
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 3500)),
      AuthService.checkSession().then((v) => isSignedIn = v),
    ]);

    if (!mounted) return;

    if (isSignedIn) {
      // Active session found — go straight to the home screen.
      _fadeNavigate(const MainNavScreen());
      return;
    }

    // No active session — check whether the user has seen onboarding before.
    final onboardingSeen = await SessionService.isOnboardingSeen();
    if (!mounted) return;

    // First launch: show onboarding. Subsequent launches: go straight to login.
    _fadeNavigate(
      onboardingSeen ? const AuthScreen() : const OnboardingScreen(slide: 1),
    );
  }

  /// Replaces the splash with [destination] using a smooth fade transition.
  void _fadeNavigate(Widget destination) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: Center(
        child: FadeTransition(
          opacity: _entryFade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    transform: GradientRotation(2.356),
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentTint.withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cardiva',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your heart, always watched',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 60),
              const _BouncingDots(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<Interval> _intervals = [
    Interval(0.0, 0.6, curve: Curves.easeInOut),
    Interval(0.15, 0.75, curve: Curves.easeInOut),
    Interval(0.30, 0.90, curve: Curves.easeInOut),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Transform.translate(
                offset: Offset(
                  0,
                  Tween<double>(begin: 0.0, end: -8.0)
                      .animate(CurvedAnimation(
                        parent: _controller,
                        curve: _intervals[i],
                      ))
                      .value,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
