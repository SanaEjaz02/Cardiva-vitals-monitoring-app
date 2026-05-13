// PLACEHOLDER — run the conversion script to replace with your trained model:
//   cd cardiva_ml_models
//   pip install m2cgen scikit-learn numpy
//   python convert_to_dart.py
//
// Description : Fall detection classifier (vitals pattern)
// Features    : [heart_rate, spo2, hrv, respiration_rate, weight_kg, height_m, bmi]
//
// Returns     : 1.0 → fall predicted from vitals pattern
//               0.0 → no fall predicted
//
// Note: accelerometer magnitude heuristic is applied on top of this in MlService.

// ignore_for_file: unused_local_variable

/// Predicts fall risk from vitals pattern alone.
/// Accelerometer magnitude (>25 or <3 m/s²) is checked separately in MlService.
/// Input feature order MUST match training: [HR, SpO2, HRV, RR, weight_kg, height_m, BMI]
double fallModelScore(List<dynamic> input) {
  final hr  = input.isNotEmpty ? (input[0] as num).toDouble() : 72.0;
  final hrv = input.length > 2 ? (input[2] as num).toDouble() : 55.0;
  final bmi = input.length > 6 ? (input[6] as num).toDouble() : 24.0;

  // Sudden high HR + very low HRV is a known pre-fall pattern (esp. in elderly)
  if (hr > 130 && hrv < 20) return 1.0;

  // Obese + tachycardic — elevated fall risk
  if (bmi >= 35.0 && hr > 110) return 1.0;

  return 0.0;
}
