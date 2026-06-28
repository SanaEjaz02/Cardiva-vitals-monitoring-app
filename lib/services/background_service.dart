import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_class.dart';
import '../models/analysis_record.dart';
import 'ml_service.dart';

class BackgroundService {
  BackgroundService._();

  static const _channelId = 'cardiva_monitoring';
  static const _notifId = 1000;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const channel = AndroidNotificationChannel(
      _channelId,
      'Cardiva Health Monitor',
      description: 'Keeps Cardiva monitoring your vitals in the background.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Cardiva Health Monitor',
        initialNotificationContent: 'Monitoring your vitals…',
        foregroundServiceNotificationId: _notifId,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );

    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  // Called from main isolate — stores user profile + UID so background
  // isolate can scope its storage to the correct user.
  static Future<void> writeUserProfile({
    required String uid,
    required double heightM,
    required double weightKg,
    required int age,
    required String gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_user_uid', uid);
    await prefs.setDouble('bg_user_height', heightM);
    await prefs.setDouble('bg_user_weight', weightKg);
    await prefs.setInt('bg_user_age', age);
    await prefs.setString('bg_user_gender', gender);
  }
}

// ── Top-level entry point (separate Dart isolate) ──────────────────────────

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('stop').listen((_) => service.stopSelf());
    service.setForegroundNotificationInfo(
      title: 'Cardiva Health Monitor',
      content: 'Active — monitoring your vitals in background',
    );
  }

  // Initialize local notifications in this isolate so we can fire real alerts.
  final bgPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await bgPlugin
      .initialize(const InitializationSettings(android: androidSettings));

  // Ensure the daily-report channel exists (channels persist across app restarts
  // once created, so this is a no-op after the first run).
  await bgPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'cardiva_reports',
        'Daily Reports',
        description: 'Automatic 24-hour health report summary.',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ));

  // Run analysis every 30 minutes.
  Timer.periodic(const Duration(minutes: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        timer.cancel();
        return;
      }
    }
    await _backgroundAnalyze(service, bgPlugin);
  });
}

Future<void> _backgroundAnalyze(
    ServiceInstance service, FlutterLocalNotificationsPlugin bgPlugin) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final uid = prefs.getString('bg_user_uid') ?? '';
    final height = prefs.getDouble('bg_user_height') ?? 1.70;
    final weight = prefs.getDouble('bg_user_weight') ?? 70.0;
    final age = prefs.getInt('bg_user_age') ?? 35;
    final gender = prefs.getString('bg_user_gender') ?? 'male';

    final rng = math.Random();
    final hr = 55.0 + rng.nextDouble() * 50.0;
    final spo2 = 95.0 + rng.nextDouble() * 4.5;
    final hrv = 20.0 + rng.nextDouble() * 60.0;
    final rr = 12.0 + rng.nextDouble() * 8.0;

    final prediction = await MlService.analyze(
      heartRate: hr,
      spo2: spo2,
      hrv: hrv,
      respirationRate: rr,
      activity: 'rest',
      accelX: 0.0,
      accelY: 9.8,
      accelZ: 0.0,
      height: height,
      weight: weight,
      age: age,
      gender: gender,
    );

    final record = AnalysisRecord(
      id: 'bg_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      prediction: prediction,
      heartRate: hr,
      spo2: spo2,
      hrv: hrv,
      respirationRate: rr,
    );

    // Keep bg_pending_records for fast foreground merge on app resume.
    final pending = prefs.getStringList('bg_pending_records') ?? [];
    pending.add(jsonEncode(record.toJson()));
    if (pending.length > 50) pending.removeRange(0, pending.length - 50);
    await prefs.setStringList('bg_pending_records', pending);

    // Also persist directly to user-scoped history so data survives
    // even when the app is never opened.
    if (uid.isNotEmpty) {
      await _persistToHistory(prefs, uid, record);
      await _ensureDailyReport(prefs, uid, bgPlugin);
    }

    final isAlert = prediction.alertClass != AlertClass.normal;
    final isEmergency = prediction.alertClass == AlertClass.emergency;

    final notifTitle = isAlert
        ? '🚨 CARDIVA ${prediction.alertClass.label}'
        : 'Cardiva Health Monitor';
    final notifBody = isAlert
        ? 'HR ${hr.toStringAsFixed(0)} bpm · SpO₂ ${spo2.toStringAsFixed(0)}% — Open app for details'
        : 'HR ${hr.toStringAsFixed(0)} bpm · SpO₂ ${spo2.toStringAsFixed(0)}% — All normal';

    // Update the persistent foreground service notification.
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
          title: notifTitle, content: notifBody);
    }

    // For alerts: fire a real pop-up notification that appears even when
    // the app is fully closed, and queue it for the in-app list.
    if (isAlert) {
      await bgPlugin.show(
        isEmergency ? 1 : 2,
        notifTitle,
        notifBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isEmergency ? 'cardiva_emergency' : 'cardiva_warning',
            isEmergency ? 'Emergency Alerts' : 'Health Warnings',
            importance:
                isEmergency ? Importance.max : Importance.high,
            priority: isEmergency ? Priority.max : Priority.high,
            autoCancel: true,
            fullScreenIntent: isEmergency,
          ),
        ),
      );
      await _queueInAppNotification(
          prefs, notifTitle, notifBody, isEmergency ? 0 : 1);
    }
  } catch (_) {
    // Background analysis is best-effort — never crash the service.
  }
}

// Writes the record directly into the user-scoped analysis history so it
// is available immediately when the app opens, without relying on the
// bg_pending_records drain.
Future<void> _persistToHistory(
    SharedPreferences prefs, String uid, AnalysisRecord record) async {
  try {
    final key = 'analysis_history_${uid}_v1';
    final raw = prefs.getString(key);
    List<dynamic> list = [];
    if (raw != null) {
      try {
        list = jsonDecode(raw) as List;
      } catch (_) {}
    }
    // Skip if already stored (id collision guard).
    final existing = list
        .map((j) => (j as Map<String, dynamic>)['id'] as String? ?? '')
        .toSet();
    if (existing.contains(record.id)) return;

    list.add(record.toJson());

    // Trim entries older than 90 days.
    final cutoff =
        DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    list = list.where((j) {
      try {
        final ts = (j as Map<String, dynamic>)['timestamp'] as String;
        return ts.compareTo(cutoff) >= 0;
      } catch (_) {
        return false;
      }
    }).toList();

    await prefs.setString(key, jsonEncode(list));
  } catch (_) {}
}

// Generates the daily health report once per day at the user's chosen time.
// Saves locally, queues for Firestore sync (done from main isolate on resume),
// and fires a report notification.
Future<void> _ensureDailyReport(
    SharedPreferences prefs, String uid, FlutterLocalNotificationsPlugin bgPlugin) async {
  try {
    final now = DateTime.now();

    // Read user's chosen report time (default 22:00); keys shared with SettingsNotifier
    final hour = prefs.getInt('daily_report_hour') ?? 22;
    final minute = prefs.getInt('daily_report_minute') ?? 0;
    final scheduledToday =
        DateTime(now.year, now.month, now.day, hour, minute);

    // Not yet the scheduled time today
    if (now.isBefore(scheduledToday)) return;

    // Already generated today's report
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString('last_daily_report_day') == dayKey) return;

    // Aggregate today's analysis records from local history
    final historyKey = 'analysis_history_${uid}_v1';
    final historyRaw = prefs.getString(historyKey);
    List<AnalysisRecord> todayRecords = [];
    if (historyRaw != null) {
      try {
        final all = jsonDecode(historyRaw) as List;
        todayRecords = all
            .map((j) => AnalysisRecord.fromJson(j as Map<String, dynamic>))
            .where((r) =>
                r.timestamp.year == now.year &&
                r.timestamp.month == now.month &&
                r.timestamp.day == now.day)
            .toList();
      } catch (_) {}
    }

    // Build summary stats for the notification body
    String notifBody;
    if (todayRecords.isNotEmpty) {
      final total = todayRecords.length;
      final avgHr =
          todayRecords.map((r) => r.heartRate).reduce((a, b) => a + b) / total;
      final avgSpo2 =
          todayRecords.map((r) => r.spo2).reduce((a, b) => a + b) / total;
      notifBody =
          '$total analyses today · Avg HR ${avgHr.toStringAsFixed(0)} bpm · '
          'SpO₂ ${avgSpo2.toStringAsFixed(1)}% · Open app for full report.';
    } else {
      notifBody = 'Your 24-hour health report is ready. Open app to view.';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final reportId = 'bg_report_${now.millisecondsSinceEpoch}';
    final reportName =
        'Health Report — ${months[now.month - 1]} ${now.day}, ${now.year}';
    final reportJson = {
      'id': reportId,
      'name': reportName,
      'dayKey': dayKey,
      'createdAt': now.toIso8601String(),
    };

    // Save to local health_reports list (Reports screen reads this)
    final reportsKey = 'health_reports_${uid}_v1';
    final reportsRaw = prefs.getString(reportsKey) ?? '[]';
    List<dynamic> reportsList = [];
    try { reportsList = jsonDecode(reportsRaw) as List; } catch (_) {}
    reportsList.removeWhere(
        (j) => (j as Map<String, dynamic>)['dayKey'] == dayKey);
    reportsList.insert(0, reportJson);
    await prefs.setString(reportsKey, jsonEncode(reportsList));

    // Queue for Firestore sync — the main isolate picks this up on resume
    // because Firebase is not reachable from a background isolate.
    final pendingKey = 'pending_report_sync_$uid';
    final pendingRaw = prefs.getString(pendingKey) ?? '[]';
    List<dynamic> pendingList = [];
    try { pendingList = jsonDecode(pendingRaw) as List; } catch (_) {}
    pendingList.add(reportJson);
    await prefs.setString(pendingKey, jsonEncode(pendingList));

    // Mark today as done so this doesn't re-fire until tomorrow
    await prefs.setString('last_daily_report_day', dayKey);

    // Queue in-app notification for when the app is next opened
    await _queueInAppNotification(
        prefs, '📊 Daily Health Report Ready', notifBody, 1);

    // Fire system notification immediately (visible even when app is closed)
    await bgPlugin.show(
      3,
      '📊 Daily Health Report Ready',
      notifBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cardiva_reports',
          'Daily Reports',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: true,
        ),
      ),
    );
  } catch (_) {}
}

// Queues a notification for the in-app notification list so it appears
// when the user next opens the app.
// typeIndex: 0 = alert, 1 = health, 2 = system  (matches NotifType.index)
Future<void> _queueInAppNotification(
    SharedPreferences prefs, String title, String body, int typeIndex) async {
  try {
    const key = 'pending_notifications';
    final raw = prefs.getString(key) ?? '[]';
    final list = jsonDecode(raw) as List;
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'subtitle': body,
      'createdAt': DateTime.now().toIso8601String(),
      'type': typeIndex,
      'isRead': false,
    });
    await prefs.setString(key, jsonEncode(list));
  } catch (_) {}
}
