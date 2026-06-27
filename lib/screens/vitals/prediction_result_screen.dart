import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/health_status_engine.dart';
import '../../engine/emergency_trigger.dart';
import '../../models/alert_class.dart';
import '../../models/health_event.dart';
import '../../models/ml_prediction.dart';
import '../../models/vital_reading.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PredictionResultScreen extends ConsumerStatefulWidget {
  final MlPrediction prediction;
  final VitalReading reading;

  const PredictionResultScreen({
    super.key,
    required this.prediction,
    required this.reading,
  });

  @override
  ConsumerState<PredictionResultScreen> createState() =>
      _PredictionResultScreenState();
}

class _PredictionResultScreenState
    extends ConsumerState<PredictionResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _alertSent = false;
  bool _alertSending = false;

  AlertClass get _cls => widget.prediction.alertClass;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (_cls == AlertClass.emergency) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoAlert());
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  HealthEvent _buildHealthEvent() {
    final event = HealthStatusEngine.analyze(widget.reading);
    return HealthEvent(
      reading: widget.reading,
      hrStatus: event.hrStatus,
      spo2Status: event.spo2Status,
      hrvStatus: event.hrvStatus,
      respirationStatus: event.respirationStatus,
      alertClass: widget.prediction.alertClass,
      vitalsHighRisk: widget.prediction.vitalsHighRisk,
      confidenceScore: widget.prediction.confidenceScore,
    );
  }

  Future<void> _autoAlert() async {
    if (_alertSent || _alertSending) return;
    setState(() => _alertSending = true);
    try {
      final user = ref.read(userProvider);
      await EmergencyTrigger.handle(
        event: _buildHealthEvent(),
        userName: user?.name ?? 'Patient',
        userPhone: user?.phone ?? '',
        userId: user?.id ?? 'demo-user-001',
      );
      if (mounted) {
        setState(() => _alertSent = true);
        _showAlertSentDialog();
      }
    } finally {
      if (mounted) setState(() => _alertSending = false);
    }
  }

  void _showAlertSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text('Alert Sent', style: AppTextStyles.h2),
            ],
          ),
          content: Text(
            'Emergency alert has been sent to all your linked guardians via Cardiva Chat. '
            'Tap OK to open the chat.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!mounted) return;
                // Clear the analysis stack and land on the guardian chat list.
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.patientChat,
                  (route) => route.isFirst,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askAndSendAlert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Text('Send Emergency Alert?', style: AppTextStyles.h2),
          ],
        ),
        content: Text(
          'This will notify your guardians via SMS with your current location.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _autoAlert();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI Analysis Result', style: AppTextStyles.h1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildVitalsCard(),
            const SizedBox(height: 20),
            _buildConfidenceCard(),
            const SizedBox(height: 20),
            if (_cls != AlertClass.normal) _buildActionCard(),
            if (_cls == AlertClass.normal) _buildNormalFooter(),
            const SizedBox(height: 16),
            _buildAskAiCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color get _bgColor => switch (_cls) {
        AlertClass.emergency => AppColors.dangerBg,
        AlertClass.fallAlert => AppColors.warningBg,
        AlertClass.vitalsAlert => AppColors.warningBg,
        AlertClass.normal => AppColors.successBg,
      };

  Color get _accentColor => switch (_cls) {
        AlertClass.emergency => AppColors.danger,
        AlertClass.fallAlert => AppColors.warning,
        AlertClass.vitalsAlert => AppColors.warning,
        AlertClass.normal => AppColors.success,
      };

  IconData get _heroIcon => switch (_cls) {
        AlertClass.emergency => Icons.emergency_rounded,
        AlertClass.fallAlert => Icons.personal_injury_rounded,
        AlertClass.vitalsAlert => Icons.monitor_heart_rounded,
        AlertClass.normal => Icons.check_circle_rounded,
      };

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pulsing icon for emergency/alert states
          _cls == AlertClass.normal
              ? Icon(_heroIcon, color: _accentColor, size: 64)
              : AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: 1.0 + _pulseCtrl.value * 0.08,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_heroIcon, color: _accentColor, size: 40),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.prediction.alertClass.shortLabel,
              style: AppTextStyles.caption
                  .copyWith(color: _accentColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.prediction.alertClass.label,
            style: AppTextStyles.h1.copyWith(
              color: _accentColor,
              fontSize: 28,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.prediction.analysisMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard() {
    final r = widget.reading;
    return _ResultCard(
      title: 'Measured Vitals',
      icon: Icons.favorite_rounded,
      children: [
        _VitalRow(
          label: 'Heart Rate',
          value: '${r.heartRate.toStringAsFixed(1)} bpm',
          alert: widget.prediction.vitalsHighRisk,
        ),
        _VitalRow(
          label: 'SpO₂',
          value: '${r.spO2.toStringAsFixed(1)}%',
          alert: widget.prediction.vitalsHighRisk,
        ),
        _VitalRow(
          label: 'HRV',
          value: '${r.hrv.toStringAsFixed(1)} ms',
          alert: widget.prediction.vitalsHighRisk,
        ),
        _VitalRow(
          label: 'Respiration',
          value: '${r.respirationRate.toStringAsFixed(1)} /min',
          alert: widget.prediction.vitalsHighRisk,
        ),
        _VitalRow(
          label: 'Fall Detected',
          value: widget.prediction.fallDetected ? 'YES' : 'No',
          alert: widget.prediction.fallDetected,
          valueColor: widget.prediction.fallDetected
              ? AppColors.danger
              : AppColors.success,
        ),
      ],
    );
  }

  Widget _buildConfidenceCard() {
    final conf = widget.prediction.confidenceScore;
    return _ResultCard(
      title: 'Model Confidence',
      icon: Icons.psychology_rounded,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: conf / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${conf.toStringAsFixed(1)}%',
              style: AppTextStyles.body.copyWith(
                  color: _accentColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          conf >= 80
              ? 'High confidence — result is reliable.'
              : conf >= 60
                  ? 'Moderate confidence — consider re-checking vitals.'
                  : 'Low confidence — please verify readings manually.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildActionCard() {
    if (_cls == AlertClass.emergency) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Text('Emergency Alert',
                    style: AppTextStyles.h2
                        .copyWith(color: AppColors.danger)),
              ],
            ),
            const SizedBox(height: 10),
            if (_alertSending)
              Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.danger)),
                  const SizedBox(width: 10),
                  Text('Sending alert to guardians…',
                      style: AppTextStyles.body),
                ],
              )
            else if (_alertSent)
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text('Alert sent to guardians.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.success)),
                ],
              )
            else
              Text(
                'Alert was not sent automatically. Tap below to retry.',
                style: AppTextStyles.body,
              ),
            if (!_alertSent && !_alertSending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _autoAlert,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Emergency Alert Now'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Class 2 or 3 — ask user
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('Emergency Alert',
                  style:
                      AppTextStyles.h2.copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _alertSent
                ? 'Alert sent to guardians.'
                : 'Do you want to notify your guardians?',
            style: AppTextStyles.body.copyWith(
              color: _alertSent ? AppColors.success : null,
            ),
          ),
          if (!_alertSent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _alertSending ? null : _askAndSendAlert,
                icon: _alertSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                    _alertSending ? 'Sending…' : 'Send Emergency Alert'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNormalFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All vitals are within normal range. No action required.',
              style: AppTextStyles.body.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskAiCard() {
    final r = widget.reading;
    final p = widget.prediction;
    final query =
        'I just got an AI analysis result. Here are my vitals:\n'
        '• Heart Rate: ${r.heartRate.toStringAsFixed(0)} bpm\n'
        '• SpO₂: ${r.spO2.toStringAsFixed(1)}%\n'
        '• HRV: ${r.hrv.toStringAsFixed(0)} ms\n'
        '• Respiration: ${r.respirationRate.toStringAsFixed(0)} /min\n'
        '• Fall Detected: ${p.fallDetected ? "YES" : "No"}\n'
        '• Status: ${p.alertClass.label}\n'
        '• Confidence: ${p.confidenceScore.toStringAsFixed(1)}%\n\n'
        'The AI said: "${p.analysisMessage}"\n\n'
        'What does this mean for my health? What should I do?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9B6DD6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF9B6DD6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF9B6DD6), size: 18),
              const SizedBox(width: 8),
              Text('Ask Cardiva AI',
                  style: AppTextStyles.h2
                      .copyWith(color: const Color(0xFF9B6DD6))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Get an explanation of your results from Cardiva AI.',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B6DD6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pushNamed(
                context,
                AppRouter.chat,
                arguments: query,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask Cardiva AI about this result'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ResultCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 16, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.h2),
            ],
          ),
          const Divider(color: AppColors.divider),
          ...children,
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool alert;
  final Color? valueColor;

  const _VitalRow({
    required this.label,
    required this.value,
    required this.alert,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ??
        (alert ? AppColors.danger : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.body
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
