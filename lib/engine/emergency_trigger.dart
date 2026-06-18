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

  // Prevents SMS/WhatsApp flood when vitals stay in emergency state across
  // multiple consecutive readings. Notification always fires (idempotent — fixed ID).
  static DateTime? _lastSmsSentAt;
  static const _smsCooldown = Duration(minutes: 5);

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
    // Normal readings never trigger alerts.
    if (event.alertClass == AlertClass.normal) return;

    // Step 1: Get GPS location (best-effort — don't block if it fails)
    String mapsLink = 'Location unavailable';
    double lat = 0, lng = 0;
    try {
      final position = await LocationService.getCurrentPosition();
      lat = position.latitude;
      lng = position.longitude;
      mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    } catch (_) {}

    // Step 2: Build SMS message — label and alert type vary by class
    final r = event.reading;
    final alertType = switch (event.alertClass) {
      AlertClass.emergency => 'EMERGENCY',
      AlertClass.fallAlert => 'FALL DETECTED',
      AlertClass.vitalsAlert => 'CRITICAL VITALS',
      _ => 'ALERT',
    };
    final message = '''⚠️ CARDIVA $alertType ⚠️
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

    // Step 3: Send SMS/WhatsApp — rate-limited to once per 5 minutes so a
    // sustained alert reading doesn't flood contacts with messages.
    final phones = await _loadContactPhones();
    final now = DateTime.now();
    final canSendSms = _lastSmsSentAt == null ||
        now.difference(_lastSmsSentAt!) >= _smsCooldown;
    if (phones.isNotEmpty && canSendSms) {
      _lastSmsSentAt = now;
      SmsService.sendSmsToAll(phones: phones, message: message).catchError((_) {});
      for (int i = 0; i < phones.length; i++) {
        Future.delayed(Duration(milliseconds: i * 800), () {
          SmsService.sendWhatsApp(to: phones[i], message: message).catchError((_) {});
        });
      }
    }

    // Step 4: Log alert to cloud (non-blocking, same cooldown as SMS)
    if (canSendSms) {
      CloudService().saveAlert(
        userId,
        message,
        r.fallDetected ? 'fall_detection' : 'critical_vitals',
        lat,
        lng,
      ).catchError((_) {});
    }

    // Step 5: Show notification — emergency/fall get max-priority full-screen,
    // vitals alert gets high-priority warning notification.
    if (event.alertClass == AlertClass.vitalsAlert) {
      NotificationService.showWarningNotification(
        '⚠️ CARDIVA ${event.alertClass.label}',
        event.statusMessage,
      ).catchError((_) {});
    } else {
      NotificationService.showEmergencyNotification(
        '🚨 CARDIVA ${event.alertClass.label}',
        event.statusMessage,
      ).catchError((_) {});
    }
  }
}
