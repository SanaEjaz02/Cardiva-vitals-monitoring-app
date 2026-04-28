import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/vital_card_atom.dart';
import '../../widgets/atoms/skeleton_loader.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../router/app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
                      _TopBar(pulseController: _pulseController),
                      const SizedBox(height: 20),
                      const _HeroCard(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Live Vitals', style: AppTextStyles.h2),
                          TextButton(
                            onPressed: () {},
                            child: Text('See all →',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _loading ? const _SkeletonGrid() : const _VitalGrid(),
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

class _TopBar extends StatelessWidget {
  final AnimationController pulseController;
  const _TopBar({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good morning,', style: AppTextStyles.caption),
              Text('Sarah', style: AppTextStyles.h1),
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
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryBg,
          child: Text('S',
              style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLg,
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Health',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text('Excellent', style: AppTextStyles.h1White()),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('94 / 100',
                  style: AppTextStyles.h2White().copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _WhitePill('Confidence: 89%', outline: true),
              const SizedBox(width: 8),
              _WhitePill('Walking', outline: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  final String label;
  final bool outline;
  const _WhitePill(this.label, {required this.outline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: outline
            ? Border.all(color: Colors.white.withOpacity(0.6))
            : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.captionWhite()
            .copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

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
