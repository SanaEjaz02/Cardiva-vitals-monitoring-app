class HealthReport {
  final String id;
  final String name;
  final String dayKey; // "2026-05-13"
  final DateTime createdAt;
  final String? pdfUrl; // Firebase Storage download URL (null until first export)

  const HealthReport({
    required this.id,
    required this.name,
    required this.dayKey,
    required this.createdAt,
    this.pdfUrl,
  });

  HealthReport copyWith({String? name, String? pdfUrl}) => HealthReport(
        id: id,
        name: name ?? this.name,
        dayKey: dayKey,
        createdAt: createdAt,
        pdfUrl: pdfUrl ?? this.pdfUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dayKey': dayKey,
        'createdAt': createdAt.toIso8601String(),
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
      };

  factory HealthReport.fromJson(Map<String, dynamic> json) => HealthReport(
        id: json['id'] as String,
        name: json['name'] as String,
        dayKey: json['dayKey'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        pdfUrl: json['pdfUrl'] as String?,
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
