import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String uid;
  final String email;
  final String name;
  final String role; // 'patient' or 'attendant'

  const SavedAccount({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isGuardian => role == 'attendant';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() =>
      {'uid': uid, 'email': email, 'name': name, 'role': role};

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        uid: j['uid'] as String,
        email: j['email'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
      );
}

class AccountSwitcherService {
  AccountSwitcherService._();

  static const _key = 'saved_accounts_v1';

  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => SavedAccount.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsertAccount(SavedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    final updated = [
      ...accounts.where((a) => a.uid != account.uid),
      account,
    ];
    await prefs.setString(
        _key, jsonEncode(updated.map((a) => a.toJson()).toList()));
  }

  static Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    final updated = accounts.where((a) => a.uid != uid).toList();
    await prefs.setString(
        _key, jsonEncode(updated.map((a) => a.toJson()).toList()));
  }
}
