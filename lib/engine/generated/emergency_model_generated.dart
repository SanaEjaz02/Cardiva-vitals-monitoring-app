// PLACEHOLDER — replace by running the conversion script:
//
//   1. Train model in Colab (fyp_dataset1.py) → download vitals_model.pkl
//   2. Place vitals_model.pkl in cardiva_ml_models/
//   3. cd cardiva_ml_models
//   4. pip install -r requirements.txt
//   5. python convert_to_dart.py
//
// Model   : GradientBoostingClassifier (fyp_dataset1.py)
// Classes : ['High Risk', 'Low Risk']
//
// Feature order (MUST match ml_service.dart):
//   [0] Heart Rate           — bpm
//   [1] HRV                  — ms (SDNN)
//   [2] Respiratory Rate     — breaths/min
//   [3] Oxygen Saturation    — % SpO2
//   [4] Age                  — years
//   [5] Height (m)
//   [6] Weight (kg)
//   [7] Gender               — 0=Male, 1=Female
//   [8] BMI                  — kg/m²
//
// Returns : 1.0 → High Risk  |  0.0 → Low Risk (normal / borderline)

// ignore_for_file: unused_local_variable

/// Placeholder — returns 1.0 only for values that are in a genuine clinical
/// emergency zone.  Borderline / warning cases are intentionally left as 0.0
/// so the WHO/AHA/ESC threshold check in ml_service.dart handles them without
/// double-firing an alert.  The 90.5 bpm dataset boundary from fyp_dataset1.py
/// was a synthetic ML training artifact, NOT a clinical threshold.
///
/// Replace with the real GBC model by running convert_to_dart.py.
double emergencyModelScore(List<dynamic> input) {
  final hr   = input.isNotEmpty  ? (input[0] as num).toDouble() : 72.0;
  final hrv  = input.length > 1  ? (input[1] as num).toDouble() : 55.0;
  final rr   = input.length > 2  ? (input[2] as num).toDouble() : 16.0;
  final spo2 = input.length > 3  ? (input[3] as num).toDouble() : 98.0;
  final age  = input.length > 4  ? (input[4] as num).toDouble() : 35.0;
  final bmi  = input.length > 8  ? (input[8] as num).toDouble() : 24.0;

  // ── Absolute emergencies (single vital in danger zone) ────────────────────
  if (spo2 < 90)            return 1.0;   // WHO: hypoxaemia
  if (hr > 150 || hr < 40)  return 1.0;   // Severe tachy/bradycardia
  if (rr > 30  || rr < 5)   return 1.0;   // Respiratory failure range
  if (hrv < 15)              return 1.0;   // Critically low HRV

  // ── Compound risk — elderly + multiple borderline vitals ──────────────────
  if (age >= 65 && spo2 < 92 && hr > 120) return 1.0;

  // ── Morbid obesity + cardiac stress ──────────────────────────────────────
  if (bmi >= 40 && (hr > 130 || spo2 < 91)) return 1.0;

  // Everything else (including HR 91–100 bpm which is clinically normal):
  // return 0.0 and let the threshold check decide.
  return 0.0;
}
