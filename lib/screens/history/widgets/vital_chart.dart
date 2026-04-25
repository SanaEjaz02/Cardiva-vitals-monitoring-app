import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/vital_reading.dart';

class VitalChart extends StatelessWidget {
  final List<VitalReading> readings;

  /// 0 = Heart Rate, 1 = SpOâ‚‚, 2 = HRV, 3 = Respiration
  final int vitalIndex;

  const VitalChart({
    super.key,
    required this.readings,
    required this.vitalIndex,
  });

  static const _meta = [
    (label: 'Heart Rate', unit: 'BPM', color: AppColors.emergency),
    (label: 'SpOâ‚‚', unit: '%', color: AppColors.stable),
    (label: 'HRV', unit: 'ms', color: AppColors.teal),
    (label: 'Respiration', unit: 'br/min', color: AppColors.lavender),
  ];

  double _value(VitalReading r) {
    switch (vitalIndex) {
      case 0:
        return r.heartRate;
      case 1:
        return r.spO2;
      case 2:
        return r.hrv;
      case 3:
        return r.respirationRate;
      default:
        return r.heartRate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta[vitalIndex];

    if (readings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded,
                size: 48, color: AppColors.primaryLightest),
            const SizedBox(height: 8),
            Text(
              'Waiting for dataâ€¦',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Readings are newest-first; reverse for chart left-to-right
    final sorted = readings.reversed.toList();
    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _value(e.value));
    }).toList();

    final values = spots.map((s) => s.y).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, 200.0);
    final maxY = values.reduce((a, b) => a > b ? a : b) + 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.primaryLightest,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (spots.length / 4).ceilToDouble().clamp(1, 999),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  final t = sorted[idx].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textHint),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} ${meta.unit}',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: meta.color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    meta.color.withOpacity(0.25),
                    meta.color.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }
}
