import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../models/user_profile.dart';

// ── Demo seed data (replaced by real Supabase auth in Phase 10) ─────────────
final _demoUser = UserProfile(
  id: 'demo-user-001',
  name: 'Demo User',
  email: 'demo@cardiva.app',
  phone: '+1234567890',
  dateOfBirth: DateTime(1990, 6, 15),
  gender: 'Not specified',
  bloodGroup: 'A+',
);

// ── User profile notifier ────────────────────────────────────────────────────
class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(_demoUser);

  void setUser(UserProfile profile) => state = profile;
  void clearUser() => state = null;
  void updateProfile(UserProfile updated) => state = updated;
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>(
  (ref) => UserNotifier(),
);

// ── Emergency contacts notifier ──────────────────────────────────────────────
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
