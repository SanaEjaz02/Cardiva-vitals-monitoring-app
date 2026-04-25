import 'vital_reading.dart';
import 'vital_status.dart';

class HealthEvent {
  final VitalReading reading;
  final VitalStatus hrStatus;
  final VitalStatus spo2Status;
  final VitalStatus hrvStatus;
  final VitalStatus respirationStatus;
  final VitalStatus overallStatus;
  final double confidenceScore;
  final bool isEmergency;
  final String statusMessage;

  const HealthEvent({
    required this.reading,
    required this.hrStatus,
    required this.spo2Status,
    required this.hrvStatus,
    required this.respirationStatus,
    required this.overallStatus,
    required this.confidenceScore,
    required this.isEmergency,
    required this.statusMessage,
  });

  Map<String, dynamic> toJson() => {
        'reading_id': reading.id,
        'hr_status': hrStatus.name,
        'spo2_status': spo2Status.name,
        'hrv_status': hrvStatus.name,
        'respiration_status': respirationStatus.name,
        'overall_status': overallStatus.name,
        'confidence_score': confidenceScore,
        'is_emergency': isEmergency,
        'status_message': statusMessage,
        'analyzed_at': DateTime.now().toIso8601String(),
      };
}
