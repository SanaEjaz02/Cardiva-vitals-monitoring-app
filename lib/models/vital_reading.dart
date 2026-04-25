import 'package:uuid/uuid.dart';

enum ActivityType { resting, walking, running, lyingDown }

class VitalReading {
  final String id;
  final DateTime timestamp;
  final double heartRate;
  final double spO2;
  final double hrv;
  final double respirationRate;
  final ActivityType activity;
  final bool fallDetected;

  VitalReading({
    String? id,
    DateTime? timestamp,
    required this.heartRate,
    required this.spO2,
    required this.hrv,
    required this.respirationRate,
    required this.activity,
    required this.fallDetected,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory VitalReading.fromJson(Map<String, dynamic> json) => VitalReading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['recorded_at'] as String),
        heartRate: (json['heart_rate'] as num).toDouble(),
        spO2: (json['spo2'] as num).toDouble(),
        hrv: (json['hrv'] as num).toDouble(),
        respirationRate: (json['respiration_rate'] as num).toDouble(),
        activity: ActivityType.values.firstWhere(
          (e) => e.name == json['activity'],
          orElse: () => ActivityType.resting,
        ),
        fallDetected: json['fall_detected'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recorded_at': timestamp.toIso8601String(),
        'heart_rate': heartRate,
        'spo2': spO2,
        'hrv': hrv,
        'respiration_rate': respirationRate,
        'activity': activity.name,
        'fall_detected': fallDetected,
      };
}
