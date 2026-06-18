import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/thresholds.dart';
import '../../models/analysis_record.dart';
import '../../models/vital_reading.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/vital_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';

class VitalDetailScreen extends ConsumerStatefulWidget {
  final String vitalId;
  const VitalDetailScreen({super.key, required this.vitalId});

  @override
  ConsumerState<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends ConsumerState<VitalDetailScreen>
    with SingleTickerProviderStateMixin {
  int _selectedRange = 0; // 0=1H, 1=6H, 2=24H, 3=7D
  late AnimationController _drawInController;
  late Animation<double> _drawIn;

  static const _ranges = ['1H', '6H', '24H', '7D'];

  @override
  void initState() {
    super.initState();
    _drawInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _drawIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _drawInController, curve: Curves.easeOut),
    );
    _drawInController.forward();
  }

  @override
  void dispose() {
    _drawInController.dispose();
    super.dispose();
  }

  void _selectRange(int i) {
    setState(() => _selectedRange = i);
    _drawInController
      ..reset()
      ..forward();
  }

  Duration get _rangeDuration => switch (_selectedRange) {
        0 => const Duration(hours: 1),
        1 => const Duration(hours: 6),
        2 => const Duration(hours: 24),
        3 => const Duration(days: 7),
        _ => const Duration(hours: 1),
      };

  List<AnalysisRecord> _filtered(List<AnalysisRecord> history) {
    final cutoff = DateTime.now().subtract(_rangeDuration);
    final filtered = history.where((r) => r.timestamp.isAfter(cutoff)).toList();
    if (filtered.length < 2) {
      return history.length > 20 ? history.sublist(history.length - 20) : history;
    }
    return filtered;
  }

  double _recordValue(AnalysisRecord r) => switch (widget.vitalId) {
        'heartRate' => r.heartRate,
        'spo2' => r.spo2,
        'hrv' => r.hrv,
        'respiration' => r.respirationRate,
        _ => 0,
      };

  List<FlSpot> _chartSpots(List<AnalysisRecord> records) {
    return records.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), _recordValue(e.value)))
        .toList();
  }

  (double, double) _yBounds() => switch (widget.vitalId) {
        'heartRate' => (40.0, 160.0),
        'spo2' => (85.0, 100.0),
        'hrv' => (0.0, 100.0),
        'respiration' => (0.0, 35.0),
        _ => (0.0, 100.0),
      };

  bool get _hasChart => switch (widget.vitalId) {
        'heartRate' || 'spo2' || 'hrv' || 'respiration' => true,
        _ => false,
      };

  String get _title => switch (widget.vitalId) {
        'heartRate' => 'Heart Rate',
        'spo2' => 'SpO₂',
        'hrv' => 'HRV',
        'respiration' => 'Respiration',
        'activity' => 'Activity',
        'fallDetection' => 'Fall Detection',
        _ => 'Vital',
      };

  String get _unit => switch (widget.vitalId) {
        'heartRate' => 'bpm',
        'spo2' => '%',
        'hrv' => 'ms',
        'respiration' => '/min',
        _ => '',
      };

  String get _normalRange => switch (widget.vitalId) {
        'heartRate' => '60–100 bpm (resting)',
        'spo2' => '95–100%',
        'hrv' => '>50 ms',
        'respiration' => '12–20/min',
        _ => '',
      };

  (String, PillVariant) _computeStatus(VitalReading? reading) {
    if (reading == null) return ('—', PillVariant.outline);
    switch (widget.vitalId) {
      case 'heartRate':
        final t = VitalThresholds.hrThresholdsFor(reading.activity);
        final hr = reading.heartRate;
        if (hr < (t['emergencyLow'] ?? 40) || hr > (t['emergencyHigh'] ?? 150)) {
          return ('Critical', PillVariant.danger);
        }
        if (hr < (t['warningLow'] ?? 50) || hr > (t['warningHigh'] ?? 120)) {
          return ('Warning', PillVariant.warning);
        }
        return ('Normal', PillVariant.success);
      case 'spo2':
        if (reading.spO2 < VitalThresholds.spo2WarningLow) return ('Critical', PillVariant.danger);
        if (reading.spO2 < VitalThresholds.spo2StableLow) return ('Warning', PillVariant.warning);
        return ('Normal', PillVariant.success);
      case 'hrv':
        if (reading.hrv < VitalThresholds.hrvWarningLow) return ('Critical', PillVariant.danger);
        if (reading.hrv < VitalThresholds.hrvStableLow) return ('Warning', PillVariant.warning);
        return ('Normal', PillVariant.success);
      case 'respiration':
        final rr = reading.respirationRate;
        if (rr < VitalThresholds.rrEmergencyLow || rr > VitalThresholds.rrEmergencyHigh) {
          return ('Critical', PillVariant.danger);
        }
        if (rr < VitalThresholds.rrWarningLow || rr > VitalThresholds.rrWarningHigh) {
          return ('Warning', PillVariant.warning);
        }
        return ('Normal', PillVariant.success);
      case 'fallDetection':
        return reading.fallDetected
            ? ('Fall Detected', PillVariant.danger)
            : ('Safe', PillVariant.success);
      default:
        return ('Normal', PillVariant.success);
    }
  }

  String _currentValueStr(VitalReading? reading, List<AnalysisRecord> history) {
    if (reading != null) {
      return switch (widget.vitalId) {
        'heartRate' => reading.heartRate.toStringAsFixed(0),
        'spo2' => reading.spO2.toStringAsFixed(0),
        'hrv' => reading.hrv.toStringAsFixed(0),
        'respiration' => reading.respirationRate.toStringAsFixed(0),
        'activity' => _activityLabel(reading.activity),
        'fallDetection' => reading.fallDetected ? 'Fall!' : 'Safe',
        _ => '—',
      };
    }
    if (history.isNotEmpty) {
      final last = history.last;
      return switch (widget.vitalId) {
        'heartRate' => last.heartRate.toStringAsFixed(0),
        'spo2' => last.spo2.toStringAsFixed(0),
        'hrv' => last.hrv.toStringAsFixed(0),
        'respiration' => last.respirationRate.toStringAsFixed(0),
        _ => '—',
      };
    }
    return '—';
  }

  String _activityLabel(ActivityType a) => switch (a) {
        ActivityType.resting => 'Resting',
        ActivityType.walking => 'Walking',
        ActivityType.running => 'Running',
        ActivityType.lyingDown => 'Lying Down',
      };

  String _explainerText(String value, String status) {
    final phrase = switch (status) {
      'Normal' => 'within normal range',
      'Warning' => 'slightly outside normal range',
      'Critical' => 'at a critical level',
      _ => 'within normal range',
    };
    final advice = switch (widget.vitalId) {
      'heartRate' => status == 'Normal'
          ? 'This indicates good cardiovascular health.'
          : 'Consider resting and monitoring. Seek medical attention if it persists.',
      'spo2' => status == 'Normal'
          ? 'Your oxygen levels are healthy.'
          : 'Low oxygen can be serious. Take slow deep breaths and seek medical attention if it persists.',
      'hrv' => status == 'Normal'
          ? 'This suggests good recovery and autonomic balance.'
          : 'Consider rest and stress reduction. Chronic low HRV may indicate overtraining or stress.',
      'respiration' => status == 'Normal'
          ? 'Your breathing rate is healthy.'
          : 'Abnormal breathing rate may require attention. Consult a doctor if it persists.',
      'activity' => 'The wearable sensor continuously classifies your movement patterns.',
      'fallDetection' => value == 'Fall!'
          ? 'A fall event has been detected. Please check on the patient or contact emergency services.'
          : 'No fall events detected. The sensor monitors for sudden acceleration changes indicative of a fall.',
      _ => '',
    };
    return switch (widget.vitalId) {
      'activity' => 'Current detected activity: $value. $advice',
      'fallDetection' => advice,
      _ =>
        'Your ${_title.toLowerCase()} of $value${_unit.isEmpty ? '' : ' $_unit'} is $phrase. '
            'Normal range: $_normalRange. $advice',
    };
  }

  String _aiQuery(String value, String status, double? statMin, double? statMax, double? statAvg) {
    final statsLine = statMin != null
        ? '• Min: ${statMin.toStringAsFixed(0)}$_unit  |  Max: ${statMax!.toStringAsFixed(0)}$_unit  |  Avg: ${statAvg!.toStringAsFixed(0)}$_unit\n'
        : '';
    return 'I am reviewing my $_title vital reading.\n'
        '• Current: $value${_unit.isEmpty ? '' : ' $_unit'}  (Normal range: $_normalRange)\n'
        '$statsLine'
        '• Status: $status\n\n'
        'What does this tell me about my health? Should I be concerned about anything?';
  }

  @override
  Widget build(BuildContext context) {
    final readingAsync = ref.watch(latestReadingProvider);
    final allHistory = ref.watch(analysisHistoryProvider);
    final reading = readingAsync.valueOrNull;

    final records = _hasChart ? _filtered(allHistory) : <AnalysisRecord>[];
    final spots = _hasChart ? _chartSpots(records) : <FlSpot>[];

    final currentValue = _currentValueStr(reading, allHistory);
    final (statusLabel, pillVariant) = _computeStatus(reading);

    double? statMin, statMax, statAvg;
    if (_hasChart && records.isNotEmpty) {
      final values = records.map(_recordValue).toList();
      statMin = values.reduce(min);
      statMax = values.reduce(max);
      statAvg = values.reduce((a, b) => a + b) / values.length;
    }

    final (minY, maxY) = _yBounds();
    final chartColor = switch (pillVariant) {
      PillVariant.danger => AppColors.danger,
      PillVariant.warning => AppColors.warning,
      _ => AppColors.primary,
    };
    final int recordCount = records.length;

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_title, style: AppTextStyles.h1),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              final statsLine = statMin != null
                  ? '\nMin: ${statMin.toStringAsFixed(0)}$_unit  |  Max: ${statMax!.toStringAsFixed(0)}$_unit  |  Avg: ${statAvg!.toStringAsFixed(0)}$_unit'
                  : '';
              final text =
                  '📊 $_title Reading — Cardiva Health Monitor\n'
                  '• Current: $currentValue${_unit.isEmpty ? '' : ' $_unit'}\n'
                  '• Status: $statusLabel\n'
                  '• Normal range: $_normalRange$statsLine\n\n'
                  'Recorded at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
              Share.share(text, subject: '$_title — Cardiva');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              currentValue,
              style: AppTextStyles.numericDisplay.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (_unit.isNotEmpty)
              Text(
                _unit,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary, fontSize: 20),
              ),
            const SizedBox(height: 8),
            PillWidget(statusLabel, variant: pillVariant),
            const SizedBox(height: 24),

            if (_hasChart) ...[
              if (spots.length >= 2)
                AnimatedBuilder(
                  animation: _drawIn,
                  builder: (_, __) => SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        clipData: FlClipData(
                          top: false,
                          bottom: false,
                          left: false,
                          right: _drawIn.value < 1,
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF0F2F7),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (maxY - minY) / 4,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= recordCount) {
                                  return const SizedBox.shrink();
                                }
                                if (i == 0 ||
                                    i == recordCount - 1 ||
                                    i == recordCount ~/ 2) {
                                  final ts = records[i].timestamp;
                                  final label =
                                      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                                  return Text(label,
                                      style: AppTextStyles.caption
                                          .copyWith(fontSize: 10));
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: chartColor,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: chartColor.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'No data for selected range',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _ranges.asMap().entries.map((e) {
                  final active = e.key == _selectedRange;
                  return GestureDetector(
                    onTap: () => _selectRange(e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              active ? AppColors.primary : AppColors.accentTint,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: AppTextStyles.body.copyWith(
                          color:
                              active ? Colors.white : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (statMin != null)
                Row(
                  children: [
                    _StatCard(label: 'Min', value: statMin.toStringAsFixed(0)),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Max', value: statMax!.toStringAsFixed(0)),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Avg', value: statAvg!.toStringAsFixed(0)),
                  ],
                ),
              const SizedBox(height: 20),
            ],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What does this mean?', style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Text(
                    _explainerText(currentValue, statusLabel),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.chat,
                        arguments:
                            _aiQuery(currentValue, statusLabel, statMin, statMax, statAvg),
                      ),
                      child: Text(
                        'Ask Cardiva AI →',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}
