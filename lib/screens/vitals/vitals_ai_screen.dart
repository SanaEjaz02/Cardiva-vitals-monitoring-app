import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/alert_class.dart';
import '../../models/vital_reading.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/user_provider.dart';
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
  double _hr = 72;
  double _spo2 = 98;
  double _hrv = 55;
  double _rr = 16;
  ActivityType _activity = ActivityType.resting;

  // ── Accelerometer ─────────────────────────────────────────────────────────
  double _ax = 0.0;
  double _ay = 9.8;
  double _az = 0.0;

  bool _loading = false;
  bool _liveMode = true;
  bool _emergencyDialogOpen = false;

  // ── Countdown ticker ──────────────────────────────────────────────────────
  Timer? _countdownTimer;
  Duration _timeToNext = const Duration(minutes: 5);

  // ── Accel magnitude (Newton-Raphson sqrt) ─────────────────────────────────
  double get _mag {
    final v = _ax * _ax + _ay * _ay + _az * _az;
    if (v <= 0) return 0;
    double x = v, last = 0;
    while ((x - last).abs() > 0.0001) {
      last = x;
      x = (x + v / x) / 2;
    }
    return x;
  }

  bool get _isFall => _mag > 25.0 || _mag < 3.0;

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
      }

      _startCountdownTicker();
    });
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = ref.read(analysisHistoryProvider.notifier).nextAnalysisAt;
      setState(() {
        if (next != null) {
          final rem = next.difference(DateTime.now());
          _timeToNext = rem.isNegative ? Duration.zero : rem;
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countdownTimer?.cancel();
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

  // ── Interval picker ───────────────────────────────────────────────────────
  void _pickInterval(BuildContext context) {
    // Options in minutes; displayed as hours
    const options = [60, 120, 240, 360, 720];
    final current = ref.read(analysisIntervalMinProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Auto-Analysis Interval', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (m) {
                  final hrs = m ~/ 60;
                  final label = hrs == 1 ? '1 hour' : '$hrs hours';
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      m == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: m == current
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: m == current
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: m == current
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      ref
                          .read(analysisHistoryProvider.notifier)
                          .setInterval(m);
                      _startCountdownTicker();
                      Navigator.pop(ctx);
                    },
                  );
                },
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
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

    // Live health event → auto emergency
    ref.listen(healthEventProvider, (_, next) {
      final event = next.valueOrNull;
      if (event == null || !mounted) return;
      if (event.alertClass == AlertClass.emergency) {
        _handleLiveEmergency();
      } else if (event.alertClass == AlertClass.vitalsAlert ||
          event.alertClass == AlertClass.fallAlert) {
        NotificationService.showWarningNotification(
          '⚠️ ${event.alertClass.label}',
          event.statusMessage,
        ).catchError((_) {});
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
                _buildProfileBanner(user),
                const SizedBox(height: 12),
                _buildAutoAnalysisCard(intervalMin),
                const SizedBox(height: 12),
                _buildVitalsCard(),
                const SizedBox(height: 12),
                _buildAccelCard(),
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
  AppBar _buildAppBar(int intervalMin) {
    return AppBar(
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            size: 20, color: AppColors.textPrimary),
        onPressed: () =>
            widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
      ),
      title: Text('AI Monitor', style: AppTextStyles.h1),
      actions: [
        // Interval chip
        GestureDetector(
          onTap: () => _pickInterval(context),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  intervalMin < 60
                      ? '$intervalMin min'
                      : '${intervalMin ~/ 60}h',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_drop_down_rounded,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
        // Live badge
        GestureDetector(
          onTap: () => setState(() => _liveMode = !_liveMode),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _liveMode
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.divider.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _liveMode
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.divider,
              ),
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
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.pause_circle_outline_rounded,
                      size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  _liveMode ? 'Live' : 'Paused',
                  style: AppTextStyles.caption.copyWith(
                    color:
                        _liveMode ? AppColors.success : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Auto-analysis status card ─────────────────────────────────────────────
  Widget _buildAutoAnalysisCard(int intervalMin) {
    final last = ref.watch(lastAnalysisProvider);
    final isAnalyzing =
        ref.read(analysisHistoryProvider.notifier).isAnalyzing;

    final totalSec = intervalMin * 60;
    final remainSec = _timeToNext.inSeconds.clamp(0, totalSec);
    final progress =
        totalSec > 0 ? (totalSec - remainSec) / totalSec : 0.0;

    final countdownStr = _fmtCountdown(_timeToNext);

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

          // Progress bar + countdown
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                isAnalyzing ? 'Analyzing now…' : 'Next in $countdownStr',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Every ${intervalMin == 1 ? '1 min' : '$intervalMin min'}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtCountdown(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    return '${diff.inHours}h ago';
  }

  // ── Profile banner ────────────────────────────────────────────────────────
  Widget _buildProfileBanner(dynamic user) {
    final age = user?.age ?? 35;
    final height = user?.heightCm ?? 170.0;
    final weight = user?.weightKg ?? 70.0;
    final bmi = user?.bmi ?? 24.2;
    final gender = user?.gender ?? 'Male';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 10, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primaryBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient profile used for analysis',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$gender · Age $age · ${height.toStringAsFixed(0)} cm · '
                  '${weight.toStringAsFixed(1)} kg · BMI ${bmi.toStringAsFixed(1)}',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            hint: 'Normal ≥95%',
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
            hint: 'Normal >50 ms',
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
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.directions_walk_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Activity', style: AppTextStyles.body),
              const Spacer(),
              DropdownButton<ActivityType>(
                value: _activity,
                underline: const SizedBox(),
                style: AppTextStyles.body.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
                items: ActivityType.values
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(_activityLabel(a)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _activity = v);
                },
              ),
            ],
          ),
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
    if (v < 90) return AppColors.danger;
    if (v < 95) return AppColors.warning;
    return AppColors.success;
  }

  Color _hrvColor(double v) {
    if (v < 20) return AppColors.danger;
    if (v < 50) return AppColors.warning;
    return AppColors.success;
  }

  Color _rrColor(double v) {
    if (v < 5 || v > 30) return AppColors.danger;
    if (v < 12 || v > 20) return AppColors.warning;
    return AppColors.success;
  }

  // ── Accelerometer card ────────────────────────────────────────────────────
  Widget _buildAccelCard() {
    return _Card(
      title: 'Accelerometer',
      icon: Icons.screen_rotation_alt_rounded,
      iconColor: AppColors.secondary,
      child: Column(
        children: [
          _SliderRow(
            icon: Icons.arrow_forward_rounded,
            label: 'X axis',
            value: _ax,
            unit: 'm/s²',
            min: -30,
            max: 30,
            hint: 'Lateral',
            trackColor: AppColors.secondary,
            onChanged: (v) => setState(() => _ax = v),
          ),
          _SliderRow(
            icon: Icons.arrow_upward_rounded,
            label: 'Y axis',
            value: _ay,
            unit: 'm/s²',
            min: -30,
            max: 30,
            hint: 'Forward / backward',
            trackColor: AppColors.secondary,
            onChanged: (v) => setState(() => _ay = v),
          ),
          _SliderRow(
            icon: Icons.vertical_align_center_rounded,
            label: 'Z axis',
            value: _az,
            unit: 'm/s²',
            min: -30,
            max: 30,
            hint: 'Vertical (resting ≈ 9.8)',
            trackColor: AppColors.secondary,
            onChanged: (v) => setState(() => _az = v),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isFall ? AppColors.dangerBg : AppColors.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isFall
                    ? AppColors.danger.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isFall
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: _isFall ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Magnitude ${_mag.toStringAsFixed(1)} m/s²  ·  '
                    '${_isFall ? "Fall range detected" : "Normal resting ≈ 9.8"}',
                    style: AppTextStyles.caption.copyWith(
                      color: _isFall ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

