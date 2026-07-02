import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_class.dart';
import '../../models/vital_reading.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/vital_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../report/health_report_screen.dart';
import 'prediction_result_screen.dart';

class VitalsAiScreen extends ConsumerStatefulWidget {
  /// When embedded in the main PageView, provide this so the back button
  /// animates back to Dashboard instead of popping the navigator.
  final VoidCallback? onBack;

  const VitalsAiScreen({super.key, this.onBack});

  @override
  ConsumerState<VitalsAiScreen> createState() => _VitalsAiScreenState();
}

class _VitalsAiScreenState extends ConsumerState<VitalsAiScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  // ── Vitals (band / manual) ────────────────────────────────────────────────
  double _hr = 60;
  double _spo2 = 95;
  double _hrv = 50;
  double _rr = 12;
  ActivityType _activity = ActivityType.resting;

  // ── Accelerometer (internal — updated from live reading, not exposed in UI) ──
  double _ax = 0.0;
  double _ay = 9.8;
  double _az = 0.0;

  bool _loading = false;
  bool _liveMode = true;
  bool _emergencyDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Prime the analysis provider (starts the background timer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisHistoryProvider); // ensures timer is running

      final reading = ref.read(latestReadingProvider).valueOrNull;
      if (reading != null && mounted) {
        setState(() {
          _hr = reading.heartRate.clamp(30, 220);
          _spo2 = reading.spO2.clamp(80, 100);
          _hrv = reading.hrv.clamp(5, 100);
          _rr = reading.respirationRate.clamp(3, 35);
          _activity = reading.activity;
        });
      } else {
        // Band not connected — use the last dashboard analysis values
        final last = ref.read(lastAnalysisProvider);
        if (last != null && mounted) {
          setState(() {
            _hr = last.heartRate.clamp(30, 220);
            _spo2 = last.spo2.clamp(80, 100);
            _hrv = last.hrv.clamp(5, 100);
            _rr = last.respirationRate.clamp(3, 35);
          });
        }
      }

    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Manual analysis → navigates to result screen ──────────────────────────
  Future<void> _runAnalysis() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(analysisHistoryProvider.notifier)
          .analyzeNow(
            heartRate: _hr,
            spo2: _spo2,
            hrv: _hrv,
            respirationRate: _rr,
            activity: _activity.name,
            accelX: _ax,
            accelY: _ay,
            accelZ: _az,
          );

      if (!mounted) return;
      final reading = VitalReading(
        heartRate: _hr,
        spO2: _spo2,
        hrv: _hrv,
        respirationRate: _rr,
        activity: _activity,
        fallDetected: result.fallDetected,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PredictionResultScreen(prediction: result, reading: reading),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Emergency response (from live band event) ─────────────────────────────
  void _handleLiveEmergency() {
    if (_emergencyDialogOpen || !mounted) return;
    _emergencyDialogOpen = true;

    NotificationService.showEmergencyNotification(
      'CARDIVA Emergency',
      'Critical vitals detected. HR: ${_hr.toStringAsFixed(0)} bpm  ·  SpO₂: ${_spo2.toStringAsFixed(0)}%',
    ).catchError((_) {});

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.dangerBg,
        title: Row(
          children: [
            const Icon(Icons.emergency_rounded,
                color: AppColors.danger, size: 24),
            const SizedBox(width: 10),
            Text('Emergency Detected',
                style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
          ],
        ),
        content: Text(
          'Band reporting critical vitals.\n'
          'HR: ${_hr.toStringAsFixed(0)} bpm  ·  SpO₂: ${_spo2.toStringAsFixed(0)}%\n\n'
          'Run full AI analysis?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _emergencyDialogOpen = false;
            },
            child: Text('Dismiss',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _emergencyDialogOpen = false;
              _runAnalysis();
            },
            child: const Text('Analyze & Alert'),
          ),
        ],
      ),
    ).then((_) => _emergencyDialogOpen = false);
  }


  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final intervalMin = ref.watch(analysisIntervalMinProvider);

    // Live band → update sliders
    ref.listen(latestReadingProvider, (_, next) {
      final reading = next.valueOrNull;
      if (reading == null || !mounted || !_liveMode) return;
      setState(() {
        _hr = reading.heartRate.clamp(30, 220);
        _spo2 = reading.spO2.clamp(80, 100);
        _hrv = reading.hrv.clamp(5, 100);
        _rr = reading.respirationRate.clamp(3, 35);
        _activity = reading.activity;
      });
    });

    // Live health event → only handle emergency dialog here.
    // Vitals/fall alert notifications are handled globally with debounce
    // in AnalysisHistoryNotifier._listenForThresholdAlerts().
    ref.listen(healthEventProvider, (_, next) {
      final event = next.valueOrNull;
      if (event == null || !mounted) return;
      if (event.alertClass == AlertClass.emergency) {
        _handleLiveEmergency();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: _buildAppBar(intervalMin),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _buildAutoAnalysisCard(intervalMin),
                const SizedBox(height: 12),
                _buildTrendChart(),
                const SizedBox(height: 12),
                _buildVitalsCard(),
                const SizedBox(height: 8),
                _buildLiveActivityCard(),
                const SizedBox(height: 8),
                _buildLiveFallCard(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(int intervalMin) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
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
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                size: 20, color: Colors.white),
            onPressed: () =>
                widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('AI Monitor',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2)),
                  Text('Real-time vitals analysis',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.2)),
                ],
              ),
            ],
          ),
          actions: [
            // Live / Paused toggle badge
            GestureDetector(
              onTap: () => setState(() => _liveMode = !_liveMode),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _liveMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_liveMode)
                      FadeTransition(
                        opacity: _pulseCtrl,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.pause_circle_outline_rounded,
                          size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      _liveMode ? 'Live' : 'Paused',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Auto-analysis status card ─────────────────────────────────────────────
  Widget _buildAutoAnalysisCard(int intervalMin) {
    final last = ref.watch(lastAnalysisProvider);
    final isAnalyzing =
        ref.read(analysisHistoryProvider.notifier).isAnalyzing;

    // Card gradient based on last result
    Color cardColor1;
    Color cardColor2;
    Color statusBadgeColor;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    if (last == null) {
      cardColor1 = AppColors.primary;
      cardColor2 = AppColors.primaryDeep;
      statusBadgeColor = Colors.white.withValues(alpha: 0.2);
      statusTextColor = Colors.white;
      statusLabel = 'WAITING';
      statusIcon = Icons.hourglass_empty_rounded;
    } else {
      switch (last.prediction.alertClass) {
        case AlertClass.emergency:
          cardColor1 = AppColors.danger;
          cardColor2 = const Color(0xFFB91C1C);
          statusBadgeColor = Colors.white.withValues(alpha: 0.2);
          statusTextColor = Colors.white;
          statusLabel = 'EMERGENCY';
          statusIcon = Icons.emergency_rounded;
        case AlertClass.fallAlert:
        case AlertClass.vitalsAlert:
          cardColor1 = AppColors.warning;
          cardColor2 = const Color(0xFFD97706);
          statusBadgeColor = Colors.white.withValues(alpha: 0.2);
          statusTextColor = Colors.white;
          statusLabel = last.prediction.alertClass.label;
          statusIcon = Icons.warning_amber_rounded;
        case AlertClass.normal:
          cardColor1 = AppColors.success;
          cardColor2 = const Color(0xFF059669);
          statusBadgeColor = Colors.white.withValues(alpha: 0.2);
          statusTextColor = Colors.white;
          statusLabel = 'NORMAL';
          statusIcon = Icons.check_circle_outline_rounded;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor1, cardColor2],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cardColor1.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Auto-Analysis',
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
              const Spacer(),
              if (isAnalyzing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBadgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusTextColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: statusTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Last result vitals (if any)
          if (last != null) ...[
            Text(
              'HR ${last.heartRate.toStringAsFixed(0)}  ·  '
              'SpO₂ ${last.spo2.toStringAsFixed(0)}%  ·  '
              'HRV ${last.hrv.toStringAsFixed(0)} ms  ·  '
              'RR ${last.respirationRate.toStringAsFixed(0)}/min',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last: ${_timeAgo(last.timestamp)}  ·  Confidence ${last.prediction.confidenceScore.toStringAsFixed(0)}%',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'Waiting for band data…',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            isAnalyzing ? 'Analyzing now…' : 'Auto-analysis every $intervalMin min',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    return '${diff.inHours}h ago';
  }

  // ── 4-vital trend charts (2×2 grid, last 10 analysis records) ───────────
  Widget _buildTrendChart() {
    final records = ref.watch(analysisHistoryProvider);
    final recent =
        records.length > 10 ? records.sublist(records.length - 10) : records;
    final hasData = recent.length >= 2;

    List<FlSpot> spots(List<double> vals) => vals.isEmpty
        ? [const FlSpot(0, 0)]
        : vals
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();

    final hrVals   = recent.map((r) => r.heartRate).toList();
    final spo2Vals = recent.map((r) => r.spo2).toList();
    final hrvVals  = recent.map((r) => r.hrv).toList();
    final rrVals   = recent.map((r) => r.respirationRate).toList();

    final spanLabel = hasData
        ? '${_hhmm(recent.first.timestamp)} – ${_hhmm(recent.last.timestamp)}'
        : 'Waiting for data…';

    return _Card(
      title: 'Vitals Trend',
      icon: Icons.show_chart_rounded,
      iconColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(spanLabel, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniChart(
                  label: 'Heart Rate',
                  unit: 'bpm',
                  color: AppColors.danger,
                  spots: spots(hrVals),
                  minY: 40, maxY: 160,
                  currentValue: hrVals.isNotEmpty ? hrVals.last : null,
                  normalRange: '60–100 bpm',
                  hasData: hasData,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniChart(
                  label: 'SpO₂',
                  unit: '%',
                  color: AppColors.primary,
                  spots: spots(spo2Vals),
                  minY: 85, maxY: 100,
                  currentValue: spo2Vals.isNotEmpty ? spo2Vals.last : null,
                  normalRange: '≥95%  ·  crit <92%',
                  hasData: hasData,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniChart(
                  label: 'HRV',
                  unit: 'ms',
                  color: const Color(0xFF7C3AED),
                  spots: spots(hrvVals),
                  minY: 0, maxY: 100,
                  currentValue: hrvVals.isNotEmpty ? hrvVals.last : null,
                  normalRange: '≥50 ms (M)  ·  ≥45 (F)',
                  hasData: hasData,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniChart(
                  label: 'Resp. Rate',
                  unit: '/min',
                  color: AppColors.success,
                  spots: spots(rrVals),
                  minY: 0, maxY: 35,
                  currentValue: rrVals.isNotEmpty ? rrVals.last : null,
                  normalRange: '12–20 /min',
                  hasData: hasData,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Vitals card ───────────────────────────────────────────────────────────
  Widget _buildVitalsCard() {
    return _Card(
      title: 'Vital Signs',
      icon: Icons.monitor_heart_rounded,
      iconColor: AppColors.primary,
      child: Column(
        children: [
          _SliderRow(
            icon: Icons.favorite_rounded,
            label: 'Heart Rate',
            value: _hr,
            unit: 'bpm',
            min: 30,
            max: 220,
            hint: 'Normal 60–100',
            trackColor: _hrColor(_hr),
            onChanged: (v) => setState(() => _hr = v),
          ),
          _SliderRow(
            icon: Icons.air_rounded,
            label: 'SpO₂',
            value: _spo2,
            unit: '%',
            min: 80,
            max: 100,
            hint: 'Normal ≥95%  ·  Critical <92%',
            trackColor: _spo2Color(_spo2),
            onChanged: (v) => setState(() => _spo2 = v),
          ),
          _SliderRow(
            icon: Icons.timeline_rounded,
            label: 'HRV',
            value: _hrv,
            unit: 'ms',
            min: 5,
            max: 100,
            hint: 'Normal ≥50 ms (M)  ·  ≥45 ms (F)',
            trackColor: _hrvColor(_hrv),
            onChanged: (v) => setState(() => _hrv = v),
          ),
          _SliderRow(
            icon: Icons.waves_rounded,
            label: 'Respiration',
            value: _rr,
            unit: '/min',
            min: 3,
            max: 35,
            hint: 'Normal 12–20',
            trackColor: _rrColor(_rr),
            onChanged: (v) => setState(() => _rr = v),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivityCard() {
    const color = AppColors.primary;
    final label = _activityLabel(_activity);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSm, blurRadius: 16, offset: Offset(0, 2)),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_walk_rounded, color: color, size: 20),
              const SizedBox(height: 2),
              Text('Activity', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: AppTextStyles.h2.copyWith(color: color, fontSize: 20)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Live',
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildLiveFallCard() {
    final reading = ref.watch(latestReadingProvider).valueOrNull;
    final isFall = reading?.fallDetected ?? false;
    final color = isFall ? AppColors.danger : AppColors.success;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSm, blurRadius: 16, offset: Offset(0, 2)),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFall ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text('Fall', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isFall ? 'Fall Detected!' : 'Safe',
              style: AppTextStyles.h2.copyWith(color: color, fontSize: 20),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isFall ? 'Alert' : 'Normal',
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  String _activityLabel(ActivityType a) => switch (a) {
        ActivityType.resting => 'Resting',
        ActivityType.walking => 'Walking',
        ActivityType.running => 'Running',
        ActivityType.lyingDown => 'Lying Down',
      };

  Color _hrColor(double v) {
    if (v < 40 || v > 150) return AppColors.danger;
    if (v < 60 || v > 100) return AppColors.warning;
    return AppColors.success;
  }

  Color _spo2Color(double v) {
    if (v < 92) return AppColors.danger;
    if (v < 95) return AppColors.warning;
    return AppColors.success;
  }

  Color _hrvColor(double v) {
    if (v < 20) return AppColors.danger;
    if (v < 45) return AppColors.warning;  // covers both male(<50) and female(<45) warn zones
    return AppColors.success;
  }

  Color _rrColor(double v) {
    if (v < 5 || v > 30) return AppColors.danger;
    if (v < 12 || v > 20) return AppColors.warning;
    return AppColors.success;
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLg.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Today's Report
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HealthReportScreen()),
              ),
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: Text('Today\'s Report',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          // Analyze Now
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _runAnalysis,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology_rounded, size: 18),
              label: Text(
                _loading ? 'Analyzing…' : 'Analyze Now',
                style: AppTextStyles.body
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card widget ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 14,
              offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 17),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.h2),
            ],
          ),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

// ── Slider row ─────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final String hint;
  final Color trackColor;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.hint,
    required this.trackColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.body),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: trackColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: trackColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)} $unit',
                  style: AppTextStyles.caption.copyWith(
                      color: trackColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: trackColor,
              inactiveTrackColor: trackColor.withValues(alpha: 0.15),
              thumbColor: trackColor,
              overlayColor: trackColor.withValues(alpha: 0.12),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Text(hint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Mini chart card (one per vital) ───────────────────────────────────────

class _MiniChart extends StatelessWidget {
  final String label;
  final String unit;
  final Color color;
  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final double? currentValue;
  final String normalRange;
  final bool hasData;

  const _MiniChart({
    required this.label,
    required this.unit,
    required this.color,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.normalRange,
    this.currentValue,
    this.hasData = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Current value
          Text(
            currentValue != null
                ? '${currentValue!.toStringAsFixed(0)} $unit'
                : '—',
            style: AppTextStyles.h2.copyWith(color: color, fontSize: 17),
          ),
          const SizedBox(height: 6),
          // Line chart
          SizedBox(
            height: 58,
            child: hasData
                ? LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
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
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration.zero,
                  )
                : Center(
                    child: Text('No data yet',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ),
          ),
          const SizedBox(height: 4),
          // Normal range label
          Text(
            normalRange,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

