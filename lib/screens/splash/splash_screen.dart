import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../attendant/attendant_home_screen.dart';
import '../auth/auth_screen.dart';
import '../main_nav_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Stage 1 — background fade-in
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgFade;

  // Stage 2 — ECG line sweeps across the screen
  late final AnimationController _ecgCtrl;
  late final Animation<double> _ecgProgress;
  late final Animation<double> _ecgFadeOut;

  // Stage 3 — shield icon scales in
  late final AnimationController _shieldCtrl;
  late final Animation<double> _shieldScale;
  late final Animation<double> _shieldFade;

  // Stage 4 — pulse-glow ring expands and fades
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseAlpha;

  // Stage 5 — app name + tagline slide up
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runSequence();
    _resolveStartupRoute();
  }

  void _initAnimations() {
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    _ecgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _ecgProgress =
        CurvedAnimation(parent: _ecgCtrl, curve: Curves.easeInOut);
    _ecgFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ecgCtrl,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _shieldCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _shieldScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut),
    );
    _shieldFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shieldCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));
    _pulseScale = Tween<double>(begin: 1.0, end: 1.9).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseAlpha = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeIn),
    );

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
  }

  Future<void> _runSequence() async {
    // Stage 1: bg
    _bgCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    // Stage 2: ECG sweep (1100 ms)
    await _ecgCtrl.forward().orCancel.catchError((_) {});
    if (!mounted) return;

    // Stage 3: shield entrance
    _shieldCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    // Stage 4: pulse ring
    _pulseCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    // Stage 5: text slide-up
    _textCtrl.forward();
  }

  Future<void> _resolveStartupRoute() async {
    bool isSignedIn = false;
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 3500)),
      AuthService.checkSession().then((v) => isSignedIn = v),
    ]);
    if (!mounted) return;

    if (isSignedIn) {
      await ref.read(userProvider.notifier).loadFromStore();
      if (!mounted) return;
      final role = ref.read(userProvider)?.role ?? UserRole.patient;
      _fadeNavigate(role == UserRole.attendant
          ? const AttendantHomeScreen()
          : const MainNavScreen());
      return;
    }

    final onboardingSeen = await SessionService.isOnboardingSeen();
    if (!mounted) return;
    _fadeNavigate(
      onboardingSeen ? const AuthScreen() : const OnboardingScreen(slide: 1),
    );
  }

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
    _bgCtrl.dispose();
    _ecgCtrl.dispose();
    _shieldCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_bgCtrl, _ecgCtrl, _shieldCtrl, _pulseCtrl, _textCtrl]),
        builder: (context, _) => _buildBody(context, size),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Size size) {
    final bg = _bgFade.value;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Color.lerp(Colors.white, AppColors.bgLight, bg)!,
            Color.lerp(Colors.white, const Color(0xFFADE8F4), bg * 0.55)!,
            Colors.white,
          ],
        ),
      ),
      child: Stack(
        children: [
          // ── Decorative corner blobs ────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Opacity(
              opacity: bg * 0.35,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Opacity(
              opacity: bg * 0.25,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),

          // ── ECG line ──────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.34,
            height: 130,
            child: Opacity(
              opacity: _ecgFadeOut.value,
              child: CustomPaint(
                painter: _EcgLinePainter(
                  progress: _ecgProgress.value,
                  lineColor: AppColors.primary,
                ),
              ),
            ),
          ),

          // ── Icon + text block ──────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      if (_pulseCtrl.value > 0)
                        Transform.scale(
                          scale: _pulseScale.value,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: _pulseAlpha.value),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),

                      // Inner fill ring (slightly delayed)
                      if (_pulseCtrl.value > 0.15)
                        Transform.scale(
                          scale: 1.0 + (_pulseScale.value - 1.0) * 0.5,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                  alpha: _pulseAlpha.value * 0.22),
                            ),
                          ),
                        ),

                      // Shield circle
                      Transform.scale(
                        scale: _shieldScale.value,
                        child: Opacity(
                          opacity: _shieldFade.value,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDeep,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.45),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.18),
                                  blurRadius: 56,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  color: Colors.white,
                                  size: 54,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(
                                    Icons.favorite,
                                    color: Color(0xFFFF8FAB),
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // App name + tagline
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Column(
                      children: [
                        Text(
                          'Cardiva',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your heart, always watched',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ECG custom painter ────────────────────────────────────────────────────────

class _EcgLinePainter extends CustomPainter {
  final double progress;
  final Color lineColor;

  const _EcgLinePainter({required this.progress, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final cy = size.height / 2;
    final w = size.width;

    // Normalised (xFraction, yOffset-px) segments — two QRS cycles across width
    const segments = <(double, double)>[
      (0.00, 0),
      (0.07, 0),
      (0.11, -7),   // P wave
      (0.14, -11),
      (0.18, 0),
      (0.23, 0),    // PR
      (0.27, 5),    // Q dip
      (0.30, -52),  // R peak
      (0.33, 9),    // S dip
      (0.37, 0),
      (0.42, 0),    // ST
      (0.46, -13),  // T wave
      (0.50, -15),
      (0.55, 0),
      (0.61, 0),    // flat
      (0.65, -7),   // P wave #2
      (0.68, -11),
      (0.72, 0),
      (0.76, 0),
      (0.80, 5),    // QRS #2
      (0.83, -52),
      (0.86, 9),
      (0.89, 0),
      (0.93, -13),  // T wave #2
      (0.97, -15),
      (1.00, 0),
    ];

    // Interpolate into a dense point list
    final pts = <Offset>[];
    for (int i = 0; i < segments.length - 1; i++) {
      final (x1, y1) = segments[i];
      final (x2, y2) = segments[i + 1];
      final steps = ((x2 - x1) * w / 1.8).ceil().clamp(2, 80);
      for (int j = 0; j < steps; j++) {
        final t = j / steps;
        pts.add(Offset(
          (x1 + (x2 - x1) * t) * w,
          cy + y1 + (y2 - y1) * t,
        ));
      }
    }
    pts.add(Offset(w, cy));

    final visible = (pts.length * progress).round().clamp(0, pts.length);
    if (visible < 2) return;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < visible; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    // Glow layer
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: 0.28)
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: 0.72)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Bright leading dot
    if (visible < pts.length) {
      final lead = pts[visible - 1];
      // glow halo
      canvas.drawCircle(
        lead,
        9,
        Paint()
          ..color = lineColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // solid dot
      canvas.drawCircle(
        lead,
        4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_EcgLinePainter old) =>
      old.progress != progress || old.lineColor != lineColor;
}
