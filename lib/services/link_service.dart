import 'package:cloud_firestore/cloud_firestore.dart';
import 'realtime_database_service.dart';

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

  /// Writes UID into both sides so each document knows who it is linked to.
  ///
  /// Writes are deliberately SEPARATE so the patient's own doc is always
  /// updated even if the cross-user write to the guardian doc is denied
  /// (e.g., before Firestore rules are deployed). Once rules are live both
  /// writes succeed and Source 1 of every stream works instantly.
  static Future<void> linkAttendantToPatient({
    required String patientUid,
    required String patientName,
    required String attendantUid,
    required String attendantName,
  }) async {
    // Firestore — kept for chat queries (linked_guardians array-contains).
    try {
      await _db.collection('patients').doc(patientUid).set(
        {'linked_guardians': FieldValue.arrayUnion([attendantUid])},
        SetOptions(merge: true),
      );
    } catch (_) {}
    try {
      await _db.collection('guardians').doc(attendantUid).set(
        {'linked_patients': FieldValue.arrayUnion([patientUid])},
        SetOptions(merge: true),
      );
    } catch (_) {}

    // RTDB — real-time stream source for attendant dashboard + chat list.
    RealtimeDatabaseService.addLinkedGuardian(
      patientUid: patientUid,
      guardianUid: attendantUid,
    ).catchError((_) {});
    RealtimeDatabaseService.addLinkedPatient(
      guardianUid: attendantUid,
      patientUid: patientUid,
    ).catchError((_) {});
  }

  /// Remove link between patient and guardian.
  static Future<void> unlink({
    required String patientUid,
    required String attendantUid,
    String? patientName,
  }) async {
    // Firestore
    await Future.wait([
      _db.collection('patients').doc(patientUid).update({
        'linked_guardians': FieldValue.arrayRemove([attendantUid]),
      }),
      _db.collection('guardians').doc(attendantUid).update({
        'linked_patients': FieldValue.arrayRemove([patientUid]),
      }),
    ]);
    // RTDB
    RealtimeDatabaseService.removeLink(
      patientUid: patientUid,
      guardianUid: attendantUid,
    ).catchError((_) {});
    RealtimeDatabaseService.removeGuardianPatientLink(
      guardianUid: attendantUid,
      patientUid:  patientUid,
    ).catchError((_) {});
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

      // Resolve manual guardians by email (always lowercase to match saveManualGuardians)
      final resolvedMgIds = <String>{};
      for (final mg in manualList) {
        final email = (mg['email'] as String? ?? '').trim().toLowerCase();
        if (email.isEmpty) continue;
        try {
          // Query both flat (new saveProfile layout) and nested (legacy) email
          // fields so guardians are found regardless of which version wrote them.
          final qs = await Future.wait([
            _db.collection('guardians').where('email', isEqualTo: email).get(),
            _db.collection('guardians').where('profile.email', isEqualTo: email).get(),
          ]);
          final seen = <String>{};
          final allDocs = [...qs[0].docs, ...qs[1].docs]
              .where((d) => seen.add(d.id))
              .toList();
          for (final doc in allDocs) {
            if (resultMap.containsKey(doc.id)) {
              resolvedMgIds.add(mg['id'] as String? ?? '');
              continue;
            }
            final gData = doc.data();
            final profile = gData['profile'] as Map<String, dynamic>?;
            final name = gData['name'] as String?
                ?? profile?['name'] as String?
                ?? mg['name'] as String?
                ?? 'Guardian';
            resultMap[doc.id] = {
              'attendant_uid': doc.id,
              'attendant_name': name,
            };
            resolvedMgIds.add(mg['id'] as String? ?? '');
            linkAttendantToPatient(
              patientUid: patientUid,
              patientName: '',
              attendantUid: doc.id,
              attendantName: name,
            ).catchError((_) {});
          }
        } catch (_) {}
      }

      // Add phone-only manual guardians as pending entries so the chat list
      // shows them even before they have registered an account.
      for (final mg in manualList) {
        final mgId = (mg['id'] as String? ?? '').trim();
        if (resolvedMgIds.contains(mgId)) continue; // already resolved via email
        final phone = (mg['phone'] as String? ?? '').trim();
        final name = (mg['name'] as String? ?? 'Guardian').trim();
        if (phone.isEmpty && name.isEmpty) continue;
        final pendingKey = 'pending_$mgId';
        if (resultMap.containsKey(pendingKey)) continue;
        resultMap[pendingKey] = {
          'attendant_uid': pendingKey,
          'attendant_name': name.isEmpty ? 'Guardian' : name,
          'phone': phone,
          'is_pending': true,
        };
      }

      return resultMap.values.toList();
    });
  }

  /// Stream all patients linked to a guardian with their names.
  /// Returns: [{patient_uid: String, patient_name: String}]
  ///
  /// Combines two sources so patients show up even before QR scanning:
  ///   1. guardians/{uid}.linked_patients — already-linked UIDs
  ///   2. Reverse email lookup — patients that listed this guardian's email in
  ///      guardian_emails; auto-links them for future instant reads.
  static Stream<List<Map<String, dynamic>>> linkedPatientsStream(
      String guardianUid) {
    return _db
        .collection('guardians')
        .doc(guardianUid)
        .snapshots()
        .asyncMap((snap) async {
      if (!snap.exists) return [];
      final data = snap.data()!;

      // Source 1: already-linked patient UIDs
      final patientUids =
          List<String>.from(data['linked_patients'] as List? ?? []);

      // Get guardian's email for reverse lookup (flat or nested layout)
      final profile = data['profile'] as Map<String, dynamic>?;
      final guardianEmail = ((data['email'] as String?)
                  ?? (profile?['email'] as String?)
                  ?? '')
              .trim()
              .toLowerCase();

      final resultMap = <String, Map<String, dynamic>>{};

      // Fetch names for already-linked patients
      if (patientUids.isNotEmpty) {
        final snaps = await Future.wait(patientUids
            .map((uid) => _db.collection('patients').doc(uid).get()));
        for (int i = 0; i < snaps.length; i++) {
          final uid = patientUids[i];
          final pData = snaps[i].data() ?? <String, dynamic>{};
          final pProfile = pData['profile'] as Map<String, dynamic>?;
          resultMap[uid] = {
            'patient_uid': uid,
            'patient_name': pData['name'] as String?
                ?? pProfile?['name'] as String?
                ?? 'Patient',
          };
        }
      }

      // Source 2: reverse email lookup
      if (guardianEmail.isNotEmpty) {
        try {
          final pSnaps = await _db
              .collection('patients')
              .where('guardian_emails', arrayContains: guardianEmail)
              .get();
          for (final doc in pSnaps.docs) {
            if (resultMap.containsKey(doc.id)) continue;
            final pData = doc.data();
            final pProfile = pData['profile'] as Map<String, dynamic>?;
            final name = pData['name'] as String?
                ?? pProfile?['name'] as String?
                ?? 'Patient';
            resultMap[doc.id] = {'patient_uid': doc.id, 'patient_name': name};
            // Auto-link so next stream emission comes from Source 1
            linkAttendantToPatient(
              patientUid: doc.id,
              patientName: name,
              attendantUid: guardianUid,
              attendantName: '',
            ).catchError((_) {});
          }
        } catch (_) {}
      }

      return resultMap.values.toList();
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
  ///
  /// Primary: reads guardian_snapshot field on the patient doc (pre-resolved UIDs
  /// + phone numbers, always readable, no cross-collection queries needed).
  /// Fallback: reads linked_guardians + manual_guardians from the patient doc.
  static Future<List<Map<String, dynamic>>> guardianContactDetails(
      String patientUid) async {
    final snap = await _db.collection('patients').doc(patientUid).get();
    if (!snap.exists) return [];
    final data = snap.data()!;

    // ── Primary: guardian_snapshot field (has UIDs + phone numbers, no extra reads) ──
    final snapField = data['guardian_snapshot'] as Map?;
    final snapGuardians = snapField?['linked_guardians'] as List?;
    if (snapGuardians != null && snapGuardians.isNotEmpty) {
      return snapGuardians
          .map((g) => Map<String, dynamic>.from(g as Map))
          .where((g) {
            final phone = (g['phone'] as String? ?? '').trim();
            final uid = (g['uid'] as String? ?? '').trim();
            return phone.isNotEmpty || uid.isNotEmpty;
          })
          .map((g) => <String, dynamic>{
                'uid': g['uid'] as String? ?? '',
                'name': g['name'] as String? ?? 'Guardian',
                'phone': g['phone'] as String? ?? '',
                'email': g['email'] as String? ?? '',
                'is_linked': (g['uid'] as String? ?? '').isNotEmpty,
              })
          .toList();
    }

    // ── Fallback: registered linked guardians + manual_guardians ─────────────
    // ── Source 1: registered linked guardians ──────────────────────────────
    final guardianUids =
        List<String>.from(data['linked_guardians'] as List? ?? []);
    final details = <Map<String, dynamic>>[];
    final seenEmails = <String>{};

    for (final gUid in guardianUids) {
      try {
        final gSnap = await _db.collection('guardians').doc(gUid).get();
        if (!gSnap.exists) continue;
        final gData = gSnap.data()!;
        final profile = gData['profile'] as Map<String, dynamic>?;
        final email = (profile?['email'] as String?
                ?? gData['email'] as String?
                ?? '')
            .toLowerCase();
        if (email.isNotEmpty) seenEmails.add(email);
        details.add({
          'uid': gUid,
          'name': gData['name'] as String?
              ?? profile?['name'] as String?
              ?? 'Guardian',
          'phone': profile?['phone'] as String?
              ?? gData['phone'] as String?
              ?? '',
          'email': email,
          'is_linked': true,
        });
      } catch (_) {}
    }

    // ── Source 2: manual_guardians — email lookup to find registered UIDs ─────
    final manualList =
        List<Map<String, dynamic>>.from(data['manual_guardians'] as List? ?? []);
    for (final mg in manualList) {
      final phone = (mg['phone'] as String? ?? '').trim();
      final rawEmail = (mg['email'] as String? ?? '').trim();
      final email = rawEmail.toLowerCase();
      if (email.isNotEmpty && seenEmails.contains(email)) continue;

      // Find a registered guardian account matching this email (flat + nested layout).
      String? foundUid;
      String? foundName;
      if (email.isNotEmpty) {
        try {
          final qs = await Future.wait([
            _db.collection('guardians').where('email', isEqualTo: email).get(),
            _db.collection('guardians').where('profile.email', isEqualTo: email).get(),
          ]);
          final seen = <String>{};
          final allDocs = [...qs[0].docs, ...qs[1].docs]
              .where((d) => seen.add(d.id))
              .toList();
          if (allDocs.isNotEmpty) {
            final doc = allDocs.first;
            foundUid = doc.id;
            final gData = doc.data();
            final profile = gData['profile'] as Map<String, dynamic>?;
            foundName = gData['name'] as String?
                ?? profile?['name'] as String?;
            seenEmails.add(email);
            // Auto-link so future lookups skip this email query
            linkAttendantToPatient(
              patientUid: patientUid,
              patientName: '',
              attendantUid: foundUid,
              attendantName: foundName ?? mg['name'] as String? ?? 'Guardian',
            ).catchError((_) {});
          }
        } catch (_) {}
      }

      if (phone.isEmpty && foundUid == null) continue;
      details.add({
        'uid': foundUid,
        'name': foundName ?? mg['name'] as String? ?? 'Guardian',
        'phone': phone,
        'email': email,
        'is_linked': foundUid != null,
      });
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
    for (final rawEmail in guardianEmails) {
      final email = rawEmail.trim().toLowerCase();
      if (email.isEmpty) continue;
      try {
        final qs = await Future.wait([
          _db.collection('guardians').where('email', isEqualTo: email).get(),
          _db.collection('guardians').where('profile.email', isEqualTo: email).get(),
        ]);
        final seen = <String>{};
        final allDocs = [...qs[0].docs, ...qs[1].docs]
            .where((d) => seen.add(d.id))
            .toList();
        for (final doc in allDocs) {
          final gData = doc.data();
          final profile = gData['profile'] as Map<String, dynamic>?;
          await linkAttendantToPatient(
            patientUid: patientUid,
            patientName: '',
            attendantUid: doc.id,
            attendantName: gData['name'] as String?
                ?? profile?['name'] as String?
                ?? 'Guardian',
          );
        }
      } catch (_) {}
    }
  }

  /// Called when a guardian logs in: finds any patients who listed this
  /// guardian's email and links them automatically.
  ///
  /// Sources checked (in order):
  ///   1. RTDB guardian_requests — written by patient on every login, works
  ///      even when Firestore patients collection is empty (old accounts).
  ///   2. Firestore patients WHERE guardian_emails arrayContains email — for
  ///      accounts that saved data to Firestore before this migration.
  static Future<void> autoLinkGuardianToPatients({
    required String guardianUid,
    required String guardianEmail,
  }) async {
    final email = guardianEmail.trim().toLowerCase();
    if (email.isEmpty) return;

    final linked = <String>{};

    // Source 1: RTDB guardian_requests (primary — works without Firestore).
    try {
      final requests =
          await RealtimeDatabaseService.readGuardianRequests(email);
      for (final req in requests) {
        final patientUid  = (req['patient_uid']  as String? ?? '').trim();
        final patientName = (req['patient_name'] as String? ?? 'Patient').trim();
        if (patientUid.isEmpty || linked.contains(patientUid)) continue;
        linked.add(patientUid);
        RealtimeDatabaseService.saveGuardianPatientLink(
          guardianUid:   guardianUid,
          guardianEmail: email,
          patientUid:    patientUid,
          patientName:   patientName,
        ).catchError((_) {});
        linkAttendantToPatient(
          patientUid:   patientUid,
          patientName:  patientName,
          attendantUid: guardianUid,
          attendantName: '',
        ).catchError((_) {});
      }
    } catch (_) {}

    // Source 2: Firestore fallback.
    try {
      final snaps = await _db
          .collection('patients')
          .where('guardian_emails', arrayContains: email)
          .get();
      for (final doc in snaps.docs) {
        if (linked.contains(doc.id)) continue;
        linked.add(doc.id);
        final data        = doc.data();
        final patientName = (data['profile'] as Map?)?['name'] as String?
            ?? data['name'] as String?
            ?? 'Patient';
        RealtimeDatabaseService.saveGuardianPatientLink(
          guardianUid:   guardianUid,
          guardianEmail: email,
          patientUid:    doc.id,
          patientName:   patientName,
        ).catchError((_) {});
        linkAttendantToPatient(
          patientUid:   doc.id,
          patientName:  patientName,
          attendantUid: guardianUid,
          attendantName: '',
        ).catchError((_) {});
      }
    } catch (_) {}
  }

  // ── Latest vitals ─────────────────────────────────────────────────────────

  /// Called by patient app after each AI analysis run.
  ///
  /// Writes vitals to vitals_latest/{patientUid} (existing read path for
  /// guardian dashboard when linked_patients is populated), AND to
  /// vitals_latest/{guardianUid} for each resolved guardian so the guardian
  /// dashboard can display data immediately without waiting for QR linking.
  ///
  /// Also auto-links both sides (linked_guardians / linked_patients) so that
  /// chat and emergency alerts start working from the very first analysis run.
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
    // Push to RTDB — instant, push-based, no Firestore latency.
    RealtimeDatabaseService.pushVitals(
      heartRate: heartRate,
      spo2: spO2,
      hrv: hrv,
      rr: respirationRate,
      fallDetected: false,
      healthStatus: healthStatus,
      healthScore: healthScore,
    ).catchError((_) {});

    // Resolve guardian UIDs and push to their RTDB feeds in the background.
    _pushVitalsToGuardians(
      patientUid: patientUid,
      patientName: patientName,
      heartRate: heartRate,
      spO2: spO2,
      hrv: hrv,
      respirationRate: respirationRate,
      healthStatus: healthStatus,
      healthScore: healthScore,
    ).catchError((_) {});
  }

  /// Resolves linked guardian UIDs and pushes vitals to each one's RTDB feed.
  /// Also auto-links both sides so chat works from the first analysis run.
  static Future<void> _pushVitalsToGuardians({
    required String patientUid,
    required String patientName,
    required double heartRate,
    required double spO2,
    required double hrv,
    required double respirationRate,
    required String healthStatus,
    required double healthScore,
  }) async {
    final snap = await _db.collection('patients').doc(patientUid).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final manualList = List<Map<String, dynamic>>.from(
        data['manual_guardians'] as List? ?? []);

    for (final mg in manualList) {
      final email = (mg['email'] as String? ?? '').trim().toLowerCase();
      if (email.isEmpty) continue;

      // Resolve email → guardian UID for RTDB feed push and auto-linking.
      try {
        final qs = await Future.wait([
          _db.collection('guardians').where('email', isEqualTo: email).get(),
          _db.collection('guardians').where('profile.email', isEqualTo: email).get(),
        ]);
        final seen = <String>{};
        final allDocs = [...qs[0].docs, ...qs[1].docs]
            .where((d) => seen.add(d.id))
            .toList();
        for (final doc in allDocs) {
          final guardianUid = doc.id;
          final gData = doc.data();
          final gProfile = gData['profile'] as Map<String, dynamic>?;
          final guardianName = gData['name'] as String?
              ?? gProfile?['name'] as String?
              ?? mg['name'] as String?
              ?? 'Guardian';

          // Push to RTDB guardian feed — isolated per guardian, no broadcast.
          RealtimeDatabaseService.pushToGuardianFeed(
            patientUid: patientUid,
            patientName: patientName,
            guardianUid: guardianUid,
            heartRate: heartRate,
            spo2: spO2,
            hrv: hrv,
            rr: respirationRate,
            healthStatus: healthStatus,
            healthScore: healthScore,
          ).catchError((_) {});

          // Write to guardian_patients so the dashboard shows the patient
          // even before this guardian logs in.
          RealtimeDatabaseService.saveGuardianPatientLink(
            guardianUid:   guardianUid,
            guardianEmail: email,
            patientUid:    patientUid,
            patientName:   patientName,
          ).catchError((_) {});

          // Link both sides so in-app chat and SOS work.
          await linkAttendantToPatient(
            patientUid: patientUid,
            patientName: patientName,
            attendantUid: guardianUid,
            attendantName: guardianName,
          );
        }
      } catch (_) {}
    }
  }

  /// Stream latest vitals for a single patient (used by guardian dashboard).
  static Stream<Map<String, dynamic>?> patientVitalsStream(String patientUid) {
    return _db
        .collection('vitals_latest')
        .doc(patientUid)
        .snapshots()
        .map((s) => s.exists ? s.data() : null);
  }

  // ── Patient-owned guardian snapshot (stored on the patient doc itself) ──────
  //
  // patients/{patientUid}.guardian_snapshot = {
  //   linked_guardians: [{uid, name, email, phone, id}],
  //   updated_at: Timestamp,
  // }
  //
  // Written as a regular field on the patient document — no subcollection, no
  // new Firestore rules needed. The patient already has allow update: isOwner(uid).
  // Chat reads from this field, falling back to manual_guardians if it isn't set.

  /// Real-time stream of the patient document — chat reads guardian_snapshot
  /// from here, falling back to manual_guardians for existing users.
  static Stream<Map<String, dynamic>?> patientSnapshotStream(String patientUid) {
    if (patientUid.isEmpty) return Stream.value(null);
    return _db
        .collection('patients')
        .doc(patientUid)
        .snapshots()
        .map((s) => s.exists ? s.data() : null);
  }

  /// Writes the guardian roster into patients/{patientUid}.guardian_snapshot.
  /// Also pushes patient info to vitals_latest/{guardianEmail} so the guardian
  /// dashboard shows the patient immediately without UID resolution.
  static Future<void> saveGuardiansSnapshot({
    required String patientUid,
    required List<Map<String, dynamic>> guardians,
    String patientName = '',
  }) async {
    if (patientUid.isEmpty) return;
    try {
      final ref = _db.collection('patients').doc(patientUid);

      // Preserve UIDs that were already resolved in a previous save
      final existingUids = <String, String>{}; // lowercase_email → uid
      try {
        final existing = await ref.get();
        if (existing.exists) {
          final snap = existing.data()?['guardian_snapshot'] as Map?;
          for (final g in List<dynamic>.from(snap?['linked_guardians'] ?? [])) {
            final m = Map<String, dynamic>.from(g as Map);
            final e = (m['email'] as String? ?? '').toLowerCase();
            final u = (m['uid'] as String? ?? '');
            if (e.isNotEmpty && u.isNotEmpty) existingUids[e] = u;
          }
        }
      } catch (_) {}

      final merged = guardians.map((g) {
        final email = (g['email'] as String? ?? '').toLowerCase();
        final currentUid = (g['uid'] as String? ?? '');
        return <String, dynamic>{
          ...g,
          'email': email,
          'uid': currentUid.isNotEmpty ? currentUid : (existingUids[email] ?? ''),
        };
      }).toList();

      await ref.set({
        'guardian_snapshot': {
          'linked_guardians': merged,
          'updated_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      // Push minimal patient info to each guardian's email-keyed doc so the
      // guardian dashboard can discover the patient without UID resolution.
      final name = patientName.isEmpty ? 'Patient' : patientName;
      for (final g in merged) {
        final email = (g['email'] as String? ?? '').trim().toLowerCase();
        if (email.isNotEmpty) {
          _db.collection('vitals_latest').doc(email).set({
            'patient_uid': patientUid,
            'patient_name': name,
            'guardian_email': email,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }

      // Resolve any still-empty UIDs in the background
      if (merged.any((g) => (g['uid'] as String? ?? '').isEmpty)) {
        _resolveAndPatchUids(patientUid, merged).catchError((_) {});
      }
    } catch (_) {}
  }

  /// Queries guardians/ by email for entries with no uid, patches guardian_snapshot.
  static Future<void> _resolveAndPatchUids(
      String patientUid, List<Map<String, dynamic>> guardians) async {
    final patched = <Map<String, dynamic>>[];
    bool anyNew = false;
    for (final g in guardians) {
      final existing = (g['uid'] as String? ?? '').trim();
      if (existing.isNotEmpty) {
        patched.add(g);
        continue;
      }
      final email = (g['email'] as String? ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        patched.add(g);
        continue;
      }
      try {
        final qs = await Future.wait([
          _db.collection('guardians').where('email', isEqualTo: email).get(),
          _db.collection('guardians').where('profile.email', isEqualTo: email).get(),
        ]);
        final seen = <String>{};
        final docs = [...qs[0].docs, ...qs[1].docs].where((d) => seen.add(d.id)).toList();
        if (docs.isNotEmpty) {
          final gData = docs.first.data();
          final profile = gData['profile'] as Map?;
          final name = gData['name'] as String?
              ?? profile?['name'] as String?
              ?? g['name'] as String?
              ?? 'Guardian';
          patched.add({...g, 'uid': docs.first.id, 'name': name});
          anyNew = true;
          linkAttendantToPatient(
            patientUid: patientUid,
            patientName: '',
            attendantUid: docs.first.id,
            attendantName: name,
          ).catchError((_) {});
        } else {
          patched.add(g);
        }
      } catch (_) {
        patched.add(g);
      }
    }
    if (!anyNew) return;
    try {
      await _db.collection('patients').doc(patientUid).set({
        'guardian_snapshot': {'linked_guardians': patched},
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
