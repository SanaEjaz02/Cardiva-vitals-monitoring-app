import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const _idEmergency = 1;
  static const _idWarning   = 2;

  // Channel IDs
  static const _chEmergency = 'cardiva_emergency';
  static const _chWarning   = 'cardiva_warning';

  /// Foreground callback — set by NotificationsNotifier to receive in-app notifs.
  static void Function(AppNotification)? onNewNotification;

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

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

    await android?.requestNotificationsPermission();
  }

  // ── Emergency notification ────────────────────────────────────────────────

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
        category: AndroidNotificationCategory.status,
        autoCancel: true,
        ticker: 'CARDIVA Emergency',
        styleInformation: BigTextStyleInformation(''),
        color: Color(0xFFEF4444),
      ),
    );
    await _plugin.show(_idEmergency, title, body, details);
    _pushInApp(title, body, NotifType.alert);
  }

  // ── Warning notification ──────────────────────────────────────────────────

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
        autoCancel: true,
        color: Color(0xFFF59E0B),
      ),
    );
    await _plugin.show(_idWarning, title, body, details);
    _pushInApp(title, body, NotifType.health);
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Internal: push to in-app notification list ────────────────────────────

  static void _pushInApp(String title, String body, NotifType type) {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: body,
      type: type,
    );
    // Foreground: deliver directly via callback
    if (onNewNotification != null) {
      onNewNotification!(notif);
      return;
    }
    // Background/isolate: queue in SharedPreferences for next app open
    _queuePending(notif);
  }

  static Future<void> _queuePending(AppNotification notif) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'pending_notifications';
      final raw = prefs.getString(key) ?? '[]';
      final list = jsonDecode(raw) as List;
      list.add(notif.toJson());
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {}
  }
}
