import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ConfidenceIndicator extends StatelessWidget {
  final double score;

  const ConfidenceIndicator({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(score);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 72,
              height: 72,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (_, value, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      backgroundColor: AppColors.primaryLightest,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: score),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, v, __) => Text(
                        '${v.toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confidence Score',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labelFor(score),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _interpretFor(score),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(double s) {
    if (s >= 80) return AppColors.emergency;
    if (s >= 60) return AppColors.warning;
    if (s >= 40) return const Color(0xFFFFA726);
    return AppColors.normal;
  }

  String _labelFor(double s) {
    if (s >= 80) return 'Very High';
    if (s >= 60) return 'High';
    if (s >= 40) return 'Moderate';
    if (s >= 20) return 'Low';
    return 'Very Low';
  }

  String _interpretFor(double s) {
    if (s >= 80) return 'Emergency response triggered';
    if (s >= 60) return 'Alert logged to history';
    if (s >= 40) return 'In-app warning shown';
    if (s >= 20) return 'Logged, no alert';
    return 'Likely sensor noise â€” ignored';
  }
}
