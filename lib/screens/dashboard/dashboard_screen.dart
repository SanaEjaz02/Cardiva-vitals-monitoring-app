import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/alert_class.dart';
import '../../models/user_profile.dart';
import '../../providers/analysis_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/skeleton_loader.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../emergency/emergency_popup.dart';
import '../../widgets/atoms/vital_animations.dart';
import '../../widgets/profile_quick_sheet.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/user_provider.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  const DashboardScreen({super.key, this.onSwitchTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: Stack(
        children: [
          // Light body background
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE2F4FC),
                    Color(0xFFF0FAFF),
                    Colors.white,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Dark decorative header blob
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _HeaderBlob(),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 6),
                      _TopBar(
                        greeting: _greeting,
                        pulseController: _pulseController,
                        onProfileTap: () => ProfileQuickSheet.show(context, onSwitchTab: widget.onSwitchTab),
                      ),
                      const SizedBox(height: 22),
                      const _HeroCard(),
                      const SizedBox(height: 18),
                      _QuickActions(
                        onEmergencyTap: () =>
                            EmergencyPopup.show(context, 'manual'),
                      ),
                      const SizedBox(height: 30),
                      _SectionHeader(
                        title: 'Live Vitals',
                        onTap: () => widget.onSwitchTab?.call(1),
                      ),
                      const SizedBox(height: 14),
                      _loading
                          ? const _SkeletonGrid()
                          : _VitalLayout(onSwitchTab: widget.onSwitchTab),
                      const SizedBox(height: 24),
                      const _DailyInsightCard(),
                      const SizedBox(height: 100),
                    ]),
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

// ── Header blob ────────────────────────────────────────────────────────────

class _HeaderBlob extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeaderBlobPainter(),
      child: const SizedBox(height: 260),
    );
  }
}

class _HeaderBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050A2E), Color(0xFF0A2F5A), Color(0xFF0D4F78)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.75, size.height * 1.08,
        size.width * 0.35, size.height * 0.85,
      )
      ..quadraticBezierTo(
        size.width * 0.10, size.height * 0.68,
        0, size.height * 0.78,
      )
      ..close();
    canvas.drawPath(path, paint);

    // Glowing accent orbs
    _drawOrb(canvas, Offset(size.width * 0.85, size.height * 0.20),
        70, const Color(0xFF2A7FAA), 0.12);
    _drawOrb(canvas, Offset(size.width * 0.12, size.height * 0.55),
        50, const Color(0xFF5BA8C8), 0.09);
    _drawOrb(canvas, Offset(size.width * 0.55, size.height * 0.08),
        35, const Color(0xFF1A6A90), 0.07);
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color,
      double opacity) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Gradient accent bar
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0077B6).withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h2.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0077B6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0077B6).withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              'See all →',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerStatefulWidget {
  final String greeting;
  final AnimationController pulseController;
  final VoidCallback? onProfileTap;

  const _TopBar({
    required this.greeting,
    required this.pulseController,
    this.onProfileTap,
  });

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadLocalPhoto();
  }

  Future<void> _loadLocalPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_photo_path');
    final exists = path != null && await File(path).exists();
    if (mounted) setState(() => _localPhotoPath = exists ? path : null);
  }

  @override
  Widget build(BuildContext context) {
    // Reload local photo whenever the profile is saved
    ref.listen<UserProfile?>(userProvider, (_, __) => _loadLocalPhoto());

    final unread = ref.watch(notificationsProvider).unreadCount;
    final userProfile = ref.watch(userProvider);
    final firebaseUser = AuthService.currentUser;
    final firstName =
        firebaseUser?.displayName?.split(' ').first ?? 'Patient';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'P';
    final networkPhoto = userProfile?.photoUrl ?? firebaseUser?.photoURL;

    ImageProvider? photo;
    if (_localPhotoPath != null) {
      photo = FileImage(File(_localPhotoPath!));
    } else if (networkPhoto != null) {
      photo = NetworkImage(networkPhoto);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.greeting,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Notification with badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, AppRouter.notifications),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 20),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        // Avatar with gradient ring
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF48CAE4), Color(0xFF90E0EF)],
              ),
            ),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryDeep,
              backgroundImage: photo,
              child: photo == null
                  ? Text(
                      initial,
                      style: AppTextStyles.h2White().copyWith(fontSize: 15),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero card ──────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dailySummaryProvider);
    final last = ref.watch(lastAnalysisProvider);

    final score = summary?.healthScore ?? 0;
    final hasData = last != null;

    final statusLabel = !hasData
        ? 'No analysis yet'
        : last.prediction.alertClass == AlertClass.emergency
            ? 'Emergency detected!'
            : last.prediction.alertClass == AlertClass.fallAlert
                ? 'Fall detected!'
                : last.prediction.alertClass == AlertClass.vitalsAlert
                    ? 'Vitals need attention'
                    : 'All vitals in healthy range';

    final scoreLabel = score >= 85
        ? 'Excellent'
        : score >= 70
            ? 'Good'
            : score >= 50
                ? 'Fair'
                : hasData
                    ? 'Poor'
                    : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0096C7),
            Color(0xFF0077B6),
            Color(0xFF023E8A),
            Color(0xFF03045E),
          ],
          stops: [0.0, 0.30, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF023E8A).withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF0096C7).withValues(alpha: 0.22),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
            const Positioned(
              top: -40,
              right: -30,
              child: _GlowOrb(
                  size: 180, color: Color(0xFF48CAE4), opacity: 0.22),
            ),
            const Positioned(
              bottom: -50,
              left: -20,
              child: _GlowOrb(
                  size: 140, color: Color(0xFF0077B6), opacity: 0.30),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite_rounded,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 12),
                              const SizedBox(width: 5),
                              Text('Health Score',
                                  style: AppTextStyles.captionWhite()
                                      .copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          scoreLabel,
                          style: AppTextStyles.h1White().copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          statusLabel,
                          style: AppTextStyles.captionWhite().copyWith(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const _HeroPill('AI Analysis', solid: true),
                            const SizedBox(width: 8),
                            _HeroPill(
                              hasData ? 'Active' : 'No data',
                              solid: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _ScoreRing(score: score),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowOrb(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScoreRing extends StatelessWidget {
  final int score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF48CAE4).withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 7.5,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor:
                AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.95)),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: AppTextStyles.h1White().copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  '/100',
                  style: AppTextStyles.captionWhite()
                      .copyWith(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final bool solid;
  const _HeroPill(this.label, {required this.solid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? Colors.white.withValues(alpha: 0.20) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: solid ? 0.0 : 0.40),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionWhite().copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onEmergencyTap;
  const _QuickActions({required this.onEmergencyTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          icon: Icons.assessment_rounded,
          label: 'Report',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
          ),
          glowColor: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, AppRouter.weeklyReport),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.smart_toy_rounded,
          label: 'Ask AI',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9B6DD6), Color(0xFF7B5EA7)],
          ),
          glowColor: const Color(0xFF7B5EA7),
          onTap: () => Navigator.pushNamed(context, AppRouter.chat),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.emergency_rounded,
          label: 'SOS',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFDC2626)],
          ),
          glowColor: AppColors.danger,
          onTap: onEmergencyTap,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.38),
                blurRadius: 18,
                spreadRadius: -3,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton grid ──────────────────────────────────────────────────────────

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: List.generate(
        6,
        (_) => const SkeletonLoader(
            width: double.infinity, height: 140, radius: 16),
      ),
    );
  }
}

// ── Vital layout ───────────────────────────────────────────────────────────

class _VitalLayout extends ConsumerWidget {
  final ValueChanged<int>? onSwitchTab;
  const _VitalLayout({this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastAnalysisProvider);

    final hr = last != null ? last.heartRate.toStringAsFixed(0) : '—';
    final spo2 = last != null ? '${last.spo2.toStringAsFixed(0)}%' : '—';
    final hrv = last != null ? '${last.hrv.toStringAsFixed(0)}ms' : '—';
    final rr = last != null ? '${last.respirationRate.toStringAsFixed(0)}/min' : '—';
    final activity = last?.prediction.analysisMessage.contains('fall') == true
        ? 'Alert'
        : 'Resting';
    final fallSafe = last?.prediction.fallDetected != true;

    String hrStatus() {
      if (last == null) return 'No data';
      final v = last.heartRate;
      return v < 60 ? 'Low' : v > 100 ? 'High' : 'Stable';
    }

    String spo2Status() {
      if (last == null) return 'No data';
      return last.spo2 < 95 ? 'Low' : 'Stable';
    }

    return Column(
      children: [
        SizedBox(
          height: 248,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _FeaturedVitalCard(
                  name: 'Heart Rate',
                  value: hr,
                  unit: last != null ? 'bpm' : '',
                  status: hrStatus(),
                  cardGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A3060),
                      Color(0xFF071D40),
                      Color(0xFF050F28),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  accentColor: const Color(0xFF2AACCC),
                  sparklineColor: const Color(0xFF2AACCC),
                  onTap: () => Navigator.pushNamed(
                      context, '${AppRouter.vitalsDetail}/heartRate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: _MiniVitalCard(
                        name: 'SpO₂',
                        value: spo2,
                        status: spo2Status(),
                        icon: Icons.water_drop_rounded,
                        accentColor: const Color(0xFF0096C7),
                        customAnimation: const Spo2AnimWidget(
                          color: Color(0xFF0096C7),
                          size: 30,
                        ),
                        onTap: () => Navigator.pushNamed(
                            context, '${AppRouter.vitalsDetail}/spo2'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _MiniVitalCard(
                        name: 'HRV',
                        value: hrv,
                        status: last == null
                            ? 'No data'
                            : last.hrv < 20
                                ? 'Low'
                                : 'Normal',
                        icon: Icons.show_chart_rounded,
                        accentColor: const Color(0xFF7B5EA7),
                        customAnimation: const HrvAnimWidget(
                          color: Color(0xFF7B5EA7),
                          size: 30,
                        ),
                        onTap: () => Navigator.pushNamed(
                            context, '${AppRouter.vitalsDetail}/hrv'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _MiniVitalCard(
                        name: 'Respiration',
                        value: rr,
                        status: last == null
                            ? 'No data'
                            : last.respirationRate < 12 ||
                                    last.respirationRate > 20
                                ? 'Abnormal'
                                : 'Normal',
                        icon: Icons.air_rounded,
                        accentColor: const Color(0xFF00B4D8),
                        customAnimation: const LungsAnimWidget(
                          color: Color(0xFF00B4D8),
                          size: 30,
                        ),
                        onTap: () => Navigator.pushNamed(
                            context,
                            '${AppRouter.vitalsDetail}/respiration'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusCard(
                label: 'Activity',
                status: activity,
                statusIcon: Icons.directions_walk_rounded,
                accentColor: AppColors.success,
                customAnimation: ActivityAnimWidget(
                  color: AppColors.success,
                  size: 44,
                  activityState: activity,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(
                label: 'Fall Detection',
                status: fallSafe ? 'Safe' : 'Alert!',
                statusIcon: fallSafe
                    ? Icons.shield_rounded
                    : Icons.warning_rounded,
                accentColor:
                    fallSafe ? AppColors.success : AppColors.danger,
                customAnimation: ShieldAnimWidget(
                  color: fallSafe ? AppColors.success : AppColors.danger,
                  size: 44,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Featured vital card ────────────────────────────────────────────────────

class _FeaturedVitalCard extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final String status;
  final LinearGradient cardGradient;
  final Color accentColor;
  final Color sparklineColor;
  final VoidCallback? onTap;

  const _FeaturedVitalCard({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.cardGradient,
    required this.accentColor,
    required this.sparklineColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF023E8A).withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Accent glow top-right
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    accentColor.withValues(alpha: 0.20),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_rounded,
                        color: accentColor, size: 20),
                  ),
                  const SizedBox(height: 10),
                  // Value
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status indicator
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.9),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Sparkline
                  SizedBox(
                    height: 52,
                    child: CustomPaint(
                      painter: _SparklinePainter(color: sparklineColor),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini vital card ────────────────────────────────────────────────────────

class _MiniVitalCard extends StatelessWidget {
  final String name;
  final String value;
  final String status;
  final IconData icon;
  final Color accentColor;
  final Widget? customAnimation;
  final VoidCallback? onTap;

  const _MiniVitalCard({
    required this.name,
    required this.value,
    required this.status,
    required this.icon,
    required this.accentColor,
    this.customAnimation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: accentColor, width: 3.5),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (customAnimation != null)
              SizedBox(width: 30, height: 30, child: customAnimation),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    name,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Glowing status dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.7),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String label;
  final String status;
  final IconData statusIcon;
  final Color accentColor;
  final Widget? customAnimation;

  const _StatusCard({
    required this.label,
    required this.status,
    required this.statusIcon,
    required this.accentColor,
    this.customAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          bottom: BorderSide(color: accentColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customAnimation != null)
            SizedBox(width: 44, height: 44, child: customAnimation!),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: accentColor, size: 12),
              const SizedBox(width: 4),
              Text(
                status,
                style: AppTextStyles.h2.copyWith(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Sparkline painter ──────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final Color color;

  static const _data = [
    0.45, 0.58, 0.48, 0.72, 0.55, 0.80, 0.62, 0.70, 0.58, 0.75, 0.65, 0.78
  ];

  const _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final points = List.generate(_data.length, (i) {
      final x = i * size.width / (_data.length - 1);
      final y = size.height * (1.0 - _data[i]);
      return Offset(x, y);
    });

    // Gradient fill
    final fillPath = Path()..moveTo(0, size.height);
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      } else {
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) / 2;
        fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Glowing endpoint dot
    canvas.drawCircle(points.last, 6, Paint()..color = color.withValues(alpha: 0.30));
    canvas.drawCircle(points.last, 3, Paint()..color = color);
    canvas.drawCircle(points.last, 1.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color;
}

// ── Daily insight card ─────────────────────────────────────────────────────

class _DailyInsightCard extends StatelessWidget {
  const _DailyInsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: 0.12),
            AppColors.success.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.28),
                  AppColors.success.withValues(alpha: 0.14),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Insight',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your heart rate has been stable for 6 hours. Great job staying active!',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
