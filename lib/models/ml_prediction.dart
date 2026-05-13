import 'alert_class.dart';

class MlPrediction {
  final bool isEmergency;
  final bool fallDetected;
  final bool vitalsHighRisk;
  final double confidenceScore;
  final AlertClass alertClass;
  final String analysisMessage;

  const MlPrediction({
    required this.isEmergency,
    required this.fallDetected,
    required this.vitalsHighRisk,
    required this.confidenceScore,
    required this.alertClass,
    required this.analysisMessage,
  });

  factory MlPrediction.fromJson(Map<String, dynamic> json) {
    final classNum = json['alert_class'] as int? ?? 4;
    return MlPrediction(
      isEmergency: json['is_emergency'] as bool? ?? false,
      fallDetected: json['fall_detected'] as bool? ?? false,
      vitalsHighRisk: json['vitals_high_risk'] as bool? ?? false,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0,
      alertClass: _classFromInt(classNum),
      analysisMessage: json['analysis_message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_emergency': isEmergency,
        'fall_detected': fallDetected,
        'vitals_high_risk': vitalsHighRisk,
        'confidence_score': confidenceScore,
        'alert_class': alertClass.classNumber,
        'analysis_message': analysisMessage,
      };

  static AlertClass _classFromInt(int n) => switch (n) {
        1 => AlertClass.emergency,
        2 => AlertClass.fallAlert,
        3 => AlertClass.vitalsAlert,
        _ => AlertClass.normal,
      };
}
