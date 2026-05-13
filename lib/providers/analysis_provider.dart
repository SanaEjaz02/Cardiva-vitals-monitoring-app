import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_class.dart';
import '../models/analysis_record.dart';
import '../models/ml_prediction.dart';
import '../services/ml_service.dart';
import '../services/notification_service.dart';
import 'user_provider.dart';
import 'vital_provider.dart';

// ── Interval setting (minutes) ─────────────────────────────────────────────
final analysisIntervalMinProvider = StateProvider<int>((ref) => 5);

// ── History ────────────────────────────────────────────────────────────────
final analysisHistoryProvider =
    StateNotifierProvider<AnalysisHistoryNotifier, List<AnalysisRecord>>(
  (ref) => AnalysisHistoryNotifier(ref),
);

// ── Today's records ────────────────────────────────────────────────────────
final todayAnalysisProvider = Provider<List<AnalysisRecord>>((ref) {
  final all = ref.watch(analysisHistoryProvider);
  final now = DateTime.now();
  return all
      .where((r) =>
          r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day)
      .toList();
});

// ── Most recent record ────────────────────────────────────────────────────
final lastAnalysisProvider = Provider<AnalysisRecord?>((ref) {
  final today = ref.watch(todayAnalysisProvider);
  return today.isEmpty ? null : today.last;
});

// ── End-of-day / on-demand daily summary ──────────────────────────────────
final dailySummaryProvider = Provider<DailySummary?>((ref) {
  final records = ref.watch(todayAnalysisProvider);
  if (records.isEmpty) return null;

  final total = records.length;
  final normal = records
      .where((r) => r.prediction.alertClass == AlertClass.normal)
      .length;
  final warn = records
      .where((r) =>
          r.prediction.alertClass == AlertClass.vitalsAlert ||
          r.prediction.alertClass == AlertClass.fallAlert)
      .length;
  final emerg = records
      .where((r) => r.prediction.alertClass == AlertClass.emergency)
      .length;

  final avgHr =
      records.map((r) => r.heartRate).reduce((a, b) => a + b) / total;
  final avgSpo2 = records.map((r) => r.spo2).reduce((a, b) => a + b) / total;
  final avgHrv = records.map((r) => r.hrv).reduce((a, b) => a + b) / total;
  final avgRr =
      records.map((r) => r.respirationRate).reduce((a, b) => a + b) / total;

  // Health score: proportion of normal analyses minus penalty per alert
  final score =
      (normal / total * 95 - warn * 2.0 - emerg * 10.0).clamp(0.0, 100.0).round();

  String summaryText;
  if (emerg > 0) {
    summaryText =
        '$emerg emergency alert${emerg > 1 ? 's' : ''} recorded today. '
        'Seek immediate medical attention. '
        'Avg HR ${avgHr.toStringAsFixed(0)} bpm, SpO₂ ${avgSpo2.toStringAsFixed(1)}%.';
  } else if (warn > 0) {
    summaryText =
        '$warn health warning${warn > 1 ? 's' : ''} detected today. '
        'Monitor closely. Avg HR ${avgHr.toStringAsFixed(0)} bpm, '
        'SpO₂ ${avgSpo2.toStringAsFixed(1)}%.';
  } else {
    summaryText =
        'All $total analyses within normal range today. '
        'Cardiovascular status stable. '
        'Avg HR ${avgHr.toStringAsFixed(0)} bpm, SpO₂ ${avgSpo2.toStringAsFixed(1)}%.';
  }

  return DailySummary(
    totalAnalyses: total,
    normalCount: normal,
    warningCount: warn,
    emergencyCount: emerg,
    avgHr: avgHr,
    avgSpo2: avgSpo2,
    avgHrv: avgHrv,
    avgRr: avgRr,
    healthScore: score,
    summaryText: summaryText,
  );
});

// ── DailySummary data class ────────────────────────────────────────────────
class DailySummary {
  final int totalAnalyses;
  final int normalCount;
  final int warningCount;
  final int emergencyCount;
  final double avgHr;
  final double avgSpo2;
  final double avgHrv;
  final double avgRr;
  final int healthScore;
  final String summaryText;

  const DailySummary({
    required this.totalAnalyses,
    required this.normalCount,
    required this.warningCount,
    required this.emergencyCount,
    required this.avgHr,
    required this.avgSpo2,
    required this.avgHrv,
    required this.avgRr,
    required this.healthScore,
    required this.summaryText,
  });
}

// ── Notifier ───────────────────────────────────────────────────────────────
class AnalysisHistoryNotifier extends StateNotifier<List<AnalysisRecord>> {
  final Ref _ref;
  Timer? _timer;
  bool _analyzing = false;

  // Exposed for UI countdown display
  DateTime? nextAnalysisAt;
  bool get isAnalyzing => _analyzing;

  AnalysisHistoryNotifier(this._ref) : super([]) {
    _schedule();
  }

  int get _interval => _ref.read(analysisIntervalMinProvider);

  // Called when the user changes the interval in the UI
  void setInterval(int minutes) {
    _ref.read(analysisIntervalMinProvider.notifier).state = minutes;
    _schedule();
  }

  // Reset countdown and arm next analysis
  void _schedule() {
    _timer?.cancel();
    final dur = Duration(minutes: _interval);
    nextAnalysisAt = DateTime.now().add(dur);
    _timer = Timer(dur, () async {
      await _autoAnalyze();
      if (mounted) _schedule();
    });
  }

  // Runs silently in the background; fires notification on non-normal results
  Future<void> _autoAnalyze() async {
    if (_analyzing) return;
    _analyzing = true;
    try {
      final reading = _ref.read(latestReadingProvider).valueOrNull;
      if (reading == null) return;
      final user = _ref.read(userProvider);

      final prediction = await MlService.analyze(
        heartRate: reading.heartRate,
        spo2: reading.spO2,
        hrv: reading.hrv,
        respirationRate: reading.respirationRate,
        activity: reading.activity.name,
        accelX: 0.0,
        accelY: 9.8,
        accelZ: 0.0,
        height: user?.heightM ?? 1.70,
        weight: user?.weightKg ?? 70.0,
        age: user?.age ?? 35,
        gender: (user?.gender ?? 'male').toLowerCase(),
      );

      _append(AnalysisRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        prediction: prediction,
        heartRate: reading.heartRate,
        spo2: reading.spO2,
        hrv: reading.hrv,
        respirationRate: reading.respirationRate,
      ));

      if (prediction.alertClass == AlertClass.emergency) {
        await NotificationService.showEmergencyNotification(
          'CARDIVA Emergency',
          'HR: ${reading.heartRate.toStringAsFixed(0)} bpm  ·  SpO₂: ${reading.spO2.toStringAsFixed(0)}%',
        ).catchError((_) {});
      } else if (prediction.alertClass != AlertClass.normal) {
        await NotificationService.showWarningNotification(
          '⚠️ ${prediction.alertClass.label}',
          prediction.analysisMessage,
        ).catchError((_) {});
      }
    } finally {
      _analyzing = false;
    }
  }

  // Manual "Analyze Now" — also stores in history, returns prediction for navigation
  Future<MlPrediction> analyzeNow({
    required double heartRate,
    required double spo2,
    required double hrv,
    required double respirationRate,
    required String activity,
    double accelX = 0.0,
    double accelY = 9.8,
    double accelZ = 0.0,
  }) async {
    final user = _ref.read(userProvider);

    final prediction = await MlService.analyze(
      heartRate: heartRate,
      spo2: spo2,
      hrv: hrv,
      respirationRate: respirationRate,
      activity: activity,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      height: user?.heightM ?? 1.70,
      weight: user?.weightKg ?? 70.0,
      age: user?.age ?? 35,
      gender: (user?.gender ?? 'male').toLowerCase(),
    );

    _append(AnalysisRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      prediction: prediction,
      heartRate: heartRate,
      spo2: spo2,
      hrv: hrv,
      respirationRate: respirationRate,
    ));

    return prediction;
  }

  void _append(AnalysisRecord record) {
    state = [...state, record];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
