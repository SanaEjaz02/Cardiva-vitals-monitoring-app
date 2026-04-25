import '../models/health_event.dart';
import '../services/cloud_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';

class EmergencyTrigger {
  EmergencyTrigger._();

  static Future<void> handle({
    required HealthEvent event,
    required String userName,
    required String userPhone,
    required String contactPhone,
    required String userId,
  }) async {
    if (!event.isEmergency) return;

    // Step 1: Get GPS location (best-effort — don't block if it fails)
    String mapsLink = 'Location unavailable';
    double lat = 0, lng = 0;
    try {
      final position = await LocationService.getCurrentPosition();
      lat = position.latitude;
      lng = position.longitude;
      mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    } catch (_) {}

    // Step 2: Build SMS message
    final r = event.reading;
    final alertType = r.fallDetected ? 'FALL DETECTED' : 'CRITICAL VITALS';
    final message = '''
⚠️ CARDIVA $alertType ALERT ⚠️
Patient: $userName
Status: ${event.overallStatus.name.toUpperCase()}
Fall Detected: ${r.fallDetected ? 'YES' : 'No'}

Vitals at time of alert:
• Heart Rate: ${r.heartRate.toStringAsFixed(1)} BPM (${event.hrStatus.name})
• SpO2: ${r.spO2.toStringAsFixed(1)}% (${event.spo2Status.name})
• HRV: ${r.hrv.toStringAsFixed(1)} ms (${event.hrvStatus.name})
• Respiration: ${r.respirationRate.toStringAsFixed(1)} br/min (${event.respirationStatus.name})
• Activity: ${r.activity.name}

📍 $mapsLink
''';

    // Step 3: Open SMS app for the primary emergency contact (url_launcher)
    // Fire-and-forget; user confirms and sends from the native SMS app.
    if (contactPhone.isNotEmpty) {
      SmsService.sendSms(to: contactPhone, message: message).catchError((_) {});
    }

    // Step 4: Log alert to cloud (non-blocking)
    CloudService().saveAlert(
      userId,
      message,
      r.fallDetected ? 'fall_detection' : 'critical_vitals',
      lat,
      lng,
    ).catchError((_) {});

    // Step 5: Show in-app high-priority notification
    NotificationService.showEmergencyNotification(
      '🚨 CARDIVA Emergency',
      event.statusMessage,
    ).catchError((_) {});
  }
}
