import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'ring_widget.dart';

class VitalCardAtom extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final double percent;
  final VitalDisplayStatus status;
  final VoidCallback? onTap;

  const VitalCardAtom({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.percent,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 16,
              offset: Offset(0, 2),
            ),
          ],
          border: Border(
            bottom: BorderSide(color: color, width: 3),
          ),
        ),
        child: Stack(
          children: [
            // Status dot
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RingWidget(
                  percent: percent,
                  color: color,
                  size: 56,
                  strokeWidth: 5,
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
