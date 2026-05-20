import 'package:uuid/uuid.dart';

class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContact({
    String? id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  }) : id = id ?? const Uuid().v4();

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String? ?? const Uuid().v4(),
        // saved by setup screen as 'user_id' or omitted entirely
        userId: (json['user_id'] ?? json['userId'] ?? '') as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        // setup screen saves 'relationship'; older records use 'relation'
        relation: (json['relationship'] ?? json['relation'] ?? '') as String,
        isPrimary: json['is_primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'relation': relation,
        'is_primary': isPrimary,
      };
}
