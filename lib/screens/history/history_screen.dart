import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/spark_widget.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../router/app_router.dart';

enum _HistoryTab { daily, weekly, monthly }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  _HistoryTab _tab = _HistoryTab.daily;
  DateTime _currentDate = DateTime(2025, 4, 25);
  int _currentMonth = 4;
  int _currentYear = 2025;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('History', style: AppTextStyles.h1),
            ),
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
                        color: active ? AppColors.primary : Colors.transparent,
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
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
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
                      date: _currentDate,
                      month: _currentMonth,
                      year: _currentYear,
                      onPrev: () => setState(() {
                        if (_tab == _HistoryTab.daily) {
                          _currentDate = _currentDate
                              .subtract(const Duration(days: 1));
                        } else {
                          _currentMonth =
                              _currentMonth == 1 ? 12 : _currentMonth - 1;
                        }
                      }),
                      onNext: () => setState(() {
                        if (_tab == _HistoryTab.daily) {
                          _currentDate =
                              _currentDate.add(const Duration(days: 1));
                        } else {
                          _currentMonth =
                              _currentMonth == 12 ? 1 : _currentMonth + 1;
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_tab == _HistoryTab.daily) ..._dailyContent(),
                    if (_tab == _HistoryTab.weekly) ..._weeklyContent(),
                    if (_tab == _HistoryTab.monthly) ..._monthlyContent(),
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

  List<Widget> _dailyContent() {
    const vitals = [
      ('Heart Rate', '72 bpm', VitalDisplayStatus.normal),
      ('SpO₂', '95%', VitalDisplayStatus.normal),
      ('HRV', '42 ms', VitalDisplayStatus.normal),
      ('Respiration', '16/min', VitalDisplayStatus.normal),
      ('Activity', 'Walking', VitalDisplayStatus.normal),
      ('Fall Detection', 'Safe', VitalDisplayStatus.normal),
    ];
    return vitals
        .map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DailySummaryCard(
                  name: v.$1, value: v.$2, status: v.$3),
            ))
        .toList();
  }

  List<Widget> _weeklyContent() {
    const vitals = [
      ('Heart Rate', VitalDisplayStatus.normal, '↑ 2%'),
      ('SpO₂', VitalDisplayStatus.warning, '↓ 1%'),
      ('HRV', VitalDisplayStatus.normal, '↑ 4%'),
      ('Respiration', VitalDisplayStatus.normal, '→ 0%'),
      ('Activity', VitalDisplayStatus.normal, '↑ 8%'),
      ('Fall Detection', VitalDisplayStatus.normal, '→ 0%'),
    ];
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: vitals
            .map((v) => _WeeklyMiniCard(
                name: v.$1, status: v.$2, trend: v.$3))
            .toList(),
      ),
    ];
  }

  List<Widget> _monthlyContent() {
    const vitals = [
      ('Heart Rate', VitalDisplayStatus.normal, '↑ 3%', 'Apr 12', 'Apr 3'),
      ('SpO₂', VitalDisplayStatus.warning, '↓ 2%', 'Apr 1', 'Apr 21'),
      ('HRV', VitalDisplayStatus.normal, '↑ 5%', 'Apr 18', 'Apr 5'),
      ('Respiration', VitalDisplayStatus.normal, '→ 0%', 'Apr 10', 'Apr 28'),
      ('Activity', VitalDisplayStatus.normal, '↑ 12%', 'Apr 22', 'Apr 2'),
      ('Fall Detection', VitalDisplayStatus.normal, '→ 0%', '—', '—'),
    ];
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: vitals
            .map((v) => _MonthlyMiniCard(
                name: v.$1,
                status: v.$2,
                trend: v.$3,
                bestDay: v.$4,
                worstDay: v.$5))
            .toList(),
      ),
    ];
  }
}

class _DateNav extends StatelessWidget {
  final _HistoryTab tab;
  final DateTime date;
  final int month;
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNav({
    required this.tab,
    required this.date,
    required this.month,
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  String get _label {
    if (tab == _HistoryTab.daily) {
      const days = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    } else if (tab == _HistoryTab.weekly) {
      return 'Apr 19 – Apr 25';
    } else {
      const monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${monthNames[month - 1]} $year';
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

class _DailySummaryCard extends StatelessWidget {
  final String name;
  final String value;
  final VitalDisplayStatus status;

  const _DailySummaryCard({
    required this.name,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final spark = [70.0, 72.0, 71.0, 73.0, 74.0, 72.0, 73.0, 72.0, 74.0, 72.0];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
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
          SparkWidget(dataPoints: spark, color: color),
        ],
      ),
    );
  }
}

class _WeeklyMiniCard extends StatelessWidget {
  final String name;
  final VitalDisplayStatus status;
  final String trend;
  const _WeeklyMiniCard(
      {required this.name, required this.status, required this.trend});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final trendColor = trend.startsWith('↑')
        ? AppColors.success
        : (trend.startsWith('↓') ? AppColors.warning : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Expanded(
            child: SparkWidget(
              dataPoints: [68, 70, 72, 71, 73, 72, 74],
              color: color,
              width: double.infinity,
              height: 40,
            ),
          ),
          const SizedBox(height: 6),
          Text(trend,
              style: AppTextStyles.caption.copyWith(color: trendColor)),
        ],
      ),
    );
  }
}

class _MonthlyMiniCard extends StatelessWidget {
  final String name;
  final VitalDisplayStatus status;
  final String trend;
  final String bestDay;
  final String worstDay;
  const _MonthlyMiniCard(
      {required this.name,
      required this.status,
      required this.trend,
      required this.bestDay,
      required this.worstDay});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final trendColor = trend.startsWith('↑')
        ? AppColors.success
        : (trend.startsWith('↓') ? AppColors.warning : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          SparkWidget(
            dataPoints: List.generate(30, (i) => 68 + (i % 5).toDouble()),
            color: color,
            width: double.infinity,
            height: 28,
          ),
          const SizedBox(height: 4),
          Text(trend, style: AppTextStyles.caption.copyWith(color: trendColor)),
          const SizedBox(height: 4),
          Text('Best: $bestDay',
              style: AppTextStyles.caption.copyWith(fontSize: 10)),
          Text('Worst: $worstDay',
              style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

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
              color: AppColors.shadowSm, blurRadius: 16, offset: Offset(0, 2)),
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
            'Generate a summary of your $rangeLabel health data',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.weeklyReport),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share Report'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
