import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/analysis_record.dart';
import '../../providers/analysis_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/status_badge.dart';

enum _HistoryTab { daily, weekly, monthly }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  _HistoryTab _tab = _HistoryTab.daily;
  DateTime _selectedDay = DateTime.now();
  late AnimationController _tabAnim;
  late Animation<double> _tabFade;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _tabFade = Tween<double>(begin: 0, end: 1).animate(_tabAnim);
    _tabAnim.forward();
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  void _switchTab(_HistoryTab tab) {
    if (_tab == tab) return;
    _tabAnim.reverse().then((_) {
      setState(() => _tab = tab);
      _tabAnim.forward();
    });
  }

  // Returns records for a given calendar day
  List<AnalysisRecord> _recordsForDay(
      List<AnalysisRecord> all, DateTime day) {
    return all
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month &&
            r.timestamp.day == day.day)
        .toList();
  }

  // Returns records for Mon..Sun of the week containing [day]
  List<AnalysisRecord> _recordsForWeek(
      List<AnalysisRecord> all, DateTime day) {
    final mon = day.subtract(Duration(days: day.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    return all
        .where((r) =>
            !r.timestamp.isBefore(DateTime(mon.year, mon.month, mon.day)) &&
            r.timestamp.isBefore(
                DateTime(sun.year, sun.month, sun.day + 1)))
        .toList();
  }

  // Returns records for the calendar month of [day]
  List<AnalysisRecord> _recordsForMonth(
      List<AnalysisRecord> all, DateTime day) {
    return all
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(analysisHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('History', style: AppTextStyles.h1),
            ),
            // Tab selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _HistoryTab.values.map((tab) {
                  final active = tab == _tab;
                  final label = switch (tab) {
                    _HistoryTab.daily => 'Daily',
                    _HistoryTab.weekly => 'Weekly',
                    _HistoryTab.monthly => 'Monthly',
                  };
                  return GestureDetector(
                    onTap: () => _switchTab(tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: active
                              ? AppColors.primary
                              : AppColors.accentTint,
                        ),
                      ),
                      child: Text(
                        label,
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
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FadeTransition(
                opacity: _tabFade,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _DateNav(
                      tab: _tab,
                      day: _selectedDay,
                      onPrev: () => setState(() {
                        if (_tab == _HistoryTab.daily) {
                          _selectedDay = _selectedDay
                              .subtract(const Duration(days: 1));
                        } else if (_tab == _HistoryTab.weekly) {
                          _selectedDay = _selectedDay
                              .subtract(const Duration(days: 7));
                        } else {
                          final m = _selectedDay.month == 1
                              ? 12
                              : _selectedDay.month - 1;
                          final y = _selectedDay.month == 1
                              ? _selectedDay.year - 1
                              : _selectedDay.year;
                          _selectedDay = DateTime(y, m, 1);
                        }
                      }),
                      onNext: () => setState(() {
                        if (_tab == _HistoryTab.daily) {
                          _selectedDay =
                              _selectedDay.add(const Duration(days: 1));
                        } else if (_tab == _HistoryTab.weekly) {
                          _selectedDay =
                              _selectedDay.add(const Duration(days: 7));
                        } else {
                          final m = _selectedDay.month == 12
                              ? 1
                              : _selectedDay.month + 1;
                          final y = _selectedDay.month == 12
                              ? _selectedDay.year + 1
                              : _selectedDay.year;
                          _selectedDay = DateTime(y, m, 1);
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_tab == _HistoryTab.daily)
                      ..._dailyContent(
                          _recordsForDay(all, _selectedDay)),
                    if (_tab == _HistoryTab.weekly)
                      ..._weeklyContent(
                          _recordsForWeek(all, _selectedDay),
                          _selectedDay),
                    if (_tab == _HistoryTab.monthly)
                      ..._monthlyContent(
                          _recordsForMonth(all, _selectedDay),
                          _selectedDay),
                    const SizedBox(height: 24),
                    _HealthReportCard(tab: _tab),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Daily ────────────────────────────────────────────────────────────────

  List<Widget> _dailyContent(List<AnalysisRecord> records) {
    if (records.isEmpty) {
      return [
        const _EmptyCard(
            message: 'No analyses recorded for this day.'),
      ];
    }

    final count = records.length;
    final avgHr =
        records.map((r) => r.heartRate).reduce((a, b) => a + b) / count;
    final avgSpo2 =
        records.map((r) => r.spo2).reduce((a, b) => a + b) / count;
    final avgHrv =
        records.map((r) => r.hrv).reduce((a, b) => a + b) / count;
    final avgRr =
        records.map((r) => r.respirationRate).reduce((a, b) => a + b) /
            count;
    final normal = records
        .where((r) => !r.prediction.isEmergency && !r.prediction.fallDetected)
        .length;
    final score =
        (normal / count * 100).clamp(0, 100).round();

    VitalDisplayStatus hrStatus(double v) => v < 60 || v > 100
        ? VitalDisplayStatus.warning
        : VitalDisplayStatus.normal;
    VitalDisplayStatus spo2Status(double v) =>
        v < 95 ? VitalDisplayStatus.warning : VitalDisplayStatus.normal;
    VitalDisplayStatus hrvStatus(double v) =>
        v < 20 ? VitalDisplayStatus.warning : VitalDisplayStatus.normal;
    VitalDisplayStatus rrStatus(double v) =>
        v < 12 || v > 20 ? VitalDisplayStatus.warning : VitalDisplayStatus.normal;

    return [
      // Score card
      _ScoreCard(score: score, analysisCount: count),
      const SizedBox(height: 12),
      _DailySummaryCard(
        name: 'Heart Rate',
        value: '${avgHr.toStringAsFixed(0)} bpm',
        status: hrStatus(avgHr),
        dataPoints: records.map((r) => r.heartRate).toList(),
      ),
      const SizedBox(height: 10),
      _DailySummaryCard(
        name: 'SpO₂',
        value: '${avgSpo2.toStringAsFixed(1)}%',
        status: spo2Status(avgSpo2),
        dataPoints: records.map((r) => r.spo2).toList(),
      ),
      const SizedBox(height: 10),
      _DailySummaryCard(
        name: 'HRV',
        value: '${avgHrv.toStringAsFixed(0)} ms',
        status: hrvStatus(avgHrv),
        dataPoints: records.map((r) => r.hrv).toList(),
      ),
      const SizedBox(height: 10),
      _DailySummaryCard(
        name: 'Respiration',
        value: '${avgRr.toStringAsFixed(1)}/min',
        status: rrStatus(avgRr),
        dataPoints: records.map((r) => r.respirationRate).toList(),
      ),
    ];
  }

  // ── Weekly ───────────────────────────────────────────────────────────────

  List<Widget> _weeklyContent(
      List<AnalysisRecord> records, DateTime anchor) {
    final mon = anchor.subtract(Duration(days: anchor.weekday - 1));

    // Per-day averages
    List<_DayData> days = List.generate(7, (i) {
      final day = mon.add(Duration(days: i));
      final recs = _recordsForDay(records, day);
      return _DayData(
        label: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
        count: recs.length,
        avgHr: recs.isEmpty
            ? 0
            : recs.map((r) => r.heartRate).reduce((a, b) => a + b) /
                recs.length,
        avgSpo2: recs.isEmpty
            ? 0
            : recs.map((r) => r.spo2).reduce((a, b) => a + b) / recs.length,
        avgHrv: recs.isEmpty
            ? 0
            : recs.map((r) => r.hrv).reduce((a, b) => a + b) / recs.length,
        avgRr: recs.isEmpty
            ? 0
            : recs.map((r) => r.respirationRate).reduce((a, b) => a + b) /
                recs.length,
      );
    });

    if (records.isEmpty) {
      return [
        const _EmptyCard(
            message: 'No analyses recorded for this week.'),
      ];
    }

    return [
      _WeeklyChart(
        title: 'Heart Rate (avg bpm)',
        days: days,
        getValue: (d) => d.avgHr,
        color: const Color(0xFF0096C7),
        minY: 40,
        maxY: 140,
      ),
      const SizedBox(height: 14),
      _WeeklyChart(
        title: 'SpO₂ (avg %)',
        days: days,
        getValue: (d) => d.avgSpo2,
        color: const Color(0xFF7B5EA7),
        minY: 85,
        maxY: 100,
      ),
      const SizedBox(height: 14),
      _WeeklyChart(
        title: 'HRV (avg ms)',
        days: days,
        getValue: (d) => d.avgHrv,
        color: AppColors.success,
        minY: 0,
        maxY: 100,
      ),
      const SizedBox(height: 14),
      _WeeklyChart(
        title: 'Respiration (avg /min)',
        days: days,
        getValue: (d) => d.avgRr,
        color: AppColors.warning,
        minY: 0,
        maxY: 35,
      ),
    ];
  }

  // ── Monthly ──────────────────────────────────────────────────────────────

  List<Widget> _monthlyContent(
      List<AnalysisRecord> records, DateTime anchor) {
    if (records.isEmpty) {
      return [
        const _EmptyCard(
            message: 'No analyses recorded for this month.'),
      ];
    }

    // Group by week number within month (1-based)
    final firstDay = DateTime(anchor.year, anchor.month, 1);
    final lastDay = DateTime(anchor.year, anchor.month + 1, 0);
    final weekCount = ((lastDay.day + firstDay.weekday - 2) / 7).ceil() + 1;

    List<_WeekData> weeks = List.generate(weekCount, (i) {
      final weekStart = firstDay.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final recs = records
          .where((r) =>
              !r.timestamp.isBefore(
                  DateTime(weekStart.year, weekStart.month, weekStart.day)) &&
              r.timestamp.isBefore(
                  DateTime(weekEnd.year, weekEnd.month, weekEnd.day + 1)))
          .toList();
      return _WeekData(
        label: 'W${i + 1}',
        count: recs.length,
        avgHr: recs.isEmpty
            ? 0
            : recs.map((r) => r.heartRate).reduce((a, b) => a + b) /
                recs.length,
        avgSpo2: recs.isEmpty
            ? 0
            : recs.map((r) => r.spo2).reduce((a, b) => a + b) / recs.length,
        avgHrv: recs.isEmpty
            ? 0
            : recs.map((r) => r.hrv).reduce((a, b) => a + b) / recs.length,
        avgRr: recs.isEmpty
            ? 0
            : recs.map((r) => r.respirationRate).reduce((a, b) => a + b) /
                recs.length,
      );
    });

    return [
      _MonthlyChart(
        title: 'Heart Rate (avg bpm)',
        weeks: weeks,
        getValue: (w) => w.avgHr,
        color: const Color(0xFF0096C7),
        minY: 40,
        maxY: 140,
      ),
      const SizedBox(height: 14),
      _MonthlyChart(
        title: 'SpO₂ (avg %)',
        weeks: weeks,
        getValue: (w) => w.avgSpo2,
        color: const Color(0xFF7B5EA7),
        minY: 85,
        maxY: 100,
      ),
      const SizedBox(height: 14),
      _MonthlyChart(
        title: 'HRV (avg ms)',
        weeks: weeks,
        getValue: (w) => w.avgHrv,
        color: AppColors.success,
        minY: 0,
        maxY: 100,
      ),
      const SizedBox(height: 14),
      _MonthlyChart(
        title: 'Respiration (avg /min)',
        weeks: weeks,
        getValue: (w) => w.avgRr,
        color: AppColors.warning,
        minY: 0,
        maxY: 35,
      ),
    ];
  }
}

// ── Data helpers ──────────────────────────────────────────────────────────────

class _DayData {
  final String label;
  final int count;
  final double avgHr, avgSpo2, avgHrv, avgRr;
  const _DayData({
    required this.label,
    required this.count,
    required this.avgHr,
    required this.avgSpo2,
    required this.avgHrv,
    required this.avgRr,
  });
}

class _WeekData {
  final String label;
  final int count;
  final double avgHr, avgSpo2, avgHrv, avgRr;
  const _WeekData({
    required this.label,
    required this.count,
    required this.avgHr,
    required this.avgSpo2,
    required this.avgHrv,
    required this.avgRr,
  });
}

// ── Date navigator ────────────────────────────────────────────────────────────

class _DateNav extends StatelessWidget {
  final _HistoryTab tab;
  final DateTime day;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNav({
    required this.tab,
    required this.day,
    required this.onPrev,
    required this.onNext,
  });

  String get _label {
    const dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (tab == _HistoryTab.daily) {
      return '${dayNames[day.weekday - 1]}, ${monthNames[day.month - 1]} ${day.day}';
    } else if (tab == _HistoryTab.weekly) {
      final mon = day.subtract(Duration(days: day.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      return '${monthNames[mon.month - 1]} ${mon.day} – ${monthNames[sun.month - 1]} ${sun.day}';
    } else {
      return '${fullMonths[day.month - 1]} ${day.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              color: AppColors.textPrimary),
          onPressed: onPrev,
        ),
        Text(_label, style: AppTextStyles.h2),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textPrimary),
          onPressed: onNext,
        ),
      ],
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final int score;
  final int analysisCount;
  const _ScoreCard({required this.score, required this.analysisCount});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.danger;
    final label = score >= 80
        ? 'Good'
        : score >= 60
            ? 'Fair'
            : 'Poor';
    return Container(
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
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$score',
                    style: AppTextStyles.h2.copyWith(
                        color: color, fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Health Score',
                    style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTextStyles.h2.copyWith(color: color)),
                const SizedBox(height: 4),
                Text('$analysisCount analysis${analysisCount == 1 ? '' : 'es'} today',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily summary card ────────────────────────────────────────────────────────

class _DailySummaryCard extends StatelessWidget {
  final String name;
  final String value;
  final VitalDisplayStatus status;
  final List<double> dataPoints;

  const _DailySummaryCard({
    required this.name,
    required this.value,
    required this.status,
    required this.dataPoints,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return Container(
      padding: const EdgeInsets.all(14),
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.h2.copyWith(color: color)),
              ],
            ),
          ),
          StatusBadge.fromStatus(status),
          const SizedBox(width: 12),
          if (dataPoints.length > 1)
            SizedBox(
              width: 60,
              height: 32,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dataPoints
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Weekly chart ──────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final String title;
  final List<_DayData> days;
  final double Function(_DayData) getValue;
  final Color color;
  final double minY;
  final double maxY;

  const _WeeklyChart({
    required this.title,
    required this.days,
    required this.getValue,
    required this.color,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = days.any((d) => d.count > 0);
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: hasData
                ? BarChart(
                    BarChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY - minY) / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                days[v.toInt()].label,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: days
                          .asMap()
                          .entries
                          .map((e) => BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.count > 0
                                        ? getValue(e.value)
                                            .clamp(minY, maxY)
                                        : minY,
                                    color: e.value.count > 0
                                        ? color
                                        : AppColors.divider,
                                    width: 16,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  )
                : const Center(
                    child: Text('No data for this week',
                        style: TextStyle(color: AppColors.textSecondary))),
          ),
        ],
      ),
    );
  }
}

// ── Monthly chart ─────────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final String title;
  final List<_WeekData> weeks;
  final double Function(_WeekData) getValue;
  final Color color;
  final double minY;
  final double maxY;

  const _MonthlyChart({
    required this.title,
    required this.weeks,
    required this.getValue,
    required this.color,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = weeks.any((w) => w.count > 0);
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: hasData
                ? BarChart(
                    BarChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY - minY) / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                weeks[v.toInt()].label,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style:
                                  AppTextStyles.caption.copyWith(fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: weeks
                          .asMap()
                          .entries
                          .map((e) => BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.count > 0
                                        ? getValue(e.value)
                                            .clamp(minY, maxY)
                                        : minY,
                                    color: e.value.count > 0
                                        ? color
                                        : AppColors.divider,
                                    width: 24,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  )
                : const Center(
                    child: Text('No data for this month',
                        style: TextStyle(color: AppColors.textSecondary))),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Health report card ────────────────────────────────────────────────────────

class _HealthReportCard extends StatelessWidget {
  final _HistoryTab tab;
  const _HealthReportCard({required this.tab});

  @override
  Widget build(BuildContext context) {
    final rangeLabel = switch (tab) {
      _HistoryTab.daily => 'daily',
      _HistoryTab.weekly => 'weekly',
      _HistoryTab.monthly => 'monthly',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 16,
              offset: Offset(0, 2)),
        ],
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Report', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            'View and manage your $rangeLabel health reports',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.weeklyReport),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View Reports'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
