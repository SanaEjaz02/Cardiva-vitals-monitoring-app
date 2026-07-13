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
  // Raw accelerometer values from the band (m/s²).
  // Normal resting: ax≈0, ay≈9.8 (gravity), az≈0.
  final double accelX;
  final double accelY;
  final double accelZ;

  VitalReading({
    String? id,
    DateTime? timestamp,
    required this.heartRate,
    required this.spO2,
    required this.hrv,
    required this.respirationRate,
    required this.activity,
    required this.fallDetected,
    this.accelX = 0.0,
    this.accelY = 9.8,
    this.accelZ = 0.0,
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
        accelX: (json['accel_x'] as num?)?.toDouble() ?? 0.0,
        accelY: (json['accel_y'] as num?)?.toDouble() ?? 9.8,
        accelZ: (json['accel_z'] as num?)?.toDouble() ?? 0.0,
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
        'accel_x': accelX,
        'accel_y': accelY,
        'accel_z': accelZ,
      };
}
