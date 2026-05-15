import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_record.dart';
import '../models/health_report.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
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
    _ref.listen<List<AnalysisRecord>>(analysisHistoryProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        ensureTodayReport();
      }
    });
  }

  Future<void> _load() async {
    // Load local cache first for instant startup
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
    // Always merge from Firestore — picks up reports from other devices
    try {
      final remote = await FirestoreService.loadHealthReports();
      if (remote.isNotEmpty) {
        final merged = <String, HealthReport>{
          for (final r in state) r.id: r,
        };
        for (final r in remote) {
          merged[r.id] = r; // Firestore wins (has pdfUrl + latest rename)
        }
        state = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _key(), jsonEncode(state.map((r) => r.toJson()).toList()));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key(), jsonEncode(state.map((r) => r.toJson()).toList()));
      FirestoreService.syncHealthReports(state).catchError((_) {});
    } catch (_) {}
  }

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

  /// Stores the Firebase Storage download URL on the report.
  Future<void> updatePdfUrl(String reportId, String url) async {
    state = state
        .map((r) => r.id == reportId ? r.copyWith(pdfUrl: url) : r)
        .toList();
    await _save();
    FirestoreService.updateReportPdfUrl(reportId, url).catchError((_) {});
  }

  Future<List<AnalysisRecord>> delete(String id) async {
    final report = state.firstWhere((r) => r.id == id);
    state = state.where((r) => r.id != id).toList();
    await _save();
    // Delete Firestore document and Storage PDF
    FirestoreService.deleteReport(id).catchError((_) {});
    if (report.pdfUrl != null) {
      StorageService.deleteReportPdf(id).catchError((_) {});
    }

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

  Future<void> restore(
      HealthReport report, List<AnalysisRecord> records) async {
    if (!state.any((r) => r.id == report.id)) {
      state = [report, ...state]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _save();
    }
    await _ref.read(analysisHistoryProvider.notifier).restoreRecords(records);
  }

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
