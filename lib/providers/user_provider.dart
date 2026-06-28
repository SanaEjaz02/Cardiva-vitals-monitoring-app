import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/realtime_database_service.dart';
import '../services/link_service.dart';

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(null);

  void setUser(UserProfile profile) => state = profile;
  void clearUser() => state = null;
  void updateProfile(UserProfile updated) => state = updated;

  /// Loads profile from local cache (instant) then syncs RTDB in background.
  /// Navigation happens immediately from cache — no server round-trip on the
  /// critical path.
  Future<void> loadFromStore() async {
    state = null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Write email→UID into RTDB immediately on every login, using the value
      // that Firebase Auth always has — does NOT wait for the profile sync.
      // This is what lets the patient's chat screen resolve guardian UIDs even
      // when the guardian has never completed profile setup in the new RTDB flow.
      final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (currentEmail.isNotEmpty) {
        RealtimeDatabaseService.saveEmailIndex(currentEmail).catchError((_) {});
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_profile_$uid');
      if (raw != null) {
        // Cache hit — populate state immediately, sync RTDB in background.
        state = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _syncRtdb(uid, prefs);
      } else {
        // No cache (first login / new install) — must await so navigation
        // can read the role and route correctly.
        await _syncRtdb(uid, prefs);
      }
    } catch (e) {
      debugPrint('[UserProvider] loadFromStore error: $e');
    }
  }

  Future<void> _syncRtdb(String uid, SharedPreferences prefs) async {
    try {
      // 5-second cap so a slow RTDB cold-start never blocks navigation.
      Map<String, dynamic>? data = await RealtimeDatabaseService
          .loadUserProfile()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (data == null) {
        // RTDB miss: new device, cleared data, or account created before the
        // RTDB-first migration.  Fall back to Firestore (now has rules deployed).
        final fs = await FirestoreService.loadRoleAndProfile()
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (fs != null) {
          data = <String, dynamic>{...fs.profile, 'id': uid, 'role': fs.role};
          // Backfill RTDB so the next login is instant from cache.
          RealtimeDatabaseService.saveUserProfile(data);
        }
      }

      if (data == null) return;

      final profile = UserProfile.fromJson(data);
      state = profile;
      await prefs.setString('user_profile_$uid', jsonEncode(data));

      // Keep Firestore in sync so email-based lookups work for ALL users.
      FirestoreService.saveProfile(data, uid: uid).catchError((_) {});

      if (profile.role == UserRole.patient) {
        _resolvePatientGuardians(uid, data).catchError((_) {});
      } else if (profile.role == UserRole.attendant) {
        final email = (data['email'] as String? ?? '').trim().toLowerCase();
        if (email.isNotEmpty) {
          LinkService.autoLinkGuardianToPatients(
            guardianUid: uid,
            guardianEmail: email,
          ).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('[UserProvider] _syncRtdb error: $e');
    }
  }

  /// Loads manual_guardians from all available sources (SharedPreferences →
  /// Firestore → RTDB) and writes RTDB guardian_requests for each guardian
  /// email so guardians can discover this patient even when Firestore is empty.
  Future<void> _resolvePatientGuardians(
      String uid, Map<String, dynamic> rtdbData) async {
    try {
      // 1. SharedPreferences — always available, written by emergency setup screen.
      List<dynamic>? rawList;
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('manual_guardians_${uid}_v1');
      if (cached != null) {
        rawList = jsonDecode(cached) as List?;
      }

      // 2. Firestore fallback (for accounts that went through setup on another device).
      if (rawList == null || rawList.isEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('patients')
              .doc(uid)
              .get()
              .timeout(const Duration(seconds: 5));
          rawList = snap.data()?['manual_guardians'] as List?;
        } catch (_) {}
      }

      // 3. RTDB fallback.
      if (rawList == null || rawList.isEmpty) {
        rawList = rtdbData['manual_guardians'] as List?;
      }

      if (rawList == null || rawList.isEmpty) return;

      final patientName = rtdbData['name'] as String? ?? '';
      final guardians = rawList.map((g) {
        final m = Map<String, dynamic>.from(g as Map);
        return <String, dynamic>{
          'id':    m['id']    as String? ?? '',
          'name':  m['name']  as String? ?? 'Guardian',
          'email': (m['email'] as String? ?? '').trim().toLowerCase(),
          'phone': m['phone'] as String? ?? '',
          'uid':   m['uid']   as String? ?? '',
        };
      }).toList();

      // Write guardian_emails to Firestore so autoLinkGuardianToPatients can
      // find this patient via WHERE guardian_emails arrayContains email query.
      final emails = guardians
          .map((g) => g['email'] as String? ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (emails.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('patients')
            .doc(uid)
            .set({'guardian_emails': emails}, SetOptions(merge: true))
            .catchError((_) {});
      }

      // Best-effort RTDB guardian_requests (works when RTDB WebSocket is available).
      for (final g in guardians) {
        final email = g['email'] as String? ?? '';
        if (email.isNotEmpty) {
          RealtimeDatabaseService.saveGuardianRequest(
            guardianEmail: email,
            patientUid:    uid,
            patientName:   patientName,
          ).catchError((_) {});
        }
      }

      LinkService.saveGuardiansSnapshot(
        patientUid:  uid,
        guardians:   guardians,
        patientName: patientName,
      ).catchError((_) {});
    } catch (e) {
      debugPrint('[UserProvider] _resolvePatientGuardians error: $e');
    }
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>(
  (ref) => UserNotifier(),
);

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier() : super([]);

  static String _key(String uid) => 'emergency_contacts_${uid}_v1';

  /// Loads contacts from local cache only — no backend sync needed.
  /// Attendants are the alert recipients now, not a separate emergency contacts list.
  Future<void> loadFromStore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid));
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        state = list
            .map((j) => EmergencyContact.fromJson(
                Map<String, dynamic>.from(j as Map)))
            .toList();
      }
    } catch (_) {}
  }

  void add(EmergencyContact contact) => state = [...state, contact];

  void remove(String id) => state = state.where((c) => c.id != id).toList();

  void setPrimary(String id) {
    state = state
        .map((c) => EmergencyContact(
              id: c.id,
              userId: c.userId,
              name: c.name,
              phone: c.phone,
              relation: c.relation,
              isPrimary: c.id == id,
            ))
        .toList();
  }

  EmergencyContact? get primary =>
      state.where((c) => c.isPrimary).isNotEmpty
          ? state.firstWhere((c) => c.isPrimary)
          : state.isNotEmpty
              ? state.first
              : null;
}

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>(
  (ref) => EmergencyContactsNotifier(),
);
