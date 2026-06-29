import '../models/alert_class.dart';
import '../models/health_event.dart';
import '../models/vital_reading.dart';
import '../models/vital_status.dart';
import 'confidence_engine.dart';
import 'vital_classifier.dart';

class HealthStatusEngine {
  HealthStatusEngine._();

  static HealthEvent analyze(VitalReading reading) {
    // ── Step 1: Vital model — classify each vital independently ──────────────
    final hrStatus =
        VitalClassifier.classifyHeartRate(reading.heartRate, reading.activity);
    final spo2Status = VitalClassifier.classifySpO2(reading.spO2);
    final hrvStatus = VitalClassifier.classifyHRV(reading.hrv);
    final rrStatus =
        VitalClassifier.classifyRespirationRate(reading.respirationRate);

    // ── Step 2: Vitals model output — High Risk if any vital is warning/emergency
    final vitalsHighRisk = [hrStatus, spo2Status, hrvStatus, rrStatus]
        .any((s) => s == VitalStatus.warning || s == VitalStatus.emergency);

    // ── Step 3: Fall model output ─────────────────────────────────────────────
    final fallDetected = reading.fallDetected;

    // ── Step 4: 4-class decision ─────────────────────────────────────────────────
    final alertClass = switch ((fallDetected, vitalsHighRisk)) {
      (true, true) => AlertClass.emergency,
      (true, false) => AlertClass.fallAlert,
      (false, true) => AlertClass.vitalsAlert,
      _ => AlertClass.normal,
    };

    // ── Step 5: Confidence score (for display) ────────────────────────────────
    final confidence = ConfidenceEngine.calculate(
      [hrStatus, spo2Status, hrvStatus, rrStatus],
      reading.activity,
    );

    return HealthEvent(
      reading: reading,
      hrStatus: hrStatus,
      spo2Status: spo2Status,
      hrvStatus: hrvStatus,
      respirationStatus: rrStatus,
      alertClass: alertClass,
      vitalsHighRisk: vitalsHighRisk,
      confidenceScore: confidence,
    );
  }
}
