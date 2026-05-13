import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const _idEmergency = 1;
  static const _idWarning   = 2;

  // Channel IDs
  static const _chEmergency = 'cardiva_emergency';
  static const _chWarning   = 'cardiva_warning';

  // ── Init ────────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Create notification channels
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chEmergency,
        'Emergency Alerts',
        description: 'Critical health emergency — fall or dangerous vitals.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFEF4444),
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chWarning,
        'Health Warnings',
        description: 'Vitals or fall alert requiring attention.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Request permission on Android 13+
    await android?.requestNotificationsPermission();
  }

  // ── Emergency notification (full-screen, max priority) ────────────────────

  static Future<void> showEmergencyNotification(
    String title,
    String body,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chEmergency,
        'Emergency Alerts',
        channelDescription: 'Critical health emergency.',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        ticker: 'CARDIVA Emergency',
        styleInformation: BigTextStyleInformation(''),
        color: Color(0xFFEF4444),
      ),
    );
    await _plugin.show(_idEmergency, title, body, details);
  }

  // ── Warning notification ───────────────────────────────────────────────────

  static Future<void> showWarningNotification(
    String title,
    String body,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chWarning,
        'Health Warnings',
        channelDescription: 'Health warning requiring attention.',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFF59E0B),
      ),
    );
    await _plugin.show(_idWarning, title, body, details);
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
