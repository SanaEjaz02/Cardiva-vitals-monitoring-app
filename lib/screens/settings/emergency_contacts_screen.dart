import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<_Contact> _contacts = [];
  bool _loading = true;

  String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'emergency_contacts_${uid}_v1';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      if (mounted) {
        setState(() {
          _contacts = list
              .map((j) => _Contact.fromJson(j as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } else {
      // Nothing local — try Firestore
      try {
        final remote = await FirestoreService.loadEmergencyContacts();
        if (remote != null && remote.isNotEmpty) {
          final contacts =
              remote.map((j) => _Contact.fromJson(j)).toList();
          // Cache locally
          final prefs2 = await SharedPreferences.getInstance();
          await prefs2.setString(
              _storageKey,
              jsonEncode(contacts.map((c) => c.toJson()).toList()));
          if (mounted) setState(() => _contacts = contacts);
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final json = jsonEncode(_contacts.map((c) => c.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json);
    // Sync to Firestore in the background
    FirestoreService.saveEmergencyContacts(
            _contacts.map((c) => c.toJson()).toList())
        .catchError((_) {});
  }

  void _delete(_Contact c) {
    setState(() => _contacts.removeWhere((x) => x.id == c.id));
    _save();
  }

  void _showForm({_Contact? editing}) {
    final nameCtrl =
        TextEditingController(text: editing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: editing?.phone ?? '');
    String relationship = editing?.relationship ?? 'Family';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(
            editing == null ? 'Add Contact' : 'Edit Contact',
            style: AppTextStyles.h2,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: AppColors.textSecondary),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined,
                        color: AppColors.textSecondary),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                  ),
                  items: ['Family', 'Friend', 'Doctor', 'Colleague', 'Other']
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: AppTextStyles.body),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setS(() => relationship = v ?? relationship),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (editing != null) {
                  final idx =
                      _contacts.indexWhere((x) => x.id == editing.id);
                  if (idx >= 0) {
                    setState(() => _contacts[idx] = _Contact(
                        id: editing.id,
                        name: name,
                        phone: phone,
                        relationship: relationship));
                  }
                } else {
                  setState(() => _contacts.add(_Contact(
                      id: const Uuid().v4(),
                      name: name,
                      phone: phone,
                      relationship: relationship)));
                }
                _save();
                Navigator.pop(ctx);
              },
              child: Text(
                'Save',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Emergency Contacts', style: AppTextStyles.h1),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 26),
            tooltip: 'Add contact',
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.contacts_outlined,
                          size: 64, color: AppColors.accentTint),
                      const SizedBox(height: 12),
                      Text('No emergency contacts added',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showForm(),
                        child: Text(
                          'Add First Contact',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        'Swipe left to remove  ·  tap to edit',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final c = _contacts[i];
                          return Dismissible(
                            key: Key(c.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22),
                            ),
                            onDismissed: (_) => _delete(c),
                            child: GestureDetector(
                              onTap: () => _showForm(editing: c),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.bgWhite,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: AppColors.shadowSm,
                                        blurRadius: 12,
                                        offset: Offset(0, 2))
                                  ],
                                  border: const Border(
                                    left: BorderSide(
                                        color: AppColors.danger,
                                        width: 4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          AppColors.dangerBg,
                                      child: Text(
                                        c.name[0].toUpperCase(),
                                        style: AppTextStyles.h2
                                            .copyWith(
                                                color:
                                                    AppColors.danger),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: AppTextStyles.body
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight
                                                            .w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c.phone}  ·  ${c.relationship}',
                                            style:
                                                AppTextStyles.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              backgroundColor: AppColors.danger,
              icon: const Icon(Icons.person_add_outlined,
                  color: Colors.white),
              label: Text(
                'Add Contact',
                style: AppTextStyles.body.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────────

class _Contact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  const _Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  factory _Contact.fromJson(Map<String, dynamic> j) => _Contact(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        relationship: j['relationship'] as String,
      );
}
