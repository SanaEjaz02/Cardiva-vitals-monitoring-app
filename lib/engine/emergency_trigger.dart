import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_class.dart';
import '../models/health_event.dart';
import '../services/cloud_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';

class EmergencyTrigger {
  EmergencyTrigger._();

  /// Loads all registered emergency contacts and SMS-enabled attendants
  /// from SharedPreferences, scoped to the current Firebase user.
  static Future<List<String>> _loadContactPhones() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final phones = <String>[];

    final ecRaw = prefs.getString('emergency_contacts_${uid}_v1');
    if (ecRaw != null) {
      try {
        final list = jsonDecode(ecRaw) as List;
        for (final j in list) {
          final phone = (j['phone'] as String? ?? '').trim();
          if (phone.isNotEmpty) phones.add(phone);
        }
      } catch (_) {}
    }

    final attRaw = prefs.getString('attendants_${uid}_v1');
    if (attRaw != null) {
      try {
        final list = jsonDecode(attRaw) as List;
        for (final j in list) {
          final notifySms = j['notifyViaSms'] as bool? ?? true;
          final phone = (j['phone'] as String? ?? '').trim();
          if (notifySms && phone.isNotEmpty) phones.add(phone);
        }
      } catch (_) {}
    }

    return phones;
  }

  static Future<void> handle({
    required HealthEvent event,
    required String userName,
    required String userPhone,
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
    final message = '''⚠️ CARDIVA $alertType ALERT ⚠️
Patient: $userName
Status: ${event.alertClass.label}
Fall Detected: ${r.fallDetected ? 'YES' : 'No'}

Vitals at time of alert:
• Heart Rate: ${r.heartRate.toStringAsFixed(1)} BPM (${event.hrStatus.name})
• SpO2: ${r.spO2.toStringAsFixed(1)}% (${event.spo2Status.name})
• HRV: ${r.hrv.toStringAsFixed(1)} ms (${event.hrvStatus.name})
• Respiration: ${r.respirationRate.toStringAsFixed(1)} br/min (${event.respirationStatus.name})
• Activity: ${r.activity.name}

📍 $mapsLink''';

    // Step 3: Send SMS to all contacts at once, then open WhatsApp sequentially
    final phones = await _loadContactPhones();
    if (phones.isNotEmpty) {
      SmsService.sendSmsToAll(phones: phones, message: message).catchError((_) {});
      for (int i = 0; i < phones.length; i++) {
        Future.delayed(Duration(milliseconds: i * 800), () {
          SmsService.sendWhatsApp(to: phones[i], message: message).catchError((_) {});
        });
      }
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
