// All vital threshold constants — never hardcode these values elsewhere.
import '../../models/vital_reading.dart';

class VitalThresholds {
  VitalThresholds._();

  // Heart Rate thresholds keyed by ActivityType name
  static const Map<String, Map<String, double>> heartRate = {
    'resting': {
      'emergencyLow': 40,
      'warningLow': 50,
      'stableLow': 55,
      'normalLow': 60,
      'normalHigh': 100,
      'stableHigh': 105,
      'warningHigh': 120,
      'emergencyHigh': 150,
    },
    'walking': {
      'emergencyLow': 45,
      'warningLow': 55,
      'normalLow': 65,
      'normalHigh': 130,
      'warningHigh': 155,
      'emergencyHigh': 175,
    },
    'running': {
      'emergencyLow': 50,
      'warningLow': 60,
      'normalLow': 80,
      'normalHigh': 180,
      'warningHigh': 200,
      'emergencyHigh': 220,
    },
    'lyingDown': {
      'emergencyLow': 35,
      'warningLow': 45,
      'normalLow': 55,
      'normalHigh': 90,
      'warningHigh': 110,
      'emergencyHigh': 140,
    },
  };

  // SpO2 thresholds (not activity-adjusted)
  static const double spo2Normal = 95;
  static const double spo2StableLow = 93;
  static const double spo2WarningLow = 90;
  // Below spo2WarningLow = emergency

  // HRV (SDNN) thresholds (not activity-adjusted)
  static const double hrvNormal = 50;
  static const double hrvStableLow = 35;
  static const double hrvWarningLow = 20;
  // Below hrvWarningLow = emergency

  // Respiration Rate thresholds
  static const double rrEmergencyLow = 5;
  static const double rrWarningLow = 8;
  static const double rrNormalLow = 12;
  static const double rrNormalHigh = 20;
  static const double rrWarningHigh = 25;
  static const double rrEmergencyHigh = 30;

  // Confidence score gate for emergency decision
  static const double emergencyConfidenceGate = 70.0;

  static Map<String, double> hrThresholdsFor(ActivityType activity) {
    return heartRate[activity.name] ?? heartRate['resting']!;
  }
}
