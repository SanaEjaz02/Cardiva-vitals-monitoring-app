import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/health_event.dart';
import '../../models/vital_status.dart';
import 'widgets/alert_banner.dart';

class EmergencyScreen extends StatelessWidget {
  final HealthEvent event;

  const EmergencyScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final r = event.reading;

    return Scaffold(
      backgroundColor: AppColors.emergencyBg,
      appBar: AppBar(
        backgroundColor: AppColors.emergency,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'ðŸš¨ CARDIVA EMERGENCY',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // â”€â”€ Pulsing alert banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AlertBanner(message: event.statusMessage),
            const SizedBox(height: 20),

            // â”€â”€ Timestamp â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Center(
              child: Text(
                'Detected at ${DateFormatter.dateTime(r.timestamp)}',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Triggering vitals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionCard(
              title: 'Triggered By',
              child: Column(
                children: [
                  if (r.fallDetected)
                    _VitalRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Fall Detected',
                      status: VitalStatus.emergency,
                    ),
                  _VitalRow(
                    icon: Icons.favorite_rounded,
                    label: 'Heart Rate: ${r.heartRate.toStringAsFixed(1)} BPM',
                    status: event.hrStatus,
                  ),
                  _VitalRow(
                    icon: Icons.water_drop_rounded,
                    label: 'SpOâ‚‚: ${r.spO2.toStringAsFixed(1)}%',
                    status: event.spo2Status,
                  ),
                  _VitalRow(
                    icon: Icons.show_chart_rounded,
                    label: 'HRV: ${r.hrv.toStringAsFixed(1)} ms',
                    status: event.hrvStatus,
                  ),
                  _VitalRow(
                    icon: Icons.air_rounded,
                    label:
                        'Respiration: ${r.respirationRate.toStringAsFixed(1)} br/min',
                    status: event.respirationStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // â”€â”€ Confidence score â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionCard(
              title: 'Confidence Score',
              child: Row(
                children: [
                  Text(
                    '${event.confidenceScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emergency,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.confidenceScore >= 70
                          ? 'High confidence â€” alert is real'
                          : 'Triggered by fall detection',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // â”€â”€ SMS status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _SectionCard(
              title: 'Response Actions',
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.message_rounded,
                    label: 'SMS opened for emergency contact',
                    done: true,
                  ),
                  _ActionRow(
                    icon: Icons.notifications_rounded,
                    label: 'In-app notification sent',
                    done: true,
                  ),
                  _ActionRow(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Event logged to cloud',
                    done: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // â”€â”€ False alarm button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                'Mark as False Alarm & Dismiss',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emergency,
                side: const BorderSide(color: AppColors.emergencyBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),

            // â”€â”€ Dismiss â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Dismiss',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Section card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

// â”€â”€ Vital status row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _VitalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VitalStatus status;

  const _VitalRow(
      {required this.icon, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.bgForStatus(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Action row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;

  const _ActionRow(
      {required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: AppColors.normal, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textPrimary)),
            ),
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: done ? AppColors.normal : AppColors.textHint,
              size: 18,
            ),
          ],
        ),
      );
}
