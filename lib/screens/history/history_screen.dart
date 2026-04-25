import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/history_provider.dart';
import 'widgets/vital_chart.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = [
    (label: 'Heart Rate', icon: Icons.favorite_rounded),
    (label: 'SpOâ‚‚', icon: Icons.water_drop_rounded),
    (label: 'HRV', icon: Icons.show_chart_rounded),
    (label: 'Respiration', icon: Icons.air_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${history.length} readings',
                style: TextStyle(
                    fontSize: 11, color: AppColors.primary),
              ),
              backgroundColor: AppColors.primaryLightest,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          tabs: _tabs
              .map((t) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 14),
                        const SizedBox(width: 4),
                        Text(t.label),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: List.generate(
          _tabs.length,
          (i) => _ChartCard(readings: history, vitalIndex: i),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List readings;
  final int vitalIndex;

  const _ChartCard({required this.readings, required this.vitalIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardBg,
        child: SizedBox(
          height: double.infinity,
          child: VitalChart(
            readings: readings.cast(),
            vitalIndex: vitalIndex,
          ),
        ),
      ),
    );
  }
}
