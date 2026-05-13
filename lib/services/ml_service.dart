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
/// 2. FALLBACK  — rule-based VitalClassifier thresholds (always available)
/// 3. FALL GATE — accelerometer magnitude heuristic on top of both
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

    // ── Feature vector (must match training order) ────────────────────────
    // [heart_rate, spo2, hrv, respiration_rate, weight_kg, height_m, bmi]
    final features = <dynamic>[
      heartRate, spo2, hrv, respirationRate, weight, height, bmi,
    ];

    // ── Step 1: Trained model inference (PRIMARY) ─────────────────────────
    bool usedTrainedModel = false;
    bool vitalsHighRisk = false;
    bool fallFromModel  = false;

    try {
      final eScore = _toDouble(emergencyModelScore(features));
      final fScore = _toDouble(fallModelScore(features));
      vitalsHighRisk  = eScore >= 0.5;
      fallFromModel   = fScore >= 0.5;
      usedTrainedModel = true;
    } catch (_) {
      // Model call failed — will use rule-based below
    }

    // ── Step 2: Rule-based fallback (if model fails or returns edge value) ─
    if (!usedTrainedModel) {
      final hrStatus   = VitalClassifier.classifyHeartRate(heartRate, activityType);
      final spo2Status = VitalClassifier.classifySpO2(spo2);
      final hrvStatus  = VitalClassifier.classifyHRV(hrv);
      final rrStatus   = VitalClassifier.classifyRespirationRate(respirationRate);
      final statuses   = [hrStatus, spo2Status, hrvStatus, rrStatus];

      vitalsHighRisk = statuses.any(
          (s) => s == VitalStatus.warning || s == VitalStatus.emergency);

      // BMI modifier for rule-based path
      if (bmi >= 35.0 || bmi < 16.0) {
        if (statuses.any((s) => s == VitalStatus.stable)) vitalsHighRisk = true;
      }

      // Age modifier for rule-based path
      if ((age >= 65 || age < 18) &&
          statuses.any((s) => s == VitalStatus.stable)) {
        vitalsHighRisk = true;
      }
    }

    // ── Step 3: Fall detection — trained model OR accelerometer heuristic ──
    final magnitude = math.sqrt(
        accelX * accelX + accelY * accelY + accelZ * accelZ);
    final accelFall  = magnitude > 25.0 || magnitude < 3.0;
    final fallDetected = fallFromModel || accelFall;

    // ── Step 4: 4-class decision (2×2 matrix) ─────────────────────────────
    final alertClass = switch ((fallDetected, vitalsHighRisk)) {
      (true,  true)  => AlertClass.emergency,
      (true,  false) => AlertClass.fallAlert,
      (false, true)  => AlertClass.vitalsAlert,
      _              => AlertClass.normal,
    };

    // ── Step 5: Confidence ────────────────────────────────────────────────
    final confidence = _confidence(
      features, bmi, fallDetected, accelFall, alertClass, usedTrainedModel);

    // ── Step 6: Analysis message ──────────────────────────────────────────
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
      // Soft classifier: take probability of positive class (last element)
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
  ) {
    // Trained model is more trustworthy than rule-based
    double base = usedTrainedModel ? 78.0 : 68.0;

    // Normal BMI → small boost
    if (bmi >= 18.5 && bmi < 25.0) base += 3.0;

    // Clear accelerometer event → extra confidence for fall classes
    if (accelFall &&
        (alertClass == AlertClass.emergency || alertClass == AlertClass.fallAlert)) {
      base += 5.0;
    }

    // Extreme vitals → high confidence in alert classes
    final spo2 = features.length > 1 ? (features[1] as num).toDouble() : 98.0;
    final hrv  = features.length > 2 ? (features[2] as num).toDouble() : 55.0;
    if (spo2 < 88 || hrv < 15) base += 10.0; // very clear emergency signal

    // Normal class with all-normal vitals → high confidence
    if (alertClass == AlertClass.normal && spo2 >= 95 && hrv >= 50) base += 8.0;

    return base.clamp(50.0, 98.0);
  }
}
