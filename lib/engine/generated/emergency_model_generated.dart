// PLACEHOLDER — run the conversion script to replace with your trained model:
//   cd cardiva_ml_models
//   pip install m2cgen scikit-learn numpy
//   python convert_to_dart.py
//
// Description : Vitals emergency / high-risk classifier
// Features    : [heart_rate, spo2, hrv, respiration_rate, weight_kg, height_m, bmi]
//
// Returns     : 1.0 → high-risk vitals detected
//               0.0 → normal vitals

// ignore_for_file: unused_local_variable

/// Predicts whether the patient's vitals indicate an emergency / high-risk state.
/// Input feature order MUST match training: [HR, SpO2, HRV, RR, weight_kg, height_m, BMI]
double emergencyModelScore(List<dynamic> input) {
  final hr   = input.isNotEmpty       ? (input[0] as num).toDouble() : 72.0;
  final spo2 = input.length > 1 ? (input[1] as num).toDouble() : 98.0;
  final hrv  = input.length > 2 ? (input[2] as num).toDouble() : 55.0;
  final rr   = input.length > 3 ? (input[3] as num).toDouble() : 16.0;
  final bmi  = input.length > 6 ? (input[6] as num).toDouble() : 24.0;

  // Emergency thresholds
  if (spo2 < 90 || hrv < 20 || hr > 150 || hr < 40 || rr > 30 || rr < 5) return 1.0;

  // Warning — BMI worsens risk
  final bmiHighRisk = bmi >= 35.0 || bmi < 16.0;
  if (spo2 < 95 || hrv < 35 || hr > 120 || hr < 55 || rr > 24 || rr < 8) {
    return bmiHighRisk ? 1.0 : 0.5;
  }

  return 0.0;
}
