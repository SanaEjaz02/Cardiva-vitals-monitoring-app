import 'dart:math' as math;
import '../engine/generated/emergency_model_generated.dart';
import '../engine/generated/fall_model_generated.dart';
import '../engine/vital_classifier.dart';
import '../models/alert_class.dart';
import '../models/ml_prediction.dart';
import '../models/vital_reading.dart';
import '../models/vital_status.dart';

/// Hybrid inference engine:
///
/// 1. PRIMARY   — generated Dart from trained pkl models (via convert_to_dart.py)
/// 2. THRESHOLD — gender-adjusted WHO/AHA/ESC rule-based classification (always runs)
/// 3. FALL GATE — accelerometer magnitude heuristic on top of both
///
/// Final vitalsHighRisk = ML model says high-risk  OR  thresholds say high-risk.
/// This ensures neither source is silently ignored in a safety-critical context.
///
/// 4-class output (2×2 matrix):
///   Class 1 EMERGENCY    — fall=true  + vitals=high-risk
///   Class 2 FALL ALERT   — fall=true  + vitals=low-risk
///   Class 3 VITALS ALERT — fall=false + vitals=high-risk
///   Class 4 NORMAL       — fall=false + vitals=low-risk
class MlService {
  MlService._();

  static Future<MlPrediction> analyze({
    required double heartRate,
    required double spo2,
    required double hrv,
    required double respirationRate,
    required String activity,
    required double accelX,
    required double accelY,
    required double accelZ,
    double height = 1.70,  // metres
    double weight = 70.0,  // kg
    int age = 35,
    String gender = 'male',
  }) async {
    final activityType = ActivityType.values.firstWhere(
      (a) => a.name == activity,
      orElse: () => ActivityType.resting,
    );

    final bmi = height > 0 ? weight / (height * height) : 25.0;
    // Gender encoded to match training: Male=0, Female=1 (df['Gender'].map())
    final genderCode = gender.toLowerCase() == 'female' ? 1.0 : 0.0;

    // ── Feature vector — order MUST match fyp_dataset1.py feature_cols ───
    // [Heart Rate, HRV, Respiratory Rate, Oxygen Saturation,
    //  Age, Height (m), Weight (kg), Gender (0/1), BMI]
    final features = <dynamic>[
      heartRate,          // 0  Heart Rate
      hrv,                // 1  HRV (SDNN ms)
      respirationRate,    // 2  Respiratory Rate
      spo2,               // 3  Oxygen Saturation
      age.toDouble(),     // 4  Age
      height,             // 5  Height (m)
      weight,             // 6  Weight (kg)
      genderCode,         // 7  Gender 0=Male 1=Female
      bmi,                // 8  BMI
    ];

    // ── Step 1: ML model inference (PRIMARY) ─────────────────────────────────
    // usedTrainedModel is true only when the real converted model is in place.
    // The placeholder always returns 0.0 for normal vitals, so it never
    // double-fires on top of the threshold check.
    bool usedTrainedModel = false;
    bool mlVitalsHighRisk = false;
    bool fallFromModel = false;

    try {
      final eScore = _toDouble(emergencyModelScore(features));
      final fScore = _toDouble(fallModelScore(features));
      // Threshold 0.8 avoids false positives from placeholder's 0.5/0.6 scores.
      // The real GBC model's scores will naturally cluster near 0.0 or 1.0.
      mlVitalsHighRisk = eScore >= 0.8;
      fallFromModel    = fScore >= 0.5;
      usedTrainedModel = eScore > 0.0; // only claim trained if model fired
    } catch (_) {
      // Model unavailable — threshold path below covers classification
    }

    // ── Step 2: Gender-adjusted WHO/AHA/ESC threshold classification ───────
    // Always runs regardless of ML model availability.
    final hrStatus   = VitalClassifier.classifyHeartRate(heartRate, activityType, gender: gender);
    final spo2Status = VitalClassifier.classifySpO2(spo2);
    final hrvStatus  = VitalClassifier.classifyHRV(hrv, gender: gender);
    final rrStatus   = VitalClassifier.classifyRespirationRate(respirationRate);
    final statuses   = [hrStatus, spo2Status, hrvStatus, rrStatus];

    bool thresholdHighRisk =
        statuses.any((s) => s == VitalStatus.warning || s == VitalStatus.emergency);

    // BMI modifier — extreme BMI elevates stable vitals to warning
    if ((bmi >= 35.0 || bmi < 16.0) &&
        statuses.any((s) => s == VitalStatus.stable)) {
      thresholdHighRisk = true;
    }

    // Age modifier — elderly (≥65) and minors (<18) get the same upgrade
    if ((age >= 65 || age < 18) && statuses.any((s) => s == VitalStatus.stable)) {
      thresholdHighRisk = true;
    }

    // ── Step 3: Final vitalsHighRisk — ML OR threshold (medical safety: OR logic) ─
    final vitalsHighRisk = mlVitalsHighRisk || thresholdHighRisk;

    // ── Step 4: Fall detection — trained model OR accelerometer heuristic ──
    final magnitude = math.sqrt(
        accelX * accelX + accelY * accelY + accelZ * accelZ);
    final accelFall  = magnitude > 25.0 || magnitude < 3.0;
    final fallDetected = fallFromModel || accelFall;

    // ── Step 5: 4-class decision (2×2 matrix) ─────────────────────────────
    final alertClass = switch ((fallDetected, vitalsHighRisk)) {
      (true,  true)  => AlertClass.emergency,
      (true,  false) => AlertClass.fallAlert,
      (false, true)  => AlertClass.vitalsAlert,
      _              => AlertClass.normal,
    };

    // ── Step 6: Confidence ────────────────────────────────────────────────
    final confidence = _confidence(
      features, bmi, fallDetected, accelFall, alertClass,
      usedTrainedModel, thresholdHighRisk);

    // ── Step 7: Analysis message ──────────────────────────────────────────
    final bmiNote = bmi < 18.5 ? ' (BMI: low)' : bmi >= 30 ? ' (BMI: high)' : '';
    final src = usedTrainedModel ? '' : ' [rule-based]';

    final message = switch (alertClass) {
      AlertClass.emergency =>
        '🚨 EMERGENCY — Fall + critical vitals$bmiNote$src. '
            'HR: ${heartRate.toStringAsFixed(1)} bpm, SpO₂: ${spo2.toStringAsFixed(1)}%',
      AlertClass.fallAlert =>
        '⚠️ FALL ALERT — Fall detected. Vitals acceptable$bmiNote$src. '
            'HR: ${heartRate.toStringAsFixed(1)} bpm',
      AlertClass.vitalsAlert =>
        '⚠️ VITALS ALERT — Critical vitals, no fall$bmiNote$src. '
            'HR: ${heartRate.toStringAsFixed(1)} bpm, SpO₂: ${spo2.toStringAsFixed(1)}%',
      AlertClass.normal =>
        '✅ NORMAL — All clear$bmiNote$src. '
            'HR: ${heartRate.toStringAsFixed(1)} bpm, SpO₂: ${spo2.toStringAsFixed(1)}%',
    };

    return MlPrediction(
      isEmergency:     alertClass.isEmergency,
      fallDetected:    fallDetected,
      vitalsHighRisk:  vitalsHighRisk,
      confidenceScore: confidence,
      alertClass:      alertClass,
      analysisMessage: message,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Safely convert model output (double or List<double>) to a single score.
  static double _toDouble(dynamic result) {
    if (result is double) return result;
    if (result is num)    return result.toDouble();
    if (result is List && result.isNotEmpty) {
      return (result.last as num).toDouble();
    }
    return 0.0;
  }

  /// Confidence — how unambiguous is the classification?
  static double _confidence(
    List<dynamic> features,
    double bmi,
    bool fallDetected,
    bool accelFall,
    AlertClass alertClass,
    bool usedTrainedModel,
    bool thresholdHighRisk,
  ) {
    double base = usedTrainedModel ? 78.0 : 68.0;

    // Agreement between ML and threshold paths boosts confidence
    if (usedTrainedModel && thresholdHighRisk &&
        (alertClass == AlertClass.vitalsAlert || alertClass == AlertClass.emergency)) {
      base += 7.0;
    }

    // Normal BMI → small boost
    if (bmi >= 18.5 && bmi < 25.0) base += 3.0;

    // Clear accelerometer event → extra confidence for fall classes
    if (accelFall &&
        (alertClass == AlertClass.emergency || alertClass == AlertClass.fallAlert)) {
      base += 5.0;
    }

    // Extreme vitals → high confidence in alert classes
    // SpO2 is at index 3, HRV at index 1 in the 9-feature vector
    final spo2 = features.length > 3 ? (features[3] as num).toDouble() : 98.0;
    final hrv  = features.length > 1 ? (features[1] as num).toDouble() : 55.0;
    if (spo2 < 88 || hrv < 15) base += 10.0;

    // All-normal vitals → high confidence in normal class
    if (alertClass == AlertClass.normal && spo2 >= 95 && hrv >= 50) base += 8.0;

    return base.clamp(50.0, 98.0);
  }
}
