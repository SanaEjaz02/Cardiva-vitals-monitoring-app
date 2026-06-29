import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/thresholds.dart';
import '../../models/analysis_record.dart';
import '../../models/vital_reading.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/vital_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/atoms/spark_widget.dart';
import '../../router/app_router.dart';

class VitalsScreen extends ConsumerWidget {
  final VoidCallback? onOpenAi;
  const VitalsScreen({super.key, this.onOpenAi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingAsync = ref.watch(latestReadingProvider);
    final history = ref.watch(analysisHistoryProvider);
    final reading = readingAsync.valueOrNull;

    final recent =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    final vitals = reading != null
        ? _buildVitalRows(reading, recent)
        : _fallbackVitalRows(recent);

    String updatedText = 'Connecting…';
    Color dotColor = AppColors.warning;
    if (reading != null) {
      dotColor = AppColors.success;
      final diff = DateTime.now().difference(reading.timestamp);
      if (diff.inSeconds < 5) {
        updatedText = 'Just now';
      } else if (diff.inSeconds < 60) {
        updatedText = '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        updatedText = '${diff.inMinutes}m ago';
      } else {
        updatedText = '${diff.inHours}h ago';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          // ── Gradient header (matches AI Monitor style) ──────────────────
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 3)),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Vitals',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2)),
                            Text('Live health metrics',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.2)),
                          ],
                        ),
                      ),
                      // Status dot
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(updatedText,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Optional AI Monitor chip ────────────────────────────────────
          if (onOpenAi != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: GestureDetector(
                onTap: onOpenAi,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
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
            ),
            Expanded(
              child: vitals.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      itemCount: vitals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) =>
                          _VitalListCard(vital: vitals[i]),
                    ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: onOpenAi ??
                    () => Navigator.pushNamed(context, AppRouter.vitalsAi),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 18),
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
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Vitals Analysis',
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                'Analyze live band data and trigger emergency response.',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
    );
  }

  List<_VitalRow> _buildVitalRows(
      VitalReading r, List<AnalysisRecord> recent) {
    final hrSpark = recent.isNotEmpty
        ? recent.map((x) => x.heartRate).toList()
        : [r.heartRate, r.heartRate];
    final spo2Spark = recent.isNotEmpty
        ? recent.map((x) => x.spo2).toList()
        : [r.spO2, r.spO2];
    final hrvSpark = recent.isNotEmpty
        ? recent.map((x) => x.hrv).toList()
        : [r.hrv, r.hrv];
    final rrSpark = recent.isNotEmpty
        ? recent.map((x) => x.respirationRate).toList()
        : [r.respirationRate, r.respirationRate];

    return [
      _VitalRow(
        'Heart Rate',
        Icons.favorite_rounded,
        r.heartRate.toStringAsFixed(0),
        'bpm',
        _hrStatus(r.heartRate, r.activity),
        'heartRate',
        hrSpark,
      ),
      _VitalRow(
        'SpO₂',
        Icons.air_rounded,
        r.spO2.toStringAsFixed(0),
        '%',
        _spo2Status(r.spO2),
        'spo2',
        spo2Spark,
      ),
      _VitalRow(
        'HRV',
        Icons.timeline_rounded,
        r.hrv.toStringAsFixed(0),
        'ms',
        _hrvStatus(r.hrv),
        'hrv',
        hrvSpark,
      ),
      _VitalRow(
        'Respiration',
        Icons.waves_rounded,
        r.respirationRate.toStringAsFixed(0),
        '/min',
        _rrStatus(r.respirationRate),
        'respiration',
        rrSpark,
      ),
      _VitalRow(
        'Activity',
        Icons.directions_walk_rounded,
        _activityLabel(r.activity),
        '',
        VitalDisplayStatus.normal,
        'activity',
        [],
      ),
      _VitalRow(
        'Fall Detection',
        Icons.shield_outlined,
        r.fallDetected ? 'Fall!' : 'Safe',
        '',
        r.fallDetected
            ? VitalDisplayStatus.critical
            : VitalDisplayStatus.normal,
        'fallDetection',
        [],
      ),
    ];
  }

  List<_VitalRow> _fallbackVitalRows(List<AnalysisRecord> recent) {
    if (recent.isEmpty) return [];
    final last = recent.last;
    final hrSpark = recent.map((x) => x.heartRate).toList();
    final spo2Spark = recent.map((x) => x.spo2).toList();
    final hrvSpark = recent.map((x) => x.hrv).toList();
    final rrSpark = recent.map((x) => x.respirationRate).toList();
    return [
      _VitalRow('Heart Rate', Icons.favorite_rounded,
          last.heartRate.toStringAsFixed(0), 'bpm',
          _hrStatus(last.heartRate, ActivityType.resting), 'heartRate', hrSpark),
      _VitalRow('SpO₂', Icons.air_rounded,
          last.spo2.toStringAsFixed(0), '%',
          _spo2Status(last.spo2), 'spo2', spo2Spark),
      _VitalRow('HRV', Icons.timeline_rounded,
          last.hrv.toStringAsFixed(0), 'ms',
          _hrvStatus(last.hrv), 'hrv', hrvSpark),
      _VitalRow('Respiration', Icons.waves_rounded,
          last.respirationRate.toStringAsFixed(0), '/min',
          _rrStatus(last.respirationRate), 'respiration', rrSpark),
      _VitalRow('Activity', Icons.directions_walk_rounded, '--', '',
          VitalDisplayStatus.normal, 'activity', []),
      _VitalRow('Fall Detection', Icons.shield_outlined, '--', '',
          VitalDisplayStatus.normal, 'fallDetection', []),
    ];
  }
}

// ── Status helpers ────────────────────────────────────────────────────────────

VitalDisplayStatus _hrStatus(double hr, ActivityType activity) {
  final t = VitalThresholds.hrThresholdsFor(activity);
  if (hr < (t['emergencyLow'] ?? 40) || hr > (t['emergencyHigh'] ?? 150)) {
    return VitalDisplayStatus.critical;
  }
  if (hr < (t['warningLow'] ?? 50) || hr > (t['warningHigh'] ?? 120)) {
    return VitalDisplayStatus.warning;
  }
  return VitalDisplayStatus.normal;
}

VitalDisplayStatus _spo2Status(double spo2) {
  if (spo2 < VitalThresholds.spo2WarningLow) return VitalDisplayStatus.critical;
  if (spo2 < VitalThresholds.spo2StableLow) return VitalDisplayStatus.warning;
  return VitalDisplayStatus.normal;
}

VitalDisplayStatus _hrvStatus(double hrv) {
  if (hrv < VitalThresholds.hrvWarningLow) return VitalDisplayStatus.critical;
  if (hrv < VitalThresholds.hrvStableLow) return VitalDisplayStatus.warning;
  return VitalDisplayStatus.normal;
}

VitalDisplayStatus _rrStatus(double rr) {
  if (rr < VitalThresholds.rrEmergencyLow ||
      rr > VitalThresholds.rrEmergencyHigh) {
    return VitalDisplayStatus.critical;
  }
  if (rr < VitalThresholds.rrWarningLow || rr > VitalThresholds.rrWarningHigh) {
    return VitalDisplayStatus.warning;
  }
  return VitalDisplayStatus.normal;
}

String _activityLabel(ActivityType a) => switch (a) {
      ActivityType.resting => 'Resting',
      ActivityType.walking => 'Walking',
      ActivityType.running => 'Running',
      ActivityType.lyingDown => 'Lying Down',
    };

// ── Widgets ───────────────────────────────────────────────────────────────────

class _VitalListCard extends StatelessWidget {
  final _VitalRow vital;
  const _VitalListCard({required this.vital});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(vital.status);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
          context, '${AppRouter.vitalsDetail}/${vital.routeId}'),
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(vital.icon, color: color, size: 20),
                const SizedBox(height: 2),
                Text(vital.name, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vital.unit.isEmpty
                        ? vital.value
                        : '${vital.value} ${vital.unit}',
                    style: AppTextStyles.h2.copyWith(
                      color: color,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge.fromStatus(vital.status),
                const SizedBox(height: 6),
                if (vital.sparkData.length >= 2)
                  SparkWidget(
                    dataPoints: vital.sparkData,
                    color: color,
                    width: 60,
                    height: 24,
                  )
                else
                  const SizedBox(width: 60, height: 24),
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
  final List<double> sparkData;

  _VitalRow(this.name, this.icon, this.value, this.unit, this.status,
      this.routeId, this.sparkData);
}
