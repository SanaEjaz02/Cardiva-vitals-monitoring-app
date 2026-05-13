import 'ml_prediction.dart';

class AnalysisRecord {
  final String id;
  final DateTime timestamp;
  final MlPrediction prediction;
  final double heartRate;
  final double spo2;
  final double hrv;
  final double respirationRate;

  const AnalysisRecord({
    required this.id,
    required this.timestamp,
    required this.prediction,
    required this.heartRate,
    required this.spo2,
    required this.hrv,
    required this.respirationRate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'prediction': prediction.toJson(),
        'heartRate': heartRate,
        'spo2': spo2,
        'hrv': hrv,
        'respirationRate': respirationRate,
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
      );
}
