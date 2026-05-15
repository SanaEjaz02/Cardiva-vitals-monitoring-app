import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/analysis_record.dart';
import '../models/health_report.dart';

class FirestoreService {
  FirestoreService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // User profile

  static Future<void> saveProfile(Map<String, dynamic> profileJson) async {
    try {
      final uid = _uid;
      debugPrint('[Firestore] saveProfile — uid=$uid');
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('[Firestore] saveProfile — skipped: no authenticated user');
        return;
      }
      await doc.set({'profile': profileJson}, SetOptions(merge: true));
      debugPrint('[Firestore] saveProfile — success');
    } catch (e) {
      debugPrint('[Firestore] saveProfile — ERROR: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    return data?['profile'] as Map<String, dynamic>?;
  }

  // Emergency contacts

  static Future<void> saveEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    try {
      final uid = _uid;
      debugPrint('[Firestore] saveEmergencyContacts — uid=$uid count=${contacts.length}');
      final doc = _userDoc;
      if (doc == null) {
        debugPrint('[Firestore] saveEmergencyContacts — skipped: no authenticated user');
        return;
      }
      await doc.set({'emergency_contacts': contacts}, SetOptions(merge: true));
      debugPrint('[Firestore] saveEmergencyContacts — success');
    } catch (e) {
      debugPrint('[Firestore] saveEmergencyContacts — ERROR: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> loadEmergencyContacts() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['emergency_contacts'];
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(raw as List);
  }

  // Attendants

  static Future<void> saveAttendants(
      List<Map<String, dynamic>> attendants) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({'attendants': attendants}, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>?> loadAttendants() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['attendants'];
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(raw as List);
  }

  // Chat sessions

  static Future<void> saveChatSessions(
      List<Map<String, dynamic>> sessions) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({'chat_sessions': sessions}, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>?> loadChatSessions() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['chat_sessions'];
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(raw as List);
  }

  // Analysis history

  static Future<List<AnalysisRecord>> loadAnalysisRecords() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('analysis_history')
        .orderBy('timestamp')
        .get();
    return snap.docs
        .map((d) => AnalysisRecord.fromJson(d.data()))
        .toList();
  }

  static Future<void> syncAnalysisRecords(List<AnalysisRecord> records) async {
    final uid = _uid;
    if (uid == null) return;
    final col =
        _db.collection('users').doc(uid).collection('analysis_history');
    final batch = _db.batch();
    for (final r in records) {
      batch.set(col.doc(r.id), r.toJson());
    }
    await batch.commit();
  }

  // Health reports

  static Future<void> syncHealthReports(List<HealthReport> reports) async {
    final uid = _uid;
    if (uid == null) return;
    final col = _db.collection('users').doc(uid).collection('health_reports');
    final batch = _db.batch();
    for (final r in reports) {
      batch.set(col.doc(r.id), r.toJson());
    }
    await batch.commit();
  }

  static Future<List<HealthReport>> loadHealthReports() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('health_reports')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => HealthReport.fromJson(d.data())).toList();
  }

  static Future<void> updateReportPdfUrl(
      String reportId, String url) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('health_reports')
        .doc(reportId)
        .update({'pdfUrl': url});
  }

  static Future<void> deleteReport(String reportId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('health_reports')
        .doc(reportId)
        .delete();
  }
}
