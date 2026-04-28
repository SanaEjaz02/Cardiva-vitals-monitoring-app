import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get numericDisplay => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFeatures: [const FontFeature.tabularFigures()],
        height: 1.1,
      );

  static TextStyle get numericDisplayLarge => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFeatures: [const FontFeature.tabularFigures()],
        height: 1.1,
      );

  // Convenience modifiers
  static TextStyle h1White() => h1.copyWith(color: Colors.white);
  static TextStyle h2White() => h2.copyWith(color: Colors.white);
  static TextStyle bodyWhite() => body.copyWith(color: Colors.white);
  static TextStyle captionWhite() => caption.copyWith(color: Colors.white);

  static TextStyle h1Color(Color c) => h1.copyWith(color: c);
  static TextStyle h2Color(Color c) => h2.copyWith(color: c);
  static TextStyle bodyColor(Color c) => body.copyWith(color: c);
  static TextStyle captionColor(Color c) => caption.copyWith(color: c);
  static TextStyle numericColor(Color c) => numericDisplay.copyWith(color: c);
}
