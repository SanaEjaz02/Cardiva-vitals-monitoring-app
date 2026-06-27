import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Realtime Database layout — all paths keyed by Firebase Auth UID so
/// security rules can enforce "only the owner can read/write their own data".
///
///   /bands/{bandId}/
///     owner_uid      : string  ← registered during patient profile setup
///     registered_at  : number  ← epoch ms
///
///   /vitals/{uid}/
///     heart_rate     : number
///     spo2           : number
///     hrv            : number
///     rr             : number
///     fall_detected  : boolean
///     health_status  : string
///     health_score   : number
///     updated_at     : number  ← epoch ms
///
///   /guardian_feeds/{guardianUid}/{patientUid}/
///     patient_name   : string
///     heart_rate     : number
///     spo2           : number
///     hrv            : number
///     rr             : number
///     health_status  : string
///     health_score   : number
///     updated_at     : number
///
///   /notifications/{uid}/{pushId}/
///     title          : string
///     body           : string
///     type           : string  (emergency | warning | info)
///     is_read        : boolean
///     created_at     : number
class RealtimeDatabaseService {
  RealtimeDatabaseService._();

  static FirebaseDatabase get _rtdb => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://cardiva-30297-default-rtdb.firebaseio.com',
      );
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Band registration ─────────────────────────────────────────────────────

  /// Registers [bandId] as owned by the currently signed-in user.
  /// A band can only be claimed once; if already claimed by another UID
  /// the write is rejected by security rules (owner check).
  static Future<bool> registerBand(String bandId) async {
    final uid = _uid;
    if (uid == null || bandId.trim().isEmpty) return false;
    try {
      final ref = _rtdb.ref('bands/${bandId.trim()}');
      final snap = await ref.get();
      if (snap.exists) {
        final existingOwner = (snap.value as Map?)?['owner_uid'] as String?;
        if (existingOwner != null && existingOwner != uid) {
          debugPrint('[RTDB] Band $bandId already owned by another user');
          return false;
        }
      }
      await ref.set({
        'owner_uid': uid,
        'registered_at': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[RTDB] Band $bandId registered to $uid');
      return true;
    } catch (e) {
      debugPrint('[RTDB] registerBand ERROR: $e');
      return false;
    }
  }

  /// Returns the UID that owns [bandId], or null if unregistered.
  static Future<String?> getBandOwner(String bandId) async {
    try {
      final snap = await _rtdb.ref('bands/${bandId.trim()}/owner_uid').get();
      return snap.value as String?;
    } catch (e) {
      debugPrint('[RTDB] getBandOwner ERROR: $e');
      return null;
    }
  }

  // ── Live vitals (patient writes their own path) ──────────────────────────

  /// Patient pushes their latest vitals to /vitals/{uid}.
  /// Security rules only allow uid == auth.uid to write here.
  static Future<void> pushVitals({
    required double heartRate,
    required double spo2,
    required double hrv,
    required double rr,
    required bool fallDetected,
    required String healthStatus,
    required double healthScore,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _rtdb.ref('vitals/$uid').set({
        'heart_rate': heartRate,
        'spo2': spo2,
        'hrv': hrv,
        'rr': rr,
        'fall_detected': fallDetected,
        'health_status': healthStatus,
        'health_score': healthScore,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[RTDB] pushVitals ERROR: $e');
    }
  }

  /// Real-time stream of the patient's own vitals.
  static Stream<Map<String, dynamic>> watchOwnVitals() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _rtdb
        .ref('vitals/$uid')
        .onValue
        .map((event) => Map<String, dynamic>.from(
              (event.snapshot.value as Map? ?? {}),
            ));
  }

  // ── Guardian feeds (patient writes to guardian's feed path) ─────────────

  /// Patient pushes their latest vitals into each linked guardian's feed.
  /// The path /guardian_feeds/{guardianUid}/{patientUid} is writable only
  /// by the patient (auth.uid == patientUid segment).
  static Future<void> pushToGuardianFeed({
    required String patientUid,
    required String patientName,
    required String guardianUid,
    required double heartRate,
    required double spo2,
    required double hrv,
    required double rr,
    required String healthStatus,
    required double healthScore,
  }) async {
    try {
      await _rtdb.ref('guardian_feeds/$guardianUid/$patientUid').set({
        'patient_name': patientName,
        'heart_rate': heartRate,
        'spo2': spo2,
        'hrv': hrv,
        'rr': rr,
        'health_status': healthStatus,
        'health_score': healthScore,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[RTDB] pushToGuardianFeed ERROR: $e');
    }
  }

  /// Guardian streams all their patients' latest vitals in real time.
  static Stream<List<Map<String, dynamic>>> watchGuardianFeed() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _rtdb
        .ref('guardian_feeds/$uid')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(raw as Map);
      return map.entries.map((e) {
        final entry = Map<String, dynamic>.from(e.value as Map);
        entry['patient_uid'] = e.key;
        return entry;
      }).toList();
    });
  }

  // ── Per-user notifications ────────────────────────────────────────────────

  /// Pushes a notification to a specific user's /notifications/{uid} path.
  /// Only that user can read it (security rule: auth.uid == $uid).
  static Future<void> pushNotificationToUser({
    required String targetUid,
    required String title,
    required String body,
    required String type, // 'emergency' | 'warning' | 'info'
  }) async {
    try {
      final ref = _rtdb.ref('notifications/$targetUid').push();
      await ref.set({
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[RTDB] notification → $targetUid ($type)');
    } catch (e) {
      debugPrint('[RTDB] pushNotificationToUser ERROR: $e');
    }
  }

  /// Real-time stream of unread notifications for the signed-in user.
  static Stream<List<Map<String, dynamic>>> watchNotifications() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _rtdb
        .ref('notifications/$uid')
        .orderByChild('created_at')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(raw as Map);
      return map.entries.map((e) {
        final entry = Map<String, dynamic>.from(e.value as Map);
        entry['id'] = e.key;
        return entry;
      }).toList()
        ..sort((a, b) => (b['created_at'] as int)
            .compareTo(a['created_at'] as int));
    });
  }

  /// Mark a notification as read.
  static Future<void> markNotificationRead(String notifId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _rtdb
          .ref('notifications/$uid/$notifId/is_read')
          .set(true);
    } catch (e) {
      debugPrint('[RTDB] markNotificationRead ERROR: $e');
    }
  }

  // ── User profile ─────────────────────────────────────────────────────────

  /// Saves full user profile to /users/{uid}.
  /// Replaces Firestore saveProfile — no Firestore round-trip, instant write.
  static Future<void> saveUserProfile(Map<String, dynamic> profileJson) async {
    final uid = _uid;
    if (uid == null) {
      // ignore: avoid_print
      print('╔══ [RTDB] saveUserProfile SKIPPED — currentUser is null ══╗');
      return;
    }
    // Fire-and-forget at SDK level — RTDB queues locally and syncs when
    // WebSocket connects. Does NOT block the caller on devices where RTDB
    // WebSocket is slow or temporarily unavailable.
    _rtdb.ref('users/$uid').set({
      ...profileJson,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }).then((_) {
      debugPrint('[RTDB] saveUserProfile OK → users/$uid');
    }).catchError((Object e) {
      debugPrint('[RTDB] saveUserProfile ERROR: $e');
    });
  }

  /// Loads user profile from /users/{uid}.
  /// Returns null if not found.
  static Future<Map<String, dynamic>?> loadUserProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _rtdb.ref('users/$uid').get();
      if (!snap.exists || snap.value == null) return null;
      return Map<String, dynamic>.from(snap.value as Map);
    } catch (e) {
      debugPrint('[RTDB] loadUserProfile ERROR: $e');
      return null;
    }
  }

  // ── Chatbot sessions ──────────────────────────────────────────────────────

  /// Saves the full list of chatbot sessions to /chat_sessions/{uid}.
  /// Stored as a map keyed by session ID so each session is a child node.
  static Future<void> saveChatSessions(
      List<Map<String, dynamic>> sessions) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final map = <String, dynamic>{};
      for (final s in sessions) {
        final id = s['id'] as String? ?? s['session_id'] as String?;
        if (id == null) continue;
        map[id] = s;
      }
      await _rtdb.ref('chat_sessions/$uid').set(map);
      debugPrint('[RTDB] saveChatSessions — ok (${sessions.length})');
    } catch (e) {
      debugPrint('[RTDB] saveChatSessions ERROR: $e');
    }
  }

  /// Loads chatbot sessions from /chat_sessions/{uid}.
  /// Returns sessions sorted newest-first.
  static Future<List<Map<String, dynamic>>> loadChatSessions() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _rtdb.ref('chat_sessions/$uid').get();
      if (!snap.exists || snap.value == null) return [];
      final map = Map<String, dynamic>.from(snap.value as Map);
      final list = map.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      list.sort((a, b) {
        final at = a['createdAt'] as int? ?? a['created_at'] as int? ?? 0;
        final bt = b['createdAt'] as int? ?? b['created_at'] as int? ?? 0;
        return bt.compareTo(at);
      });
      return list;
    } catch (e) {
      debugPrint('[RTDB] loadChatSessions ERROR: $e');
      return [];
    }
  }

  // ── Guardian ↔ Patient linking ────────────────────────────────────────────

  /// Marks [guardianUid] as linked inside the patient's RTDB node.
  /// The guardian is the one writing their own UID (security rule allows this).
  static Future<void> addLinkedGuardian({
    required String patientUid,
    required String guardianUid,
  }) async {
    try {
      await _rtdb.ref('users/$patientUid/linked_guardians/$guardianUid').set(true);
    } catch (e) {
      debugPrint('[RTDB] addLinkedGuardian ERROR: $e');
    }
  }

  /// Marks [patientUid] as linked inside the guardian's RTDB node.
  /// The patient is the one writing their own UID (security rule allows this).
  static Future<void> addLinkedPatient({
    required String guardianUid,
    required String patientUid,
  }) async {
    try {
      await _rtdb.ref('users/$guardianUid/linked_patients/$patientUid').set(true);
    } catch (e) {
      debugPrint('[RTDB] addLinkedPatient ERROR: $e');
    }
  }

  /// Removes the guardian link from both sides.
  static Future<void> removeLink({
    required String patientUid,
    required String guardianUid,
  }) async {
    try {
      await Future.wait([
        _rtdb.ref('users/$patientUid/linked_guardians/$guardianUid').remove(),
        _rtdb.ref('users/$guardianUid/linked_patients/$patientUid').remove(),
      ]);
    } catch (e) {
      debugPrint('[RTDB] removeLink ERROR: $e');
    }
  }

  /// Real-time stream of the guardian's full feed (patient_uid + vitals).
  /// This is the single source of truth for the attendant dashboard.
  static Stream<List<Map<String, dynamic>>> watchGuardianFeedForUid(
      String guardianUid) {
    if (guardianUid.isEmpty) return const Stream.empty();
    return _rtdb
        .ref('guardian_feeds/$guardianUid')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(raw as Map);
      return map.entries.map((e) {
        final entry = Map<String, dynamic>.from(e.value as Map);
        entry['patient_uid'] = e.key;
        return entry;
      }).toList();
    });
  }

  // ── Guardian ↔ Patient roster (guardian_patients) ────────────────────────
  //
  // /guardian_patients/{guardianUid}/{patientUid}
  //   patient_uid    : string
  //   patient_name   : string
  //   guardian_id    : string
  //   guardian_email : string
  //
  // Readable only by the guardian; writable by BOTH the patient (on link) and
  // the guardian (on auto-link at login).  This path is the single source of
  // truth for which patients a guardian can see — populated even before the
  // patient pushes any vitals.

  /// Writes/updates a patient entry in the guardian's roster.
  static Future<void> saveGuardianPatientLink({
    required String guardianUid,
    required String guardianEmail,
    required String patientUid,
    required String patientName,
  }) async {
    if (guardianUid.isEmpty || patientUid.isEmpty) return;
    try {
      await _rtdb.ref('guardian_patients/$guardianUid/$patientUid').set({
        'patient_uid':    patientUid,
        'patient_name':   patientName,
        'guardian_id':    guardianUid,
        'guardian_email': guardianEmail.trim().toLowerCase(),
      });
    } catch (e) {
      debugPrint('[RTDB] saveGuardianPatientLink ERROR: $e');
    }
  }

  /// Removes a patient entry from the guardian's roster.
  static Future<void> removeGuardianPatientLink({
    required String guardianUid,
    required String patientUid,
  }) async {
    if (guardianUid.isEmpty || patientUid.isEmpty) return;
    try {
      await _rtdb.ref('guardian_patients/$guardianUid/$patientUid').remove();
    } catch (e) {
      debugPrint('[RTDB] removeGuardianPatientLink ERROR: $e');
    }
  }

  /// Real-time stream of all patients linked to [guardianUid].
  /// Available immediately after linking — does NOT require vitals to have
  /// been pushed.  Each entry: {patient_uid, patient_name, guardian_id, guardian_email}.
  static Stream<List<Map<String, dynamic>>> watchGuardianPatients(
      String guardianUid) {
    if (guardianUid.isEmpty) return const Stream.empty();
    return _rtdb
        .ref('guardian_patients/$guardianUid')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <Map<String, dynamic>>[];
      final map = Map<String, dynamic>.from(raw as Map);
      return map.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    });
  }

  /// Real-time stream of the guardian feed as a Map keyed by patientUid.
  /// Used alongside [watchGuardianPatients] to overlay vitals on the patient list.
  static Stream<Map<String, Map<String, dynamic>>> watchGuardianFeedAsMap(
      String guardianUid) {
    if (guardianUid.isEmpty) return const Stream.empty();
    return _rtdb
        .ref('guardian_feeds/$guardianUid')
        .onValue
        .map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <String, Map<String, dynamic>>{};
      final map = Map<String, dynamic>.from(raw as Map);
      return map.map(
          (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    });
  }

  // ── Account deletion ─────────────────────────────────────────────────────

  /// Deletes all RTDB data for the signed-in user.
  /// Also releases their band claim so another user can register the same band.
  static Future<void> deleteUserData() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Read bandId from profile before wiping it.
      final bandSnap = await _rtdb.ref('users/$uid/band_id').get();
      final bandId = bandSnap.value as String?;

      final tasks = <Future<void>>[
        _rtdb.ref('users/$uid').remove(),
        _rtdb.ref('vitals/$uid').remove(),
        _rtdb.ref('chat_sessions/$uid').remove(),
        _rtdb.ref('notifications/$uid').remove(),
      ];
      if (bandId != null && bandId.isNotEmpty) {
        tasks.add(_rtdb.ref('bands/$bandId').remove());
      }
      await Future.wait(tasks);
      debugPrint('[RTDB] deleteUserData → $uid (band: $bandId)');
    } catch (e) {
      debugPrint('[RTDB] deleteUserData ERROR: $e');
    }
  }

  // ── Email → UID index (Firestore-free guardian lookup) ────────────────────
  //
  // Every user writes their own email here at login.
  // Key: email with '.' replaced by ',' (RTDB keys can't contain dots).
  // Patient app reads this to find a guardian's UID without Firestore.

  static String _emailKey(String email) =>
      email.trim().toLowerCase().replaceAll('.', ',');

  /// Writes /email_index/{key} = {uid, email} so any authenticated user can
  /// look up a UID by email — no Firestore needed.
  static Future<void> saveEmailIndex(String email) async {
    final uid = _uid;
    if (uid == null || email.trim().isEmpty) return;
    try {
      await _rtdb.ref('email_index/${_emailKey(email)}').set({
        'uid':   uid,
        'email': email.trim().toLowerCase(),
      });
    } catch (e) {
      debugPrint('[RTDB] saveEmailIndex ERROR: $e');
    }
  }

  // ── Guardian request index (patient → guardian discovery) ────────────────
  //
  // /guardian_requests/{guardianEmailKey}/{patientUid}
  //   patient_uid  : string
  //   patient_name : string
  //   added_at     : number (epoch ms)
  //
  // Patient writes this on every login so the guardian can always find them
  // even if Firestore is empty or guardian_emails was never saved.

  /// Writes /guardian_requests/{guardianEmailKey}/{patientUid} so the guardian
  /// can discover this patient when they log in.
  static Future<void> saveGuardianRequest({
    required String guardianEmail,
    required String patientUid,
    required String patientName,
  }) async {
    if (guardianEmail.trim().isEmpty || patientUid.isEmpty) return;
    try {
      await _rtdb
          .ref('guardian_requests/${_emailKey(guardianEmail)}/$patientUid')
          .set({
        'patient_uid':  patientUid,
        'patient_name': patientName.isEmpty ? 'Patient' : patientName,
        'added_at':     DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[RTDB] saveGuardianRequest ERROR: $e');
    }
  }

  /// Reads all patients who have listed [guardianEmail] as their guardian.
  /// Returns list of {patient_uid, patient_name}.
  static Future<List<Map<String, dynamic>>> readGuardianRequests(
      String guardianEmail) async {
    if (guardianEmail.trim().isEmpty) return [];
    try {
      final snap =
          await _rtdb.ref('guardian_requests/${_emailKey(guardianEmail)}').get();
      if (!snap.exists || snap.value == null) return [];
      final map = Map<String, dynamic>.from(snap.value as Map);
      return map.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    } catch (e) {
      debugPrint('[RTDB] readGuardianRequests ERROR: $e');
      return [];
    }
  }

  /// Returns the UID of a registered user with [email], or null if not found.
  static Future<String?> getUidByEmail(String email) async {
    if (email.trim().isEmpty) return null;
    try {
      final snap = await _rtdb.ref('email_index/${_emailKey(email)}').get();
      if (snap.exists) {
        return (snap.value as Map?)?['uid'] as String?;
      }
    } catch (e) {
      debugPrint('[RTDB] getUidByEmail ERROR: $e');
    }
    return null;
  }

  /// Saves a resolved guardian UID under the patient's own RTDB node.
  /// Used by the patient chat screen so the guardian list never shows "pending"
  /// for an already-registered guardian even when Firestore is unavailable.
  static Future<void> saveResolvedGuardian({
    required String patientUid,
    required String guardianUid,
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      await _rtdb.ref('users/$patientUid/resolved_guardians/$guardianUid').set({
        'uid':   guardianUid,
        'name':  name,
        'email': email.trim().toLowerCase(),
        'phone': phone,
      });
    } catch (e) {
      debugPrint('[RTDB] saveResolvedGuardian ERROR: $e');
    }
  }

  /// Real-time stream of resolved guardians for a patient.
  /// Returns a map keyed by guardianUid → {uid, name, email, phone}.
  static Stream<Map<String, Map<String, dynamic>>> watchResolvedGuardians(
      String patientUid) {
    if (patientUid.isEmpty) return const Stream.empty();
    return _rtdb
        .ref('users/$patientUid/resolved_guardians')
        .onValue
        .map((event) {
      final val = event.snapshot.value;
      if (val == null) return {};
      final raw = Map<String, dynamic>.from(val as Map);
      return raw.map((k, v) => MapEntry(
            k,
            Map<String, dynamic>.from(v as Map),
          ));
    });
  }

  // ── Presence / online state ───────────────────────────────────────────────

  /// Sets the signed-in user as online. Automatically clears on disconnect.
  static void setOnline() {
    final uid = _uid;
    if (uid == null) return;
    final presenceRef = _rtdb.ref('presence/$uid');
    presenceRef.onDisconnect().remove();
    presenceRef.set({
      'online': true,
      'last_seen': ServerValue.timestamp,
    });
  }
}
