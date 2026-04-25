class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String gender;
  final String bloodGroup;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
        gender: json['gender'] as String? ?? '',
        bloodGroup: json['blood_group'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'gender': gender,
        'blood_group': bloodGroup,
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        bloodGroup: bloodGroup ?? this.bloodGroup,
      );
}
