import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum PillVariant { success, warning, danger, primary, outline }

class PillWidget extends StatelessWidget {
  final String label;
  final PillVariant variant;

  const PillWidget(this.label, {super.key, this.variant = PillVariant.primary});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }

  (Color, Color, Color?) _colors() {
    switch (variant) {
      case PillVariant.success:
        return (AppColors.successBg, AppColors.success, null);
      case PillVariant.warning:
        return (AppColors.warningBg, AppColors.warning, null);
      case PillVariant.danger:
        return (AppColors.dangerBg, AppColors.danger, null);
      case PillVariant.primary:
        return (AppColors.primaryBg, AppColors.primary, null);
      case PillVariant.outline:
        return (Colors.transparent, AppColors.textSecondary, AppColors.textSecondary);
    }
  }
}
