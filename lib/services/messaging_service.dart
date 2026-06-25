import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/in_app_message.dart';

/// Firestore layout:
///   /patient_alerts/{patientUid}/alerts/{alertId}
///
/// Patient writes to their own sub-collection.
/// Attendant reads from the patient UID they are monitoring.
class MessagingService {
  MessagingService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference _alertsRef(String patientUid) =>
      _db.collection('patient_alerts').doc(patientUid).collection('alerts');

  /// Patient calls this when an emergency fires or a report is ready.
  static Future<void> sendAlert({
    required String patientUid,
    required String patientName,
    required String type,
    required String content,
  }) async {
    await _alertsRef(patientUid).add(InAppMessage(
      id: '',
      fromUid: patientUid,
      fromName: patientName,
      type: type,
      content: content,
      timestamp: DateTime.now(),
    ).toFirestore());
  }

  /// Attendant calls this to get a live stream of alerts for their patient.
  static Stream<List<InAppMessage>> alertStream(String patientUid) {
    return _alertsRef(patientUid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => InAppMessage.fromFirestore(d)).toList());
  }

  /// Mark a single alert as read.
  static Future<void> markRead(String patientUid, String alertId) =>
      _alertsRef(patientUid).doc(alertId).update({'is_read': true});

  /// Mark all alerts as read.
  static Future<void> markAllRead(String patientUid) async {
    final snap = await _alertsRef(patientUid)
        .where('is_read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
