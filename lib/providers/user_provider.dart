import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

final _demoUser = UserProfile(
  id: 'demo-user-001',
  name: 'Demo User',
  email: 'demo@cardiva.app',
  phone: '+1234567890',
  dateOfBirth: DateTime(1990, 6, 15),
  gender: 'Male',
  bloodGroup: 'A+',
  heightCm: 170.0,
  weightKg: 70.0,
);

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(_demoUser);

  void setUser(UserProfile profile) => state = profile;
  void clearUser() => state = null;
  void updateProfile(UserProfile updated) => state = updated;

  /// Loads the real profile on login: SharedPreferences first, Firestore fallback.
  Future<void> loadFromStore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_profile_$uid');
      if (raw != null) {
        state = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return;
      }
      // Not cached locally — pull from Firestore
      final profileJson = await FirestoreService.loadProfile();
      if (profileJson != null) {
        state = UserProfile.fromJson(profileJson);
        // Cache locally for next launch
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
