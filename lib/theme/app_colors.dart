import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary palette ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF489DBE);
  static const Color primaryDeep = Color(0xFF3A6C8A);
  static const Color secondary = Color(0xFF7BC2D6);
  static const Color accentTint = Color(0xFFAFD7E2);

  // ── Background ─────────────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFDFF1F5);
  static const Color bgWhite = Color(0xFFFAFAFA);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF181919);
  static const Color textSecondary = Color(0xFFAAA9A2);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ── Surface tints (derived, not raw hex) ──────────────────────────────────
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color primaryBg = Color(0xFFEFF8FB);

  // ── Divider / border ──────────────────────────────────────────────────────
  static const Color divider = Color(0xFFF0F2F7);

  // ── Shadows ───────────────────────────────────────────────────────────────
  static const Color shadowSm = Color(0x80AFD7E2); // rgba(175,215,226,.50)
  static const Color shadowLg = Color(0x1A3A6C8A); // rgba(58,108,138,.10)

  // ── Gradient helpers ──────────────────────────────────────────────────────
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.6, 1.0],
    colors: [bgLight, secondary, bgWhite],
  );

  static const LinearGradient heroCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(2.356), // 135°
    colors: [primary, primaryDeep],
  );

  static const LinearGradient emergencyOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFEF2F2), Color(0xFFFCA5A5)],
  );

  // ── Status-aware helpers ──────────────────────────────────────────────────
  static Color statusColor(VitalDisplayStatus status) {
    switch (status) {
      case VitalDisplayStatus.normal:
        return success;
      case VitalDisplayStatus.warning:
        return warning;
      case VitalDisplayStatus.critical:
        return danger;
    }
  }

  static Color statusBg(VitalDisplayStatus status) {
    switch (status) {
      case VitalDisplayStatus.normal:
        return successBg;
      case VitalDisplayStatus.warning:
        return warningBg;
      case VitalDisplayStatus.critical:
        return dangerBg;
    }
  }
}

enum VitalDisplayStatus { normal, warning, critical }
