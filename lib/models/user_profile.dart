class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String gender;
  final String bloodGroup;
  final double heightCm;  // centimetres
  final double weightKg;  // kilograms

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    this.heightCm = 170.0,
    this.weightKg = 70.0,
  });

  // Computed
  double get heightM => heightCm / 100.0;
  double get bmi => heightM > 0 ? weightKg / (heightM * heightM) : 25.0;
  int get age {
    final now = DateTime.now();
    int a = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      a--;
    }
    return a;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
        gender: json['gender'] as String? ?? '',
        bloodGroup: json['blood_group'] as String? ?? '',
        heightCm: (json['height_cm'] as num?)?.toDouble() ?? 170.0,
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 70.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'gender': gender,
        'blood_group': bloodGroup,
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
      );
}
