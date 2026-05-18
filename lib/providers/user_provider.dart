import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(null);

  void setUser(UserProfile profile) => state = profile;
  void clearUser() => state = null;
  void updateProfile(UserProfile updated) => state = updated;

  /// Loads the real profile on login: SharedPreferences first, Firestore fallback.
  /// Also syncs local data back to Firestore in case a previous save failed.
  Future<void> loadFromStore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_profile_$uid');
      if (raw != null) {
        final profile =
            UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        state = profile;
        // Heal: push local data to Firestore in case the initial save failed
        FirestoreService.saveProfile(profile.toJson()).catchError((_) {});
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

// Emergency contacts notifier (legacy in-memory — real data lives in SharedPreferences/Firestore)
class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier()
      : super([
          EmergencyContact(
            id: const Uuid().v4(),
            userId: 'demo-user-001',
            name: 'Sarah Demo',
            phone: '+0987654321',
            relation: 'Family',
            isPrimary: true,
          ),
        ]);

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
