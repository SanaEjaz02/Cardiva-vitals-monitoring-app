enum UserRole { patient, attendant }

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String gender;
  final String bloodGroup;
  final double heightCm;
  final double weightKg;
  final String? photoUrl;
  final UserRole role;
  // For attendants: the patient UID they are monitoring
  final String? monitoredPatientId;

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
    this.photoUrl,
    this.role = UserRole.patient,
    this.monitoredPatientId,
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
        photoUrl: json['photo_url'] as String?,
        role: json['role'] == 'attendant' ? UserRole.attendant : UserRole.patient,
        monitoredPatientId: json['monitored_patient_id'] as String?,
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
        if (photoUrl != null) 'photo_url': photoUrl,
        'role': role == UserRole.attendant ? 'attendant' : 'patient',
        if (monitoredPatientId != null)
          'monitored_patient_id': monitoredPatientId,
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
    String? photoUrl,
    bool clearPhotoUrl = false,
    UserRole? role,
    String? monitoredPatientId,
    bool clearMonitoredPatientId = false,
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
        photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
        role: role ?? this.role,
        monitoredPatientId: clearMonitoredPatientId
            ? null
            : (monitoredPatientId ?? this.monitoredPatientId),
      );
}
