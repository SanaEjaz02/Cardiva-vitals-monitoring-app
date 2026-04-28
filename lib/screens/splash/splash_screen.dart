import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _dotsController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        // In a real app, check auth state here
        // For demo: go to onboarding for first-time, dashboard for returning
        Navigator.pushReplacementNamed(context, AppRouter.onboarding1);
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Logo + text
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Column(
                    children: [
                      // Logo circle
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroCard,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowLg,
                              blurRadius: 28,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.monitor_heart_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Cardiva', style: AppTextStyles.h1),
                      const SizedBox(height: 6),
                      Text(
                        'Your heart, always watched',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
            // Bouncing dots
            _BouncingDots(controller: _dotsController),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  final AnimationController controller;

  const _BouncingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final start = i * 0.2;
        final end = start + 0.4;
        final anim = Tween<double>(begin: 0, end: -10).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end.clamp(0.0, 1.0),
                curve: Curves.easeInOut),
          ),
        );
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, anim.value),
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
