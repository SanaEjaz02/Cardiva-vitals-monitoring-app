import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/vital_reading.dart';
import '../../providers/vital_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class LiveMonitorScreen extends ConsumerWidget {
  const LiveMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingAsync = ref.watch(latestReadingProvider);
    final bleService   = ref.watch(bleServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Live Monitor', style: AppTextStyles.h1),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Device info bar ──────────────────────────────────────
            _DeviceBar(
              name: bleService.deviceName,
              connected: bleService.isConnected,
            ),

            const SizedBox(height: 8),

            // ── Vitals grid ──────────────────────────────────────────
            Expanded(
              child: readingAsync.when(
                loading: () => _NoDeviceState(),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.caption),
                ),
                data: (r) => _VitalsGrid(reading: r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Device info bar ───────────────────────────────────────────────────────────

class _DeviceBar extends StatelessWidget {
  final String name;
  final bool connected;

  const _DeviceBar({required this.name, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: connected ? AppColors.successBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (connected ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          _PulseIcon(connected: connected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  connected ? 'Live data streaming' : 'Waiting for device…',
                  style: AppTextStyles.caption.copyWith(
                      color: connected
                          ? AppColors.success
                          : AppColors.warning),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connected ? AppColors.success : AppColors.warning,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              connected ? 'LIVE' : 'OFF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dot animation ─────────────────────────────────────────────────────

class _PulseIcon extends StatefulWidget {
  final bool connected;
  const _PulseIcon({required this.connected});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.connected ? AppColors.success : AppColors.warning;
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.monitor_heart_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Vitals grid ───────────────────────────────────────────────────────────────

class _VitalsGrid extends StatelessWidget {
  final VitalReading reading;

  const _VitalsGrid({required this.reading});

  String get _activityLabel {
    switch (reading.activity) {
      case ActivityType.walking:   return 'Walking';
      case ActivityType.running:   return 'Running';
      case ActivityType.lyingDown: return 'Lying Down';
      case ActivityType.resting:   return 'Resting';
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt =
        DateFormat('hh:mm:ss a').format(reading.timestamp);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Last updated timestamp
        Center(
          child: Text(
            'Last updated: $updatedAt',
            style: AppTextStyles.caption,
          ),
        ),
        const SizedBox(height: 16),

        // 2-column grid of vital cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _VitalCard(
              icon: Icons.favorite_rounded,
              color: AppColors.danger,
              label: 'Heart Rate',
              value: reading.heartRate.toStringAsFixed(0),
              unit: 'bpm',
            ),
            _VitalCard(
              icon: Icons.water_drop_rounded,
              color: AppColors.primary,
              label: 'SpO₂',
              value: reading.spO2.toStringAsFixed(0),
              unit: '%',
            ),
            _VitalCard(
              icon: Icons.graphic_eq_rounded,
              color: AppColors.secondary,
              label: 'HRV (SDNN)',
              value: reading.hrv.toStringAsFixed(1),
              unit: 'ms',
            ),
            _VitalCard(
              icon: Icons.air_rounded,
              color: AppColors.success,
              label: 'Respiration',
              value: reading.respirationRate.toStringAsFixed(1),
              unit: 'br/min',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Activity row
        _WideCard(
          icon: Icons.directions_walk_rounded,
          color: const Color(0xFF7C3AED),
          label: 'Activity',
          value: _activityLabel,
        ),

        const SizedBox(height: 12),

        // Fall detection row
        _WideCard(
          icon: reading.fallDetected
              ? Icons.warning_amber_rounded
              : Icons.shield_rounded,
          color: reading.fallDetected ? AppColors.danger : AppColors.success,
          label: 'Fall Detection',
          value: reading.fallDetected ? 'FALL DETECTED' : 'No Fall',
          valueColor: reading.fallDetected ? AppColors.danger : null,
        ),
      ],
    );
  }
}

// ── Vital card (square) ───────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  const _VitalCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
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
              color: AppColors.shadowSm,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ── No device connected state ─────────────────────────────────────────────────

class _NoDeviceState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth_searching_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No Device Connected',
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Go to Profile → Connect Device and pair your Cardiva band to see live vitals here.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wide card (full width) ────────────────────────────────────────────────────

class _WideCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color? valueColor;

  const _WideCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.valueColor,
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
              color: AppColors.shadowSm,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
