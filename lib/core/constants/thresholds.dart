// Vital threshold constants — WHO/AHA/ESC clinical guidelines.
import '../../models/vital_reading.dart';

class VitalThresholds {
  VitalThresholds._();

  // ── Heart Rate — 60–100 bpm normal for BOTH genders (AHA/ESC) ─────────────
  static const Map<String, Map<String, double>> _heartRate = {
    'resting': {
      'emergencyLow': 40,
      'warningLow': 50,
      'stableLow': 55,
      'normalLow': 60,
      'normalHigh': 100,
      'stableHigh': 105,
      'warningHigh': 120,
      'emergencyHigh': 150,
    },
    'walking': {
      'emergencyLow': 45,
      'warningLow': 55,
      'normalLow': 65,
      'normalHigh': 130,
      'warningHigh': 155,
      'emergencyHigh': 175,
    },
    'running': {
      'emergencyLow': 50,
      'warningLow': 60,
      'normalLow': 80,
      'normalHigh': 180,
      'warningHigh': 200,
      'emergencyHigh': 220,
    },
    'lyingDown': {
      'emergencyLow': 35,
      'warningLow': 45,
      'normalLow': 55,
      'normalHigh': 90,
      'warningHigh': 110,
      'emergencyHigh': 140,
    },
  };

  // ── SpO2 — normal 95–100%; below 92% = critical (WHO) ─────────────────────
  static const double spo2Normal    = 95;   // ≥95 = normal
  static const double spo2StableLow = 93;   // 93–95 = borderline
  static const double spo2WarningLow = 92;  // 92–93 = warning; <92 = emergency

  // ── HRV (SDNN) — gender-specific lower-normal bound ───────────────────────
  // Male  : normal ≥50 ms  |  Female: normal ≥45 ms
  static const double _hrvNormalMale    = 50;
  static const double _hrvStableLowMale = 35;   // 35–50 = stable
  static const double _hrvWarningLowMale = 20;  // 20–35 = warning; <20 = emergency

  static const double _hrvNormalFemale    = 45;
  static const double _hrvStableLowFemale = 30;  // 30–45 = stable
  static const double _hrvWarningLowFemale = 18; // 18–30 = warning; <18 = emergency

  // ── Respiration Rate — 12–20 /min normal for both genders (WHO) ───────────
  static const double rrEmergencyLow = 5;
  static const double rrWarningLow   = 8;
  static const double rrNormalLow    = 12;
  static const double rrNormalHigh   = 20;
  static const double rrWarningHigh  = 25;
  static const double rrEmergencyHigh = 30;

  static const double emergencyConfidenceGate = 70.0;

  // ── Accessors ──────────────────────────────────────────────────────────────

  // HR is gender-neutral — same thresholds for male and female.
  static Map<String, double> hrThresholdsFor(ActivityType activity,
      {String gender = 'male'}) {
    return _heartRate[activity.name] ?? _heartRate['resting']!;
  }

  static double hrvNormalFor(String gender) =>
      gender.toLowerCase() == 'female' ? _hrvNormalFemale : _hrvNormalMale;

  static double hrvStableLowFor(String gender) =>
      gender.toLowerCase() == 'female'
          ? _hrvStableLowFemale
          : _hrvStableLowMale;

  static double hrvWarningLowFor(String gender) =>
      gender.toLowerCase() == 'female'
          ? _hrvWarningLowFemale
          : _hrvWarningLowMale;
}
