import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final VitalDisplayStatus status;

  const StatusBadge({super.key, required this.label, required this.status});

  factory StatusBadge.fromStatus(VitalDisplayStatus status) {
    final label = switch (status) {
      VitalDisplayStatus.normal => 'Normal',
      VitalDisplayStatus.warning => 'Warning',
      VitalDisplayStatus.critical => 'Critical',
    };
    return StatusBadge(label: label, status: status);
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final bg = AppColors.statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
