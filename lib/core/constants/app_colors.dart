import 'package:flutter/material.dart';
import '../../models/vital_status.dart';

class AppColors {
  AppColors._();

  // ── Scaffold & surface ────────────────────────────────────────────────────
  static const Color scaffold = Color(0xFFF0F7FF);
  static const Color cardBg = Colors.white;
  static const Color inputFill = Color(0xFFEBF4FF);

  // ── Pastel blue primary palette ───────────────────────────────────────────
  static const Color primary = Color(0xFF5B9BD5);
  static const Color primaryLight = Color(0xFF8EC6F2);
  static const Color primaryLightest = Color(0xFFD6EEFF);
  static const Color primaryDark = Color(0xFF3A7AB5);

  // ── Pastel accents ────────────────────────────────────────────────────────
  static const Color teal = Color(0xFF80CBC4);
  static const Color tealLight = Color(0xFFB2EBF2);
  static const Color lavender = Color(0xFFB3B3E7);
  static const Color lavenderLight = Color(0xFFE8E8F8);

  // ── Status colours (pastel) ───────────────────────────────────────────────
  static const Color normal = Color(0xFF81C784);
  static const Color normalBg = Color(0xFFEDF7E8);
  static const Color normalBorder = Color(0xFFA5D6A7);

  static const Color stable = Color(0xFF64B5F6);
  static const Color stableBg = Color(0xFFE3F2FD);
  static const Color stableBorder = Color(0xFF90CAF9);

  static const Color warning = Color(0xFFFFB74D);
  static const Color warningBg = Color(0xFFFFF8E1);
  static const Color warningBorder = Color(0xFFFFCC80);

  static const Color emergency = Color(0xFFE57373);
  static const Color emergencyBg = Color(0xFFFFEBEE);
  static const Color emergencyBorder = Color(0xFFEF9A9A);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E3A5F);
  static const Color textSecondary = Color(0xFF6B8CAE);
  static const Color textHint = Color(0xFF9EB6CC);

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color forStatus(VitalStatus status) {
    switch (status) {
      case VitalStatus.normal:
        return normal;
      case VitalStatus.stable:
        return stable;
      case VitalStatus.warning:
        return warning;
      case VitalStatus.emergency:
        return emergency;
    }
  }

  static Color bgForStatus(VitalStatus status) {
    switch (status) {
      case VitalStatus.normal:
        return normalBg;
      case VitalStatus.stable:
        return stableBg;
      case VitalStatus.warning:
        return warningBg;
      case VitalStatus.emergency:
        return emergencyBg;
    }
  }

  static Color borderForStatus(VitalStatus status) {
    switch (status) {
      case VitalStatus.normal:
        return normalBorder;
      case VitalStatus.stable:
        return stableBorder;
      case VitalStatus.warning:
        return warningBorder;
      case VitalStatus.emergency:
        return emergencyBorder;
    }
  }
}
