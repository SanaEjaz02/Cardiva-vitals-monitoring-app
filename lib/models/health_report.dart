class HealthReport {
  final String id;
  final String name;
  final String dayKey; // "2026-05-13"
  final DateTime createdAt;

  const HealthReport({
    required this.id,
    required this.name,
    required this.dayKey,
    required this.createdAt,
  });

  HealthReport copyWith({String? name}) => HealthReport(
        id: id,
        name: name ?? this.name,
        dayKey: dayKey,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dayKey': dayKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HealthReport.fromJson(Map<String, dynamic> json) => HealthReport(
        id: json['id'] as String,
        name: json['name'] as String,
        dayKey: json['dayKey'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String defaultName(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Health Report — ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
