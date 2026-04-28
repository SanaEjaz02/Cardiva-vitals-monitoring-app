import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../router/app_router.dart';

class OnboardingScreen extends StatelessWidget {
  final int slide; // 1, 2, or 3

  const OnboardingScreen({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final data = _slides[slide - 1];
    final isLast = slide == 3;

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Skip
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRouter.auth),
                  child: Text(
                    'Skip',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Illustration area
              Expanded(
                flex: 5,
                child: _OnboardingIllustration(slide: slide),
              ),
              const SizedBox(height: 24),
              // Step indicator
              StepIndicator(current: slide, total: 3),
              const SizedBox(height: 24),
              // Title
              Text(
                data.title,
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Body
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  data.body,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final next = isLast
                        ? AppRouter.auth
                        : (slide == 1
                            ? AppRouter.onboarding2
                            : AppRouter.onboarding3);
                    Navigator.pushReplacementNamed(context, next);
                  },
                  child: Text(isLast ? 'Get Started' : 'Next →'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingIllustration extends StatefulWidget {
  final int slide;
  const _OnboardingIllustration({required this.slide});

  @override
  State<_OnboardingIllustration> createState() =>
      _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<_OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Center(
        child: switch (widget.slide) {
          1 => _Slide1Illustration(pulse: _pulse),
          2 => _Slide2Illustration(pulse: _pulse),
          _ => _Slide3Illustration(pulse: _pulse),
        },
      ),
    );
  }
}

// Slide 1: Wearable with signal arcs
class _Slide1Illustration extends StatelessWidget {
  final AnimationController pulse;
  const _Slide1Illustration({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Pulse arcs
          ...List.generate(3, (i) {
            final delay = i * 0.33;
            final t = ((pulse.value - delay) % 1.0).clamp(0.0, 1.0);
            return Opacity(
              opacity: (1 - t) * (i == 0 ? 1.0 : i == 1 ? 0.6 : 0.3),
              child: Container(
                width: 80 + t * 60,
                height: 80 + t * 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
          // Device icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.heroCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.watch_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

// Slide 2: Shield with heart-rate line
class _Slide2Illustration extends StatelessWidget {
  final AnimationController pulse;
  const _Slide2Illustration({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 120,
          color: AppColors.primary.withOpacity(0.15),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.primaryBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppColors.primary,
            size: 40,
          ),
        ),
        // Floating data dots
        ...List.generate(6, (i) {
          final angle = i * 60.0 * 3.14159 / 180;
          final r = 80.0;
          return Positioned(
            left: 120 + r * (0.8 * (i % 2 == 0 ? 1 : -0.7)),
            top: 80 + r * (0.5 * (i < 3 ? -1 : 1)),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ],
    );
  }
}

// Slide 3: Two people connected
class _Slide3Illustration extends StatelessWidget {
  final AnimationController pulse;
  const _Slide3Illustration({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 28),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 28),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 28),
            Row(
              children: List.generate(5, (i) {
                return Container(
                  width: 8,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: AppColors.accentTint,
                );
              }),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_rounded,
                color: AppColors.secondary, size: 28),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primaryDeep, size: 28),
            ),
          ],
        ),
      ],
    );
  }
}

class _SlideData {
  final String title;
  final String body;
  const _SlideData(this.title, this.body);
}

const _slides = [
  _SlideData(
    'Real-time health monitoring',
    'Six vital signs tracked continuously. Intelligent analysis. Zero delay.',
  ),
  _SlideData(
    'Smart emergency detection',
    'AI-powered analysis distinguishes real emergencies from false alarms — and alerts your contacts in seconds.',
  ),
  _SlideData(
    'Always connected to care',
    'Emergency contacts and attendants are alerted instantly with your live location when it matters most.',
  ),
];
