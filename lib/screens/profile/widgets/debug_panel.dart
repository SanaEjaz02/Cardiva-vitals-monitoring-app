import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/vital_reading.dart';
import '../../../providers/vital_provider.dart';

/// Debug panel accessible from the Profile screen.
/// Injects synthetic vital readings into the BLE stream for UI testing.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(bleServiceProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFD180), width: 1.5),
      ),
      color: const Color(0xFFFFFDE7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bug_report_rounded,
                    color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Text(
                  'Developer Debug Panel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Inject synthetic readings to test UI flows without hardware.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DebugButton(
                  label: 'Normal',
                  color: AppColors.normal,
                  icon: Icons.check_circle_rounded,
                  onTap: () {
                    svc.injectReading(VitalReading(
                      heartRate: 72,
                      spO2: 98,
                      hrv: 55,
                      respirationRate: 16,
                      activity: ActivityType.resting,
                      fallDetected: false,
                    ));
                    _snack(context, 'Normal reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Warning',
                  color: AppColors.warning,
                  icon: Icons.warning_rounded,
                  onTap: () {
                    svc.injectReading(VitalReading(
                      heartRate: 115,
                      spO2: 93,
                      hrv: 22,
                      respirationRate: 24,
                      activity: ActivityType.walking,
                      fallDetected: false,
                    ));
                    _snack(context, 'Warning reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Emergency',
                  color: AppColors.emergency,
                  icon: Icons.emergency_rounded,
                  onTap: () {
                    svc.injectReading(VitalReading(
                      heartRate: 155,
                      spO2: 86,
                      hrv: 10,
                      respirationRate: 30,
                      activity: ActivityType.running,
                      fallDetected: false,
                    ));
                    _snack(context, 'Emergency reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Fall',
                  color: AppColors.emergency,
                  icon: Icons.man_rounded,
                  onTap: () {
                    svc.injectReading(VitalReading(
                      heartRate: 88,
                      spO2: 95,
                      hrv: 40,
                      respirationRate: 18,
                      activity: ActivityType.resting,
                      fallDetected: true,
                    ));
                    _snack(context, 'Fall detection injected');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _DebugButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style:
            TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: color.withValues(alpha: 0.08),
      ),
    );
  }
}
