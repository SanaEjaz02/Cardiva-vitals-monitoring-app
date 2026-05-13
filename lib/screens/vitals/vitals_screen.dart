import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/atoms/spark_widget.dart';
import '../../router/app_router.dart';

class VitalsScreen extends StatelessWidget {
  final VoidCallback? onOpenAi;
  const VitalsScreen({super.key, this.onOpenAi});

  static const _vitals = [
    _VitalRow('Heart Rate', Icons.favorite_rounded, '72', 'bpm',
        VitalDisplayStatus.normal, 'heartRate'),
    _VitalRow('SpO₂', Icons.air_rounded, '93', '%',
        VitalDisplayStatus.warning, 'spo2'),
    _VitalRow('HRV', Icons.timeline_rounded, '18', 'ms',
        VitalDisplayStatus.critical, 'hrv'),
    _VitalRow('Respiration', Icons.waves_rounded, '16', '/min',
        VitalDisplayStatus.normal, 'respiration'),
    _VitalRow('Activity', Icons.directions_walk_rounded, 'Walking', '',
        VitalDisplayStatus.normal, 'activity'),
    _VitalRow('Fall Detection', Icons.shield_outlined, 'Safe', '',
        VitalDisplayStatus.normal, 'fallDetection'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text('Vitals', style: AppTextStyles.h1)),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Updated 3s ago', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                  if (onOpenAi != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onOpenAi,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_rounded,
                                size: 11,
                                color: AppColors.primary.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text(
                              'AI Monitor',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.monitor_heart_outlined,
                                size: 13, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _vitals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final v = _vitals[i];
                  return _VitalListCard(vital: v);
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: onOpenAi ?? () => Navigator.pushNamed(context, AppRouter.vitalsAi),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_rounded, color: AppColors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Vitals Analysis', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Analyze live band data and trigger emergency response.', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _VitalListCard extends StatelessWidget {
  final _VitalRow vital;
  const _VitalListCard({required this.vital});

  // Demo spark data
  List<double> _sparkData() {
    switch (vital.status) {
      case VitalDisplayStatus.normal:
        return [70, 72, 71, 73, 72, 74, 72, 71, 73, 72];
      case VitalDisplayStatus.warning:
        return [96, 95, 94, 94, 93, 93, 92, 93, 93, 93];
      case VitalDisplayStatus.critical:
        return [42, 35, 28, 22, 18, 18, 16, 18, 18, 18];
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(vital.status);
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '${AppRouter.vitalsDetail}/${vital.routeId}'),
      child: Container(
        height: 80,
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
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // Icon + name
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(vital.icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(vital.name, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(width: 16),
            // Value
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vital.unit.isEmpty ? vital.value : '${vital.value} ${vital.unit}',
                    style: AppTextStyles.h2.copyWith(
                      color: color,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Badge + spark
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge.fromStatus(vital.status),
                const SizedBox(height: 6),
                SparkWidget(
                  dataPoints: _sparkData(),
                  color: color,
                  width: 60,
                  height: 24,
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _VitalRow {
  final String name;
  final IconData icon;
  final String value;
  final String unit;
  final VitalDisplayStatus status;
  final String routeId;

  const _VitalRow(
      this.name, this.icon, this.value, this.unit, this.status, this.routeId);
}
