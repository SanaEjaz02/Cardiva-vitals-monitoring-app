import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../widgets/atoms/status_badge.dart';

class VitalDetailScreen extends StatefulWidget {
  final String vitalId;
  const VitalDetailScreen({super.key, required this.vitalId});

  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen>
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

  List<FlSpot> _chartData() {
    final data = [62, 65, 68, 72, 75, 74, 72, 70, 73, 72, 74, 71];
    return data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Heart Rate', style: AppTextStyles.h1),
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
            const SizedBox(height: 16),
            // Hero value
            Text('72',
                style: AppTextStyles.numericDisplay.copyWith(
                  color: AppColors.textPrimary,
                )),
            Text('bpm',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary, fontSize: 20)),
            const SizedBox(height: 8),
            PillWidget('Normal', variant: PillVariant.success),
            const SizedBox(height: 24),
            // Chart
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
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFFF0F2F7),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          reservedSize: 32,
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
                          interval: 2,
                          getTitlesWidget: (v, _) {
                            final labels = [
                              '9:00', '', '9:15', '', '9:30',
                              '', '9:45', '', '10:00', '', '', ''
                            ];
                            final i = v.toInt();
                            if (i < labels.length) {
                              return Text(labels[i],
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
                    maxX: 11,
                    minY: 40,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _chartData(),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Time range pills
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
                      color:
                          active ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.accentTint,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: AppTextStyles.body.copyWith(
                        color: active
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Stats row
            Row(
              children: [
                _StatCard(label: 'Min', value: '58'),
                const SizedBox(width: 12),
                _StatCard(label: 'Max', value: '89'),
                const SizedBox(width: 12),
                _StatCard(label: 'Avg', value: '72'),
              ],
            ),
            const SizedBox(height: 20),
            // AI Explainer card
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
                    'Your heart rate of 72 bpm is within the normal resting range of 60–100 bpm, indicating good cardiovascular health.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/chat'),
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
            Text(label,
                style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.h2),
          ],
        ),
      ),
    );
  }
}
