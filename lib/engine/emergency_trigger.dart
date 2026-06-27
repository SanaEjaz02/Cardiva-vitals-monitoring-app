import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_class.dart';
import '../models/chat_message.dart';
import '../models/health_event.dart';
import '../services/chat_service.dart';
import '../services/cloud_service.dart';
import '../services/link_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_database_service.dart';

class EmergencyTrigger {
  EmergencyTrigger._();

  // Rate-limit: don't flood guardians when vitals stay in emergency state
  // across multiple consecutive readings.
  static DateTime? _lastAlertSentAt;
  static const _alertCooldown = Duration(minutes: 5);

  static Future<void> handle({
    required HealthEvent event,
    required String userName,
    required String userPhone,
    required String userId,
  }) async {
    if (event.alertClass == AlertClass.normal) return;

    // Step 1: Get GPS location (best-effort)
    String mapsLink = 'Location unavailable';
    double lat = 0, lng = 0;
    try {
      final position = await LocationService.getCurrentPosition();
      lat = position.latitude;
      lng = position.longitude;
      mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    } catch (_) {}

    // Step 2: Build alert message
    final r = event.reading;
    final alertType = switch (event.alertClass) {
      AlertClass.emergency => 'EMERGENCY',
      AlertClass.fallAlert => 'FALL DETECTED',
      AlertClass.vitalsAlert => 'CRITICAL VITALS',
      _ => 'ALERT',
    };
    final message = '🚨 CARDIVA $alertType\n'
        'Patient: $userName\n'
        'Status: ${event.alertClass.label}\n'
        'Fall Detected: ${r.fallDetected ? 'YES' : 'No'}\n\n'
        'Vitals:\n'
        '• HR: ${r.heartRate.toStringAsFixed(1)} BPM\n'
        '• SpO2: ${r.spO2.toStringAsFixed(1)}%\n'
        '• HRV: ${r.hrv.toStringAsFixed(1)} ms\n'
        '• RR: ${r.respirationRate.toStringAsFixed(1)} br/min\n\n'
        '📍 $mapsLink';

    // Step 3: Send in-app Cardiva chat message to all linked guardians AND
    // store the full contact list (including manual phone-only guardians) for
    // the alert record. Rate-limited to once per 5 minutes.
    final now = DateTime.now();
    final canSend = _lastAlertSentAt == null ||
        now.difference(_lastAlertSentAt!) >= _alertCooldown;

    if (canSend) {
      _lastAlertSentAt = now;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? userId;
      try {
        // Fetch all guardian contacts (registered + manual phone-only)
        final contacts = await LinkService.guardianContactDetails(uid);

        final notifType = event.alertClass == AlertClass.vitalsAlert
            ? 'warning'
            : 'emergency';
        final notifTitle = '🚨 CARDIVA ${event.alertClass.label}';

        // Build a short SMS text (no emojis — some carriers strip them).
        final smsText = 'CARDIVA ALERT\n'
            'Patient: $userName\n'
            'Status: ${event.alertClass.label}\n'
            'HR: ${r.heartRate.toStringAsFixed(0)} BPM  '
            'SpO2: ${r.spO2.toStringAsFixed(0)}%\n'
            '$mapsLink';

        for (final c in contacts) {
          final gUid = (c['uid'] as String? ?? '').trim();
          final phone = (c['phone'] as String? ?? '').trim();

          // SMS: all contacts with a phone number, registered or not.
          if (phone.isNotEmpty) {
            final smsUri = Uri(
              scheme: 'sms',
              path: phone,
              queryParameters: {'body': smsText},
            );
            launchUrl(smsUri, mode: LaunchMode.externalApplication)
                .catchError((_) => false);
          }

          // In-app chat + RTDB push: only registered (linked) guardians.
          if (gUid.isEmpty) continue;

          ChatService.sendMessage(
            patientUid: uid,
            guardianUid: gUid,
            senderUid: uid,
            senderName: userName,
            text: message,
            type: MessageType.emergency,
          ).catchError((_) {});

          RealtimeDatabaseService.pushNotificationToUser(
            targetUid: gUid,
            title: notifTitle,
            body: message,
            type: notifType,
          ).catchError((_) {});
        }
      } catch (_) {}
    }

    // Step 4: Log to cloud
    if (canSend) {
      CloudService().saveAlert(
        userId,
        message,
        r.fallDetected ? 'fall_detection' : 'critical_vitals',
        lat,
        lng,
      ).catchError((_) {});
    }

    // Step 5: Show local notification
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
