import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SparkWidget extends StatelessWidget {
  final List<double> dataPoints;
  final Color color;
  final double width;
  final double height;

  const SparkWidget({
    super.key,
    required this.dataPoints,
    required this.color,
    this.width = 60,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.length < 2) {
      return SizedBox(width: width, height: height);
    }

    final spots = dataPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: (dataPoints.length - 1).toDouble(),
          minY: dataPoints.reduce((a, b) => a < b ? a : b) - 2,
          maxY: dataPoints.reduce((a, b) => a > b ? a : b) + 2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}
