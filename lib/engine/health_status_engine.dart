import '../core/constants/thresholds.dart';
import '../models/health_event.dart';
import '../models/vital_reading.dart';
import '../models/vital_status.dart';
import 'confidence_engine.dart';
import 'vital_classifier.dart';

class HealthStatusEngine {
  HealthStatusEngine._();

  static HealthEvent analyze(VitalReading reading) {
    // Step 1: classify each vital
    final hrStatus = VitalClassifier.classifyHeartRate(reading.heartRate, reading.activity);
    final spo2Status = VitalClassifier.classifySpO2(reading.spO2);
    final hrvStatus = VitalClassifier.classifyHRV(reading.hrv);
    final rrStatus = VitalClassifier.classifyRespirationRate(reading.respirationRate);

    final statuses = [hrStatus, spo2Status, hrvStatus, rrStatus];

    // Step 2: confidence score (must be calculated before overall status)
    final confidence = ConfidenceEngine.calculate(statuses, reading.activity);

    // Step 3: emergency decision tree (priority order)
    VitalStatus overall;
    bool isEmergency;
    String message;

    final hasEmergencyVital = statuses.any((s) => s == VitalStatus.emergency);
    final hasWarningVital = statuses.any((s) => s == VitalStatus.warning);
    final hasStableVital = statuses.any((s) => s == VitalStatus.stable);

    if (reading.fallDetected) {
      overall = VitalStatus.emergency;
      isEmergency = true;
      message = 'Fall detected. Emergency alert triggered.';
    } else if (hasEmergencyVital && confidence >= VitalThresholds.emergencyConfidenceGate) {
      overall = VitalStatus.emergency;
      isEmergency = true;
      message = 'Critical vitals detected. Emergency alert triggered.';
    } else if (hasEmergencyVital) {
      overall = VitalStatus.warning;
      isEmergency = false;
      message = 'Abnormal readings detected. Monitoring closely.';
    } else if (hasWarningVital) {
      overall = VitalStatus.warning;
      isEmergency = false;
      message = 'Some vitals require attention.';
    } else if (hasStableVital) {
      overall = VitalStatus.stable;
      isEmergency = false;
      message = 'Vitals are slightly outside normal range.';
    } else {
      overall = VitalStatus.normal;
      isEmergency = false;
      message = 'All vitals are normal.';
    }

    return HealthEvent(
      reading: reading,
      hrStatus: hrStatus,
      spo2Status: spo2Status,
      hrvStatus: hrvStatus,
      respirationStatus: rrStatus,
      overallStatus: overall,
      confidenceScore: confidence,
      isEmergency: isEmergency,
      statusMessage: message,
    );
  }
}
