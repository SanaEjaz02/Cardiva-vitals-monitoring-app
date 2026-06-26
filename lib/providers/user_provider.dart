import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(null);

  void setUser(UserProfile profile) => state = profile;
  void clearUser() => state = null;
  void updateProfile(UserProfile updated) => state = updated;

  /// Loads the real profile on login: SharedPreferences first, Firestore fallback.
  /// Always clears stale state first so a different user's data is never shown.
  Future<void> loadFromStore() async {
    state = null; // clear any stale profile from the previous session
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_profile_$uid');
      if (raw != null) {
        // Use the cached profile immediately — no blocking Firestore call.
        // The role is already stored in the JSON. Refresh it in the background
        // in case the user changed roles on another device.
        state = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        FirestoreService.loadRole().then((r) {
          if (r != null) {
            final roleEnum =
                r == 'attendant' ? UserRole.attendant : UserRole.patient;
            state = state?.copyWith(role: roleEnum);
          }
        }).catchError((_) {});
        // Heal: push local data to Firestore in case the initial save failed
        FirestoreService.saveProfile(state!.toJson()).catchError((_) {});
        return;
      }
      // Not cached locally — pull from Firestore
      final profileJson = await FirestoreService.loadProfile();
      if (profileJson != null) {
        state = UserProfile.fromJson(profileJson);
        await prefs.setString('user_profile_$uid', jsonEncode(profileJson));
      }
    } catch (_) {}
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>(
  (ref) => UserNotifier(),
);

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier() : super([]);

  static String _key(String uid) => 'emergency_contacts_${uid}_v1';

  /// Loads contacts on login: SharedPreferences first, then Firestore fallback.
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
      // Always sync from Firestore
      final remote = await FirestoreService.loadEmergencyContacts();
      if (remote != null && remote.isNotEmpty) {
        state = remote
            .map((j) => EmergencyContact.fromJson(j))
            .toList();
        await prefs.setString(_key(uid), jsonEncode(remote));
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
