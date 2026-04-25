import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/vital_provider.dart';

/// Debug panel accessible from the Profile screen.
/// Allows manual injection of specific vital scenarios for UI testing.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(mockDataServiceProvider);

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
            Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: Color(0xFFF9A825), size: 20),
                const SizedBox(width: 8),
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
            Text(
              'Manually inject vital readings to test UI flows.',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
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
                    svc.injectNormal();
                    _snack(context, 'Normal reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Warning',
                  color: AppColors.warning,
                  icon: Icons.warning_rounded,
                  onTap: () {
                    svc.injectWarning();
                    _snack(context, 'Warning reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Emergency',
                  color: AppColors.emergency,
                  icon: Icons.emergency_rounded,
                  onTap: () {
                    svc.injectEmergency();
                    _snack(context, 'Emergency reading injected');
                  },
                ),
                _DebugButton(
                  label: 'Fall',
                  color: AppColors.emergency,
                  icon: Icons.man_rounded,
                  onTap: () {
                    svc.injectFall();
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
        content: Text(msg, style: TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: color.withOpacity(0.08),
      ),
    );
  }
}
