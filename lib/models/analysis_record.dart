import 'ml_prediction.dart';

class AnalysisRecord {
  final String id;
  final DateTime timestamp;
  final MlPrediction prediction;
  final double heartRate;
  final double spo2;
  final double hrv;
  final double respirationRate;
  final String activity;      // ActivityType.name e.g. 'resting', 'walking'
  final bool fallDetected;

  const AnalysisRecord({
    required this.id,
    required this.timestamp,
    required this.prediction,
    required this.heartRate,
    required this.spo2,
    required this.hrv,
    required this.respirationRate,
    this.activity = 'resting',
    this.fallDetected = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'prediction': prediction.toJson(),
        'heartRate': heartRate,
        'spo2': spo2,
        'hrv': hrv,
        'respirationRate': respirationRate,
        'activity': activity,
        'fallDetected': fallDetected,
      };

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) => AnalysisRecord(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        prediction: MlPrediction.fromJson(
            json['prediction'] as Map<String, dynamic>),
        heartRate: (json['heartRate'] as num).toDouble(),
        spo2: (json['spo2'] as num).toDouble(),
        hrv: (json['hrv'] as num).toDouble(),
        respirationRate: (json['respirationRate'] as num).toDouble(),
        activity: json['activity'] as String? ?? 'resting',
        fallDetected: json['fallDetected'] as bool? ?? false,
      );
}
