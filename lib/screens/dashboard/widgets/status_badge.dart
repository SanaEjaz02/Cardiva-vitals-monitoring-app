import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/vital_status.dart';

class StatusBadge extends StatelessWidget {
  final VitalStatus status;
  final String message;

  const StatusBadge({super.key, required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    final bgColor = AppColors.bgForStatus(status);
    final borderColor = AppColors.borderForStatus(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(status), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(status),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(VitalStatus s) {
    switch (s) {
      case VitalStatus.normal:
        return Icons.check_circle_rounded;
      case VitalStatus.stable:
        return Icons.info_rounded;
      case VitalStatus.warning:
        return Icons.warning_rounded;
      case VitalStatus.emergency:
        return Icons.emergency_rounded;
    }
  }

  String _titleFor(VitalStatus s) {
    switch (s) {
      case VitalStatus.normal:
        return 'All Clear';
      case VitalStatus.stable:
        return 'Stable';
      case VitalStatus.warning:
        return 'Attention Required';
      case VitalStatus.emergency:
        return 'EMERGENCY';
    }
  }
}
