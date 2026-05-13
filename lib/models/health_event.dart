import 'alert_class.dart';
import 'vital_reading.dart';
import 'vital_status.dart';

class HealthEvent {
  final VitalReading reading;

  // Per-vital classifications (from VitalClassifier)
  final VitalStatus hrStatus;
  final VitalStatus spo2Status;
  final VitalStatus hrvStatus;
  final VitalStatus respirationStatus;

  // Combined 4-class AI output
  final AlertClass alertClass;
  final bool vitalsHighRisk;
  final double confidenceScore;

  const HealthEvent({
    required this.reading,
    required this.hrStatus,
    required this.spo2Status,
    required this.hrvStatus,
    required this.respirationStatus,
    required this.alertClass,
    required this.vitalsHighRisk,
    required this.confidenceScore,
  });

  // Derived helpers kept for backwards compatibility with EmergencyTrigger etc.
  bool get isEmergency => alertClass.isEmergency;
  String get statusMessage => alertClass.message;

  Map<String, dynamic> toJson() => {
        'reading_id': reading.id,
        'alert_class': alertClass.classNumber,
        'alert_label': alertClass.label,
        'vitals_high_risk': vitalsHighRisk,
        'fall_detected': reading.fallDetected,
        'hr_status': hrStatus.name,
        'spo2_status': spo2Status.name,
        'hrv_status': hrvStatus.name,
        'respiration_status': respirationStatus.name,
        'confidence_score': confidenceScore,
        'is_emergency': isEmergency,
        'analyzed_at': DateTime.now().toIso8601String(),
      };
}
