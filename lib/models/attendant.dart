class Attendant {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String? email;
  final bool notifyViaSms;
  final bool shareLocation;

  const Attendant({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.email,
    this.notifyViaSms = true,
    this.shareLocation = true,
  });

  Attendant copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? notifyViaSms,
    bool? shareLocation,
  }) =>
      Attendant(
        id: id,
        name: name ?? this.name,
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        notifyViaSms: notifyViaSms ?? this.notifyViaSms,
        shareLocation: shareLocation ?? this.shareLocation,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'notifyViaSms': notifyViaSms,
        'shareLocation': shareLocation,
      };

  factory Attendant.fromJson(Map<String, dynamic> j) => Attendant(
        id: j['id'] as String,
        name: j['name'] as String,
        relationship: j['relationship'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        notifyViaSms: j['notifyViaSms'] as bool? ?? true,
        shareLocation: j['shareLocation'] as bool? ?? true,
      );
}
