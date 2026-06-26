import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/analysis_record.dart';
import '../models/health_report.dart';
import 'link_service.dart';

/// Firestore layout — TWO collections only, no users/ collection.
///
///  patients/{uid}/
///    role            : 'patient'
///    profile         : {name, email, phone, dob, gender,
///                       bloodGroup, heightCm, weightKg}
///    vitals          : {hr, spo2, hrv, rr, fall, timestamp}  ← BLE layer
///    manual_guardians: [{id, name, phone, email, relationship}]
///    linked_guardians: [guardianUid, ...]                    ← QR-link
///    analysis_history/   (subcollection)
///    health_reports/     (subcollection)
///    ai_chat_sessions    (field — session array for Groq chatbot)
///
///  guardians/{uid}/
///    role           : 'attendant'
///    profile        : {name, email, phone}
///    linked_patients: [patientUid, ...]                      ← QR-link
///
///  chats/{patientUid}_{guardianUid}/
///    patientId, guardianId, participants[], lastMessage, lastMessageTime
///    messages/ (subcollection)
///      {msgId}/ { senderId, receiverId, text, timestamp, isRead, type }
class FirestoreService {
  FirestoreService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Role routing ──────────────────────────────────────────────────────────

  static String _cachedRole = 'patient';

  static String _collectionFor(String role) =>
      role == 'attendant' ? 'guardians' : 'patients';

  /// Primary document in the role-appropriate collection.
  static DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection(_collectionFor(_cachedRole)).doc(uid);
  }

  // ── Role ─────────────────────────────────────────────────────────────────

  /// Writes role into patients/ or guardians/ depending on role value.
  static Future<void> saveRole(String role) async {
    _cachedRole = role;
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection(_collectionFor(role))
          .doc(uid)
          .set({'role': role}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] saveRole ERROR: $e');
    }
  }

  /// Determines which collection this user belongs to.
  /// Reads patients/ and guardians/ in parallel — halves latency for guardians.
  static Future<String?> loadRole() async {
    final uid = _uid;
    if (uid == null) return null;

    Future<bool> exists(String col) async {
      try {
        return (await _db.collection(col).doc(uid).get()).exists;
      } catch (_) {
        return false;
      }
    }

    final results =
        await Future.wait([exists('patients'), exists('guardians')]);
    if (results[0]) { _cachedRole = 'patient'; return 'patient'; }
    if (results[1]) { _cachedRole = 'attendant'; return 'attendant'; }
    return null;
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Saves profile map as patients/{uid}.profile  or  guardians/{uid}.profile.
  static Future<void> saveProfile(Map<String, dynamic> profileJson) async {
    final uid = _uid;
    if (uid == null) return;
    final roleStr = profileJson['role'] as String?;
    if (roleStr != null) _cachedRole = roleStr;
    try {
      debugPrint('[Firestore] saveProfile → ${_collectionFor(_cachedRole)}/$uid');
      await _db
          .collection(_collectionFor(_cachedRole))
          .doc(uid)
          .set({'profile': profileJson, 'role': _cachedRole},
              SetOptions(merge: true));
      debugPrint('[Firestore] saveProfile — ok');
    } catch (e) {
      debugPrint('[Firestore] saveProfile ERROR: $e');
      rethrow;
    }
    // Guardian just set up profile — auto-link to any patients who added them by email
    if (_cachedRole == 'attendant') {
      final email = profileJson['email'] as String? ?? '';
      if (email.isNotEmpty) {
        LinkService.autoLinkGuardianToPatients(
          guardianUid: uid,
          guardianEmail: email,
        ).catchError((_) {});
      }
    }
  }

  /// Loads profile from patients/{uid}.profile or guardians/{uid}.profile.
  static Future<Map<String, dynamic>?> loadProfile() async {
    try {
      final snap = await _userDoc?.get();
      if (snap != null && snap.exists) {
        return (snap.data() as Map<String, dynamic>?)?['profile']
            as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[Firestore] loadProfile ERROR: $e');
    }
    return null;
  }

  // ── Manual guardians ──────────────────────────────────────────────────────

  /// Saves manually-added guardian list to patients/{uid}.manual_guardians.
  /// Also writes a flat guardian_emails array used for reverse-lookup auto-linking.
  static Future<void> saveManualGuardians(
      List<Map<String, dynamic>> guardians) async {
    final doc = _userDoc;
    if (doc == null) return;
    final emails = guardians
        .map((g) => (g['email'] as String? ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      await doc.set({
        'manual_guardians': guardians,
        'guardian_emails': emails,
      }, SetOptions(merge: true));
      debugPrint('[Firestore] saveManualGuardians — ok (${guardians.length})');
    } catch (e) {
      debugPrint('[Firestore] saveManualGuardians ERROR: $e');
      rethrow;
    }
  }

  /// Loads manually-added guardian list from patients/{uid}.manual_guardians.
  /// Also checks emergency_contacts key for data saved by older app versions.
  static Future<List<Map<String, dynamic>>?> loadManualGuardians() async {
    try {
      final snap = await _userDoc?.get();
      if (snap != null && snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        final mg = data?['manual_guardians'];
        if (mg != null) return List<Map<String, dynamic>>.from(mg as List);
        final ec = data?['emergency_contacts'];
        if (ec != null) return List<Map<String, dynamic>>.from(ec as List);
      }
    } catch (e) {
      debugPrint('[Firestore] loadManualGuardians ERROR: $e');
    }
    return null;
  }

  /// Alias used by attendant/guardian management screen.
  static Future<void> saveAttendants(
      List<Map<String, dynamic>> attendants) async {
    await saveManualGuardians(attendants);
  }

  static Future<List<Map<String, dynamic>>?> loadAttendants() async {
    return loadManualGuardians();
  }

  // ── Emergency contacts (alias for manual guardians) ───────────────────────

  static Future<void> saveEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      await doc.set({'emergency_contacts': contacts}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] saveEmergencyContacts ERROR: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> loadEmergencyContacts() async {
    return loadManualGuardians();
  }

  // ── AI chat sessions (Groq chatbot) ──────────────────────────────────────

  static Future<void> saveChatSessions(
      List<Map<String, dynamic>> sessions) async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      await doc.set({'ai_chat_sessions': sessions}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] saveChatSessions ERROR: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> loadChatSessions() async {
    try {
      final snap = await _userDoc?.get();
      if (snap == null || !snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>?;
      // Also check legacy key from older app versions
      final ai = data?['ai_chat_sessions'] ?? data?['chat_sessions'];
      if (ai == null) return null;
      return List<Map<String, dynamic>>.from(ai as List);
    } catch (e) {
      debugPrint('[Firestore] loadChatSessions ERROR: $e');
      return null;
    }
  }

  // ── Analysis history ──────────────────────────────────────────────────────

  static Future<List<AnalysisRecord>> loadAnalysisRecords() async {
    try {
      final doc = _userDoc;
      if (doc == null) return [];
      final snap =
          await doc.collection('analysis_history').orderBy('timestamp').get();
      return snap.docs.map((d) => AnalysisRecord.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] loadAnalysisRecords ERROR: $e');
      return [];
    }
  }

  static Future<void> syncAnalysisRecords(List<AnalysisRecord> records) async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      final col = doc.collection('analysis_history');
      final batch = _db.batch();
      for (final r in records) {
        batch.set(col.doc(r.id), r.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] syncAnalysisRecords ERROR: $e');
    }
  }

  // ── Health reports ────────────────────────────────────────────────────────

  static Future<void> syncHealthReports(List<HealthReport> reports) async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      final col = doc.collection('health_reports');
      final batch = _db.batch();
      for (final r in reports) {
        batch.set(col.doc(r.id), r.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] syncHealthReports ERROR: $e');
    }
  }

  static Future<List<HealthReport>> loadHealthReports() async {
    try {
      final doc = _userDoc;
      if (doc == null) return [];
      final snap = await doc
          .collection('health_reports')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => HealthReport.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] loadHealthReports ERROR: $e');
      return [];
    }
  }

  static Future<void> updateReportPdfUrl(String reportId, String url) async {
    try {
      await _userDoc
          ?.collection('health_reports')
          .doc(reportId)
          .update({'pdfUrl': url});
    } catch (e) {
      debugPrint('[Firestore] updateReportPdfUrl ERROR: $e');
    }
  }

  static Future<void> deleteReport(String reportId) async {
    try {
      await _userDoc?.collection('health_reports').doc(reportId).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteReport ERROR: $e');
    }
  }

  // ── Account deletion ──────────────────────────────────────────────────────

  static Future<void> deleteAccount() async {
    final uid = _uid;
    if (uid == null) return;
    final userRef = _userDoc;
    if (userRef == null) return;
    try {
      final batch = _db.batch();
      for (final col in ['analysis_history', 'health_reports']) {
        final snaps = await userRef.collection(col).get();
        for (final d in snaps.docs) {
          batch.delete(d.reference);
        }
      }
      batch.delete(userRef);
      await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] deleteAccount ERROR: $e');
    }
  }

  // ── Feedback ──────────────────────────────────────────────────────────────

  static Future<void> saveFeedback({
    required String userId,
    required String userEmail,
    required String userName,
    required int rating,
    required String category,
    required String message,
  }) async {
    try {
      await _db.collection('feedback').add({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'rating': rating,
        'category': category,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('[Firestore] saveFeedback — ok');
    } catch (e) {
      debugPrint('[Firestore] saveFeedback ERROR: $e');
      rethrow;
    }
  }
}
