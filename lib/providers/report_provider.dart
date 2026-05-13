import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_record.dart';
import '../models/health_report.dart';
import 'analysis_provider.dart';

final reportProvider =
    StateNotifierProvider<ReportNotifier, List<HealthReport>>(
  (ref) => ReportNotifier(ref),
);

class ReportNotifier extends StateNotifier<List<HealthReport>> {
  final Ref _ref;

  ReportNotifier(this._ref) : super([]) {
    _init();
  }

  static String _key() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'health_reports_${uid}_v1';
  }

  Future<void> _init() async {
    await _load();
    // Auto-create a report for the current day when new analysis records appear
    _ref.listen<List<AnalysisRecord>>(analysisHistoryProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        ensureTodayReport();
      }
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key());
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        state = list
            .map((j) => HealthReport.fromJson(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key(), jsonEncode(state.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  // Creates a report entry for today if one doesn't exist yet
  Future<void> ensureTodayReport() async {
    final dayKey = HealthReport.todayKey();
    if (state.any((r) => r.dayKey == dayKey)) return;
    final now = DateTime.now();
    final report = HealthReport(
      id: now.millisecondsSinceEpoch.toString(),
      name: HealthReport.defaultName(now),
      dayKey: dayKey,
      createdAt: now,
    );
    state = [report, ...state];
    await _save();
  }

  Future<void> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    state = state
        .map((r) => r.id == id ? r.copyWith(name: trimmed) : r)
        .toList();
    await _save();
  }

  // Delete report AND its associated analysis records
  Future<List<AnalysisRecord>> delete(String id) async {
    final report = state.firstWhere((r) => r.id == id);
    state = state.where((r) => r.id != id).toList();
    await _save();

    // Get records for this day before deleting
    final all = _ref.read(analysisHistoryProvider);
    final parts = report.dayKey.split('-');
    final day = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final deleted = all
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month &&
            r.timestamp.day == day.day)
        .toList();

    await _ref.read(analysisHistoryProvider.notifier).deleteDayRecords(day);
    return deleted;
  }

  // Restore a deleted report + its records (undo)
  Future<void> restore(
      HealthReport report, List<AnalysisRecord> records) async {
    if (!state.any((r) => r.id == report.id)) {
      state = [report, ...state]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _save();
    }
    await _ref.read(analysisHistoryProvider.notifier).restoreRecords(records);
  }

  // Returns analysis records for a given report
  List<AnalysisRecord> recordsFor(HealthReport report) {
    final all = _ref.read(analysisHistoryProvider);
    final parts = report.dayKey.split('-');
    final day = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return all
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month &&
            r.timestamp.day == day.day)
        .toList();
  }
}
