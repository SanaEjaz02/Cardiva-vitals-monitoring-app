import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages QR-based patient ↔ guardian linking and latest-vitals publishing.
///
/// Firestore layout:
///
///   patients/{patientUid}
///     linked_guardians : [guardianUid1, guardianUid2, ...]  ← UID array
///     (+ profile, manual_guardians, analysis_history/, health_reports/)
///
///   guardians/{guardianUid}
///     linked_patients  : [patientUid1, patientUid2, ...]   ← UID array
///     (+ profile, role)
///
///   vitals_latest/{patientUid} — latest vitals pushed after each AI analysis
class LinkService {
  LinkService._();

  static final _db = FirebaseFirestore.instance;

  // ── Linking ───────────────────────────────────────────────────────────────

  /// Called when a guardian scans a patient's QR code.
  /// Writes UID into both sides so each document knows who it is linked to.
  static Future<void> linkAttendantToPatient({
    required String patientUid,
    required String patientName,
    required String attendantUid,
    required String attendantName,
  }) async {
    await Future.wait([
      // Add guardianUid to patient's linked_guardians array
      _db.collection('patients').doc(patientUid).set(
        {'linked_guardians': FieldValue.arrayUnion([attendantUid])},
        SetOptions(merge: true),
      ),
      // Add patientUid to guardian's linked_patients array
      _db.collection('guardians').doc(attendantUid).set(
        {'linked_patients': FieldValue.arrayUnion([patientUid])},
        SetOptions(merge: true),
      ),
    ]);
  }

  /// Remove link between patient and guardian.
  static Future<void> unlink({
    required String patientUid,
    required String attendantUid,
    String? patientName,
  }) async {
    await Future.wait([
      _db.collection('patients').doc(patientUid).update({
        'linked_guardians': FieldValue.arrayRemove([attendantUid]),
      }),
      _db.collection('guardians').doc(attendantUid).update({
        'linked_patients': FieldValue.arrayRemove([patientUid]),
      }),
    ]);
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Stream all guardians the patient can chat with.
  ///
  /// Combines two sources so the list is never empty just because QR hasn't
  /// been scanned:
  ///   1. `patients/{uid}.linked_guardians` — QR / email auto-linked UIDs
  ///   2. `patients/{uid}.manual_guardians` — manually added contacts; each
  ///      email is looked up in `guardians/` to find a registered account
  ///
  /// Any match found in source 2 is also written to linked_guardians so
  /// future reads are instant.
  static Stream<List<Map<String, dynamic>>> linkedGuardiansStream(
      String patientUid) {
    return _db
        .collection('patients')
        .doc(patientUid)
        .snapshots()
        .asyncMap((snap) async {
      if (!snap.exists) return [];
      final data = snap.data()!;

      // ── Source 1: already-linked guardian UIDs ──────────────────────────
      final linkedUids = List<String>.from(
          data['linked_guardians'] as List? ?? []);

      // ── Source 2: manual guardians — look up by email ──────────────────
      final manualList = List<Map<String, dynamic>>.from(
          data['manual_guardians'] as List? ?? []);

      final resultMap = <String, Map<String, dynamic>>{};

      // Fetch names for already-linked guardians
      if (linkedUids.isNotEmpty) {
        final snaps = await Future.wait(
            linkedUids.map((uid) => _db.collection('guardians').doc(uid).get()));
        for (int i = 0; i < snaps.length; i++) {
          final uid = linkedUids[i];
          final gData = snaps[i].data() ?? <String, dynamic>{};
          final profile = gData['profile'] as Map<String, dynamic>?;
          resultMap[uid] = {
            'attendant_uid': uid,
            'attendant_name': gData['name'] as String?
                ?? profile?['name'] as String?
                ?? 'Guardian',
          };
        }
      }

      // Resolve manual guardians by email
      for (final mg in manualList) {
        final email = (mg['email'] as String? ?? '').trim();
        if (email.isEmpty) continue;
        try {
          final q = await _db
              .collection('guardians')
              .where('profile.email', isEqualTo: email)
              .get();
          for (final doc in q.docs) {
            if (resultMap.containsKey(doc.id)) continue; // already in list
            final profile = doc.data()['profile'] as Map<String, dynamic>?;
            resultMap[doc.id] = {
              'attendant_uid': doc.id,
              'attendant_name': profile?['name'] as String?
                  ?? mg['name'] as String?
                  ?? 'Guardian',
            };
            // Persist the link so next read is instant
            linkAttendantToPatient(
              patientUid: patientUid,
              patientName: '',
              attendantUid: doc.id,
              attendantName:
                  profile?['name'] as String? ?? 'Guardian',
            ).catchError((_) {});
          }
        } catch (_) {}
      }

      return resultMap.values.toList();
    });
  }

  /// Stream all patients linked to a guardian with their names.
  /// Returns: [{patient_uid: String, patient_name: String}]
  ///
  /// Reads patient UIDs from guardians/{guardianUid}.linked_patients,
  /// then fetches each patient's name from patients/{uid}.
  static Stream<List<Map<String, dynamic>>> linkedPatientsStream(
      String guardianUid) {
    return _db
        .collection('guardians')
        .doc(guardianUid)
        .snapshots()
        .asyncMap((snap) async {
      if (!snap.exists) return [];
      final patientUids = List<String>.from(
          snap.data()!['linked_patients'] as List? ?? []);
      if (patientUids.isEmpty) return [];

      // Fetch all patient profiles in parallel
      final snaps = await Future.wait(
          patientUids.map((uid) => _db.collection('patients').doc(uid).get()));

      return snaps.asMap().entries.map((e) {
        final pData = e.value.data() ?? <String, dynamic>{};
        final profile = pData['profile'] as Map<String, dynamic>?;
        return {
          'patient_uid': patientUids[e.key],
          'patient_name': pData['name'] as String?
              ?? profile?['name'] as String?
              ?? 'Patient',
        };
      }).toList();
    });
  }

  /// Stream of all guardian UIDs linked to a patient.
  /// Used by the emergency trigger to broadcast to all linked guardians.
  static Stream<List<String>> linkedAttendantsStream(String patientUid) {
    return _db
        .collection('patients')
        .doc(patientUid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return [];
      return List<String>.from(
          snap.data()!['linked_guardians'] as List? ?? []);
    });
  }

  /// Fetches guardian phone + email for emergency SMS.
  /// Reads UIDs from patients/{patientUid}.linked_guardians,
  /// then reads contact details from each guardians/{gid} document.
  static Future<List<Map<String, dynamic>>> guardianContactDetails(
      String patientUid) async {
    final snap = await _db.collection('patients').doc(patientUid).get();
    if (!snap.exists) return [];

    final guardianUids = List<String>.from(
        snap.data()!['linked_guardians'] as List? ?? []);
    if (guardianUids.isEmpty) return [];

    final details = <Map<String, dynamic>>[];
    for (final gUid in guardianUids) {
      try {
        final gSnap = await _db.collection('guardians').doc(gUid).get();
        if (!gSnap.exists) continue;
        final gData = gSnap.data()!;
        final profile = gData['profile'] as Map<String, dynamic>?;
        details.add({
          'uid': gUid,
          'name': gData['name'] as String?
              ?? profile?['name'] as String?
              ?? 'Guardian',
          'phone': profile?['phone'] as String?
              ?? gData['phone'] as String?
              ?? '',
          'email': profile?['email'] as String?
              ?? gData['email'] as String?
              ?? '',
        });
      } catch (_) {}
    }
    return details;
  }

  /// Looks up a patient's display name from patients/{patientUid}.
  /// Falls back to vitals_latest if the patient document has no name yet.
  static Future<String> getPatientName(String patientUid) async {
    try {
      final snap = await _db.collection('patients').doc(patientUid).get();
      if (snap.exists) {
        final data = snap.data()!;
        final profile = data['profile'] as Map<String, dynamic>?;
        final name = data['name'] as String? ?? profile?['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    // Fallback: vitals_latest might have patient_name from previous analysis
    try {
      final v = await _db.collection('vitals_latest').doc(patientUid).get();
      if (v.exists) {
        return v.data()?['patient_name'] as String? ?? 'Patient';
      }
    } catch (_) {}
    return 'Patient';
  }

  // ── Email-based auto-linking ──────────────────────────────────────────────

  /// Called when a patient saves manual guardians: finds any already-registered
  /// guardian accounts matching those emails and links them automatically.
  static Future<void> autoLinkByEmails({
    required String patientUid,
    required List<String> guardianEmails,
  }) async {
    for (final email in guardianEmails) {
      if (email.isEmpty) continue;
      try {
        final snaps = await _db
            .collection('guardians')
            .where('profile.email', isEqualTo: email)
            .get();
        for (final doc in snaps.docs) {
          final profile = doc.data()['profile'] as Map<String, dynamic>?;
          await linkAttendantToPatient(
            patientUid: patientUid,
            patientName: '',
            attendantUid: doc.id,
            attendantName: profile?['name'] as String? ?? 'Guardian',
          );
        }
      } catch (_) {}
    }
  }

  /// Called when a guardian saves their profile: finds any patients who listed
  /// this guardian's email in manual_guardians and links them automatically.
  static Future<void> autoLinkGuardianToPatients({
    required String guardianUid,
    required String guardianEmail,
  }) async {
    if (guardianEmail.isEmpty) return;
    try {
      final snaps = await _db
          .collection('patients')
          .where('guardian_emails', arrayContains: guardianEmail)
          .get();
      for (final doc in snaps.docs) {
        await linkAttendantToPatient(
          patientUid: doc.id,
          patientName:
              (doc.data()['profile'] as Map?)?['name'] as String? ?? 'Patient',
          attendantUid: guardianUid,
          attendantName: '',
        );
      }
    } catch (_) {}
  }

  // ── Latest vitals ─────────────────────────────────────────────────────────

  /// Called by patient app after each AI analysis run.
  static Future<void> pushLatestVitals({
    required String patientUid,
    required String patientName,
    required double heartRate,
    required double spO2,
    required double hrv,
    required double respirationRate,
    required String healthStatus,
    required double healthScore,
  }) async {
    await _db.collection('vitals_latest').doc(patientUid).set({
      'patient_uid': patientUid,
      'patient_name': patientName,
      'heart_rate': heartRate,
      'spo2': spO2,
      'hrv': hrv,
      'respiration_rate': respirationRate,
      'health_status': healthStatus,
      'health_score': healthScore,
      'updated_at': Timestamp.now(),
    });
  }

  /// Stream latest vitals for a single patient (used by guardian dashboard).
  static Stream<Map<String, dynamic>?> patientVitalsStream(String patientUid) {
    return _db
        .collection('vitals_latest')
        .doc(patientUid)
        .snapshots()
        .map((s) => s.exists ? s.data() : null);
  }
}
