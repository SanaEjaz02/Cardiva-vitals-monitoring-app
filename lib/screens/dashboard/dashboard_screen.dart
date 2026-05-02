import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/vital_card_atom.dart';
import '../../widgets/atoms/skeleton_loader.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../emergency/emergency_popup.dart';

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
      duration: const Duration(seconds: 1),
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
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.appBackground),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      _TopBar(
                        greeting: _greeting,
                        pulseController: _pulseController,
                        onProfileTap: () => widget.onSwitchTab?.call(3),
                      ),
                      const SizedBox(height: 20),
                      const _HeroCard(),
                      const SizedBox(height: 16),
                      _QuickActions(onEmergencyTap: () =>
                          EmergencyPopup.show(context, 'manual')),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Live Vitals', style: AppTextStyles.h2),
                          TextButton(
                            onPressed: () => widget.onSwitchTab?.call(1),
                            child: Text(
                              'See all →',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _loading ? const _SkeletonGrid() : const _VitalGrid(),
                      const SizedBox(height: 20),
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

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String greeting;
  final AnimationController pulseController;
  final VoidCallback? onProfileTap;

  const _TopBar({
    required this.greeting,
    required this.pulseController,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Patient';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'P';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTextStyles.caption),
              Text(firstName, style: AppTextStyles.h1),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.textPrimary, size: 24),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRouter.notifications),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onProfileTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryDeep,
            child: Text(
              initial,
              style: AppTextStyles.h2White().copyWith(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5BB8D4),
            Color(0xFF3A8AAD),
            Color(0xFF2A5A7A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A6C8A).withOpacity(0.40),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: 50,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.09),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 110,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'Your Health Score',
                              style: AppTextStyles.captionWhite()
                                  .copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Excellent',
                          style: AppTextStyles.h1White().copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All vitals are in a healthy range',
                          style: AppTextStyles.captionWhite().copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _HeroPill('Accuracy: High', solid: true),
                            _HeroPill('Walking Active', solid: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right: score ring
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: 0.94,
                          strokeWidth: 7,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '94',
                                style: AppTextStyles.h1White().copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '/100',
                                style: AppTextStyles.captionWhite()
                                    .copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _HeroPill extends StatelessWidget {
  final String label;
  final bool solid;
  const _HeroPill(this.label, {required this.solid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? Colors.white.withOpacity(0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(solid ? 0 : 0.55),
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
          icon: Icons.assessment_outlined,
          label: 'Report',
          color: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, AppRouter.weeklyReport),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.smart_toy_outlined,
          label: 'Ask AI',
          color: const Color(0xFF7B5EA7),
          onTap: () => Navigator.pushNamed(context, AppRouter.chat),
        ),
        const SizedBox(width: 12),
        _ActionTile(
          icon: Icons.emergency_outlined,
          label: 'SOS',
          color: AppColors.danger,
          onTap: onEmergencyTap,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
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

// ── Vital grid ────────────────────────────────────────────────────────────

class _VitalGrid extends StatelessWidget {
  const _VitalGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        VitalCardAtom(
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          percent: 0.60,
          status: VitalDisplayStatus.normal,
          onTap: () => Navigator.pushNamed(
              context, '${AppRouter.vitalsDetail}/heartRate'),
        ),
        VitalCardAtom(
          name: 'SpO₂',
          value: '98',
          unit: '%',
          percent: 0.90,
          status: VitalDisplayStatus.normal,
          onTap: () =>
              Navigator.pushNamed(context, '${AppRouter.vitalsDetail}/spo2'),
        ),
        VitalCardAtom(
          name: 'HRV',
          value: '45',
          unit: 'ms',
          percent: 0.55,
          status: VitalDisplayStatus.normal,
          onTap: () =>
              Navigator.pushNamed(context, '${AppRouter.vitalsDetail}/hrv'),
        ),
        VitalCardAtom(
          name: 'Respiration',
          value: '16',
          unit: '/min',
          percent: 0.65,
          status: VitalDisplayStatus.normal,
          onTap: () => Navigator.pushNamed(
              context, '${AppRouter.vitalsDetail}/respiration'),
        ),
        // Activity card
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowSm,
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ],
              border: const Border(
                bottom: BorderSide(color: AppColors.success, width: 3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_walk_rounded,
                    color: AppColors.success, size: 36),
                const SizedBox(height: 8),
                PillWidget('Walking', variant: PillVariant.success),
                const SizedBox(height: 4),
                Text('Activity', style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
        // Fall detection card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSm,
                blurRadius: 16,
                offset: Offset(0, 2),
              ),
            ],
            border: const Border(
              bottom: BorderSide(color: AppColors.success, width: 3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.success, size: 36),
              const SizedBox(height: 8),
              Text('Safe',
                  style: AppTextStyles.h2.copyWith(color: AppColors.success)),
              const SizedBox(height: 4),
              Text('Fall Detection', style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Daily insight card ────────────────────────────────────────────────────

class _DailyInsightCard extends StatelessWidget {
  const _DailyInsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tips_and_updates_outlined,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Insight',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your heart rate has been stable for 6 hours. Great job staying active!',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
