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

    // Create the persistent notification channel
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
        autoStart: true,
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

  // Called from main isolate so background isolate can read user profile
  static Future<void> writeUserProfile({
    required double heightM,
    required double weightKg,
    required int age,
    required String gender,
  }) async {
    final prefs = await SharedPreferences.getInstance();
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

  // Run background analysis every 30 minutes — frequent enough to catch issues,
  // gentle enough not to drain the battery overnight.
  Timer.periodic(const Duration(minutes: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        timer.cancel();
        return;
      }
    }
    await _backgroundAnalyze(service);
  });
}

Future<void> _backgroundAnalyze(ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Read user profile from SharedPreferences (written by main isolate on login)
    final height = prefs.getDouble('bg_user_height') ?? 1.70;
    final weight = prefs.getDouble('bg_user_weight') ?? 70.0;
    final age = prefs.getInt('bg_user_age') ?? 35;
    final gender = prefs.getString('bg_user_gender') ?? 'male';

    // Generate simulated vitals (same as MockDataService)
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

    // Save result to SharedPreferences so main isolate can sync on resume
    final record = AnalysisRecord(
      id: 'bg_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      prediction: prediction,
      heartRate: hr,
      spo2: spo2,
      hrv: hrv,
      respirationRate: rr,
    );

    final pending = prefs.getStringList('bg_pending_records') ?? [];
    pending.add(jsonEncode(record.toJson()));
    // Keep at most 50 pending records to avoid storage overflow
    if (pending.length > 50) pending.removeRange(0, pending.length - 50);
    await prefs.setStringList('bg_pending_records', pending);

    // Update foreground notification — use URGENT prefix for emergencies
    if (service is AndroidServiceInstance) {
      final isAlert = prediction.alertClass != AlertClass.normal;
      final title = isAlert
          ? '🚨 CARDIVA ${prediction.alertClass.label}'
          : 'Cardiva Health Monitor';
      final content = isAlert
          ? 'HR ${hr.toStringAsFixed(0)} bpm · SpO₂ ${spo2.toStringAsFixed(0)}% — Open app to send alert'
          : 'HR ${hr.toStringAsFixed(0)} bpm · SpO₂ ${spo2.toStringAsFixed(0)}% — All normal';
      service.setForegroundNotificationInfo(title: title, content: content);

      // Flag that an emergency was detected so main isolate can handle it on resume
      if (isAlert) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bg_emergency_pending', true);
        await prefs.setString(
            'bg_emergency_type', prediction.alertClass.name);
      }
    }
  } catch (_) {
    // Silently fail — background analysis is best-effort
  }
}

