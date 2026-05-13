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
}
