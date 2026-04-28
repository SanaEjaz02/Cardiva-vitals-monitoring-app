import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/ring_widget.dart';
import '../../widgets/atoms/spark_widget.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  int _weekOffset = 0;

  String get _weekLabel {
    if (_weekOffset == 0) return 'Apr 19 – Apr 25';
    if (_weekOffset == -1) return 'Apr 12 – Apr 18';
    return 'Apr 26 – May 2';
  }

  static const _vitals = [
    _VitalDelta('Heart Rate', Icons.favorite_rounded, '72 bpm', '+2 bpm',
        true, VitalDisplayStatus.normal),
    _VitalDelta('SpO₂', Icons.air_rounded, '95%', '-1%',
        false, VitalDisplayStatus.warning),
    _VitalDelta('HRV', Icons.timeline_rounded, '45 ms', '+4 ms',
        true, VitalDisplayStatus.normal),
    _VitalDelta('Respiration', Icons.waves_rounded, '16/min', '0',
        true, VitalDisplayStatus.normal),
    _VitalDelta('Activity', Icons.directions_walk_rounded, '8,200 steps', '+8%',
        true, VitalDisplayStatus.normal),
    _VitalDelta('Fall Detection', Icons.shield_outlined, 'Safe', '0 falls',
        true, VitalDisplayStatus.normal),
  ];

  static const _activityDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _activityValues = [0.6, 0.8, 0.5, 0.9, 0.7, 0.4, 0.3];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Health Report', style: AppTextStyles.h1),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Date navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _weekOffset--),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_weekLabel, style: AppTextStyles.h2),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _weekOffset++),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Score hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowLg,
                      blurRadius: 28,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Score',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('92 / 100',
                            style: AppTextStyles.numericDisplay
                                .copyWith(color: Colors.white, fontSize: 36)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.trending_up_rounded,
                                color: AppColors.success, size: 16),
                            const SizedBox(width: 4),
                            Text('↑ 3 from last week',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  RingWidget(
                    percent: 0.92,
                    color: Colors.white,
                    size: 56,
                    strokeWidth: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // AI Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowSm,
                      blurRadius: 12,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your cardiovascular health remained stable this week with a slight improvement in HRV. '
                          'SpO₂ dipped briefly on Apr 21 — consider monitoring during physical activity.',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 6),
                        Text('Generated by Cardiva AI',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Vital deltas
            ..._vitals.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VitalDeltaRow(vital: v),
                )),
            const SizedBox(height: 8),
            // Activity bars
            Text('Activity This Week', style: AppTextStyles.h2),
            const SizedBox(height: 12),
            _ActivityBars(
              days: _activityDays,
              values: _activityValues,
            ),
            const SizedBox(height: 24),
            // Export buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.local_hospital_outlined, size: 18),
                    label: const Text('Share with Doctor'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _VitalDeltaRow extends StatelessWidget {
  final _VitalDelta vital;
  const _VitalDeltaRow({required this.vital});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(vital.status);
    final deltaColor =
        vital.isPositive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(vital.icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vital.name, style: AppTextStyles.caption),
                Text(vital.avgValue,
                    style: AppTextStyles.body.copyWith(color: color)),
              ],
            ),
          ),
          Text(vital.delta,
              style: AppTextStyles.caption.copyWith(color: deltaColor)),
          const SizedBox(width: 10),
          SparkWidget(
            dataPoints: [68, 70, 72, 71, 73, 72, 74],
            color: color,
            width: 48,
            height: 24,
          ),
        ],
      ),
    );
  }
}

class _ActivityBars extends StatelessWidget {
  final List<String> days;
  final List<double> values;

  const _ActivityBars({required this.days, required this.values});

  @override
  Widget build(BuildContext context) {
    const maxHeight = 80.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(days.length, (i) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 28,
              height: values[i] * maxHeight,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(days[i], style: AppTextStyles.caption),
          ],
        );
      }),
    );
  }
}

class _VitalDelta {
  final String name;
  final IconData icon;
  final String avgValue;
  final String delta;
  final bool isPositive;
  final VitalDisplayStatus status;

  const _VitalDelta(this.name, this.icon, this.avgValue, this.delta,
      this.isPositive, this.status);
}
