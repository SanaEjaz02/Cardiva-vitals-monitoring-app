import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_class.dart';
import '../models/analysis_record.dart';
import '../models/health_report.dart';
import '../providers/settings_provider.dart' show kReportHourKey, kReportMinuteKey, kLastReportDayKey;
import '../models/ml_prediction.dart';
import '../services/firestore_service.dart';
import '../services/ml_service.dart';
import '../services/notification_service.dart';
import 'user_provider.dart';
import 'vital_provider.dart';

// ── Interval setting (minutes) ─────────────────────────────────────────────
final analysisIntervalMinProvider = StateProvider<int>((ref) => 120);

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
  return _buildSummary(records);
});

DailySummary _buildSummary(List<AnalysisRecord> records) {
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

  final score =
      (normal / total * 95 - warn * 2.0 - emerg * 10.0).clamp(0.0, 100.0).round();

  String summaryText;
  if (emerg > 0) {
    summaryText =
        '$emerg emergency alert${emerg > 1 ? 's' : ''} recorded. '
        'Seek immediate medical attention. '
        'Avg HR ${avgHr.toStringAsFixed(0)} bpm, SpO₂ ${avgSpo2.toStringAsFixed(1)}%.';
  } else if (warn > 0) {
    summaryText =
        '$warn health warning${warn > 1 ? 's' : ''} detected. '
        'Monitor closely. Avg HR ${avgHr.toStringAsFixed(0)} bpm, '
        'SpO₂ ${avgSpo2.toStringAsFixed(1)}%.';
  } else {
    summaryText =
        'All $total analyses within normal range. '
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
}

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
  Timer? _reportTimer;
  bool _analyzing = false;
  String? _loadedForUid;

  DateTime? nextAnalysisAt;
  bool get isAnalyzing => _analyzing;

  AnalysisHistoryNotifier(this._ref) : super([]) {
    _init();
  }

  /// Call this when a new user logs in to ensure stale data from the previous
  /// session is discarded and fresh data is loaded for the current user.
  Future<void> ensureLoadedForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == _loadedForUid) return;
    _loadedForUid = uid;
    _timer?.cancel();
    _reportTimer?.cancel();
    state = [];
    await _init();
  }

  Future<void> _init() async {
    _loadedForUid = FirebaseAuth.instance.currentUser?.uid;
    await _loadHistory();
    await _syncBackgroundRecords();
    _schedule();
    _startReportWatcher();
  }

  // Imports records written by the background service isolate
  Future<void> syncFromBackground() async {
    await _syncBackgroundRecords();
  }

  Future<void> _syncBackgroundRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('bg_pending_records') ?? [];
      if (pending.isEmpty) return;
      await prefs.remove('bg_pending_records');

      final existing = state.map((r) => r.id).toSet();
      final toAdd = pending
          .map((s) => AnalysisRecord.fromJson(
              jsonDecode(s) as Map<String, dynamic>))
          .where((r) => !existing.contains(r.id))
          .toList();
      if (toAdd.isEmpty) return;

      state = [...state, ...toAdd]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await _saveHistory();
    } catch (_) {}
  }

  // ── SharedPreferences key scoped to current user ────────────────────────
  static String _storageKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'analysis_history_${uid}_v1';
  }

  Future<void> _loadHistory() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    // Load local cache first for instant startup
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey());
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        state = list
            .map((j) => AnalysisRecord.fromJson(j as Map<String, dynamic>))
            .where((r) => r.timestamp.isAfter(cutoff))
            .toList();
      }
    } catch (_) {}
    // Always merge from Firestore — picks up records from other devices
    try {
      final remote = await FirestoreService.loadAnalysisRecords();
      if (remote.isNotEmpty) {
        final merged = <String, AnalysisRecord>{
          for (final r in state) r.id: r,
        };
        for (final r in remote) {
          if (r.timestamp.isAfter(cutoff)) merged[r.id] = r;
        }
        state = merged.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey(),
          jsonEncode(state.map((r) => r.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey(), json);
      // Sync to Firestore in the background
      FirestoreService.syncAnalysisRecords(state).catchError((_) {});
    } catch (_) {}
  }

  int get _interval => _ref.read(analysisIntervalMinProvider);

  void setInterval(int minutes) {
    _ref.read(analysisIntervalMinProvider.notifier).state = minutes;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final dur = Duration(minutes: _interval);
    nextAnalysisAt = DateTime.now().add(dur);
    _timer = Timer(dur, () async {
      await _autoAnalyze();
      if (mounted) _schedule();
    });
  }

  // Checks every minute whether the daily report time has arrived,
  // independent of the auto-analysis interval.
  void _startReportWatcher() {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _checkAndSaveDailyReport();
    });
  }

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

      await _checkAndSaveDailyReport();
    } finally {
      _analyzing = false;
    }
  }

  // Generates a daily report when 24 hours have elapsed since the last one.
  // Saves locally, syncs to Firestore, and fires a notification.
  Future<void> _checkAndSaveDailyReport() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Read the user's chosen report time (default 22:00)
      final hour = prefs.getInt(kReportHourKey) ?? 22;
      final minute = prefs.getInt(kReportMinuteKey) ?? 0;
      final scheduledToday =
          DateTime(now.year, now.month, now.day, hour, minute);

      // Not yet time today
      if (now.isBefore(scheduledToday)) return;

      // Already generated today's report
      final dayKey = HealthReport.todayKey();
      if (prefs.getString(kLastReportDayKey) == dayKey) return;

      // Aggregate today's records already in state
      final todayRecords = state
          .where((r) =>
              r.timestamp.year == now.year &&
              r.timestamp.month == now.month &&
              r.timestamp.day == now.day)
          .toList();

      final report = HealthReport(
        id: 'report_${now.millisecondsSinceEpoch}',
        name: HealthReport.defaultName(now),
        dayKey: dayKey,
        createdAt: now,
      );

      // Persist to local reports list
      final reportsKey = 'health_reports_${uid}_v1';
      final raw = prefs.getString(reportsKey) ?? '[]';
      final list = jsonDecode(raw) as List;
      list.removeWhere(
          (j) => (j as Map<String, dynamic>)['dayKey'] == dayKey);
      list.insert(0, report.toJson());
      await prefs.setString(reportsKey, jsonEncode(list));

      // Sync to Firestore (we're in the main isolate so Firebase is available)
      FirestoreService.syncHealthReports([report]).catchError((_) {});

      // Notify user
      final summary = todayRecords.isEmpty
          ? null
          : buildSummaryFromRecords(todayRecords);
      final body = summary != null
          ? summary.summaryText
          : 'Your daily health report has been generated. Open the app to view it.';
      NotificationService.showReportNotification(
        '📊 Daily Health Report Ready',
        body,
      ).catchError((_) {});

      // Mark today as done so this doesn't re-fire until tomorrow
      await prefs.setString(kLastReportDayKey, dayKey);
    } catch (_) {}
  }

  // Syncs any reports the background isolate queued for Firestore.
  // Called from app.dart when the app comes to the foreground.
  Future<void> syncPendingReports() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'pending_report_sync_$uid';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      if (list.isEmpty) return;
      final reports = list
          .map((j) => HealthReport.fromJson(j as Map<String, dynamic>))
          .toList();
      await FirestoreService.syncHealthReports(reports);
      await prefs.remove(key);
    } catch (_) {}
  }

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

  // Delete a single record by ID
  Future<void> deleteRecord(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _saveHistory();
  }

  // Delete all records for a given calendar day
  Future<void> deleteDayRecords(DateTime day) async {
    state = state
        .where((r) =>
            r.timestamp.year != day.year ||
            r.timestamp.month != day.month ||
            r.timestamp.day != day.day)
        .toList();
    await _saveHistory();
  }

  // Restore a list of records (undo delete)
  Future<void> restoreRecords(List<AnalysisRecord> records) async {
    final ids = state.map((r) => r.id).toSet();
    final toAdd = records.where((r) => !ids.contains(r.id)).toList();
    if (toAdd.isEmpty) return;
    state = [...state, ...toAdd]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _saveHistory();
  }

  void _append(AnalysisRecord record) {
    state = [...state, record];
    _saveHistory();
  }

  @override
  @override
  void dispose() {
    _timer?.cancel();
    _reportTimer?.cancel();
    super.dispose();
  }
}

// ── Helper to build summary from an arbitrary list ─────────────────────────
DailySummary buildSummaryFromRecords(List<AnalysisRecord> records) =>
    _buildSummary(records);
