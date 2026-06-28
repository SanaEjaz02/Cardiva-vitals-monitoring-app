import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_navigator.dart';
import '../models/notification_model.dart';
import '../router/app_router.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const _idEmergency = 1;
  static const _idWarning   = 2;
  static const _idReport    = 3;
  static const _idChat      = 4;

  // Channel IDs
  static const _chEmergency = 'cardiva_emergency';
  static const _chWarning   = 'cardiva_warning';
  static const _chReports   = 'cardiva_reports';
  static const _chChat      = 'cardiva_chat';

  // Payloads — used to deep-link on notification tap
  static const _payloadVitalsAi = 'vitals_ai';
  static const _payloadReport   = 'report';

  /// Foreground callback — set by NotificationsNotifier to receive in-app notifs.
  static void Function(AppNotification)? onNewNotification;

  /// Current user role — updated by app.dart when profile loads.
  /// Prevents guardians being routed to the patient-only AI analysis screen.
  static String _currentUserRole = 'patient';
  static void setCurrentUserRole(String role) => _currentUserRole = role;

  // ── Init ─────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

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

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chReports,
        'Daily Reports',
        description: 'Automatic 24-hour health report summary.',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chChat,
        'Chat Messages',
        description: 'Messages from guardians and patients.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android?.requestNotificationsPermission();

    // Handle tap when app was completely closed and user taps notification
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        // Delay so the widget tree is ready before we push a new route.
        Future.delayed(const Duration(milliseconds: 1800), () {
          _navigateFromPayload(payload);
        });
      }
    }
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    // Small delay so the app is foregrounded before we navigate.
    Future.delayed(const Duration(milliseconds: 300), () {
      _navigateFromPayload(payload);
    });
  }

  static void _navigateFromPayload(String payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    switch (payload) {
      case _payloadVitalsAi:
        // AI analysis is patient-only — guardians must not be routed here.
        if (_currentUserRole == 'patient') {
          navigator.pushNamed(AppRouter.vitalsAi);
        }
      case _payloadReport:
        navigator.pushNamed(AppRouter.weeklyReport);
    }
  }

  // ── Chat message notification ─────────────────────────────────────────────

  static Future<void> showChatNotification(
    String title,
    String body,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chChat,
        'Chat Messages',
        channelDescription: 'Messages from guardians and patients.',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(_idChat, title, body, details);
  }

  // ── Daily report notification ─────────────────────────────────────────────

  static Future<void> showReportNotification(
    String title,
    String body,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chReports,
        'Daily Reports',
        channelDescription: 'Automatic 24-hour health report summary.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
      ),
    );
    await _plugin.show(_idReport, title, body, details,
        payload: _payloadReport);
    _pushInApp(title, body, NotifType.health);
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
    await _plugin.show(_idEmergency, title, body, details,
        payload: _payloadVitalsAi);
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
    await _plugin.show(_idWarning, title, body, details,
        payload: _payloadVitalsAi);
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
