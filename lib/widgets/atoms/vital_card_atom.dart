import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class VitalCardAtom extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final double percent;
  final VitalDisplayStatus status;
  final VoidCallback? onTap;
  final String lottiePath;
  final IconData icon;
  // When provided this widget is rendered instead of the Lottie asset.
  final Widget? customAnimation;

  const VitalCardAtom({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.percent,
    required this.status,
    required this.lottiePath,
    required this.icon,
    this.onTap,
    this.customAnimation,
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
                // Animation: custom widget if provided, else Lottie
                SizedBox(
                  width: 54,
                  height: 54,
                  child: customAnimation ??
                      Lottie.asset(
                        lottiePath,
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (_, __, ___) => Icon(
                          icon,
                          color: color,
                          size: 36,
                        ),
                      ),
                ),
                const SizedBox(height: 4),
                // Icon + value + unit row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 11),
                    const SizedBox(width: 3),
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
