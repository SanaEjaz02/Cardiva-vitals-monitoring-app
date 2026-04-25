import '../models/vital_reading.dart';
import '../models/vital_status.dart';

class ConfidenceEngine {
  ConfidenceEngine._();

  static double calculate(List<VitalStatus> statuses, ActivityType activity) {
    // Step 1: sum points per status
    final rawScore = statuses.fold<double>(0, (sum, s) {
      switch (s) {
        case VitalStatus.emergency:
          return sum + 30;
        case VitalStatus.warning:
          return sum + 15;
        case VitalStatus.stable:
          return sum + 5;
        case VitalStatus.normal:
          return sum + 0;
      }
    });

    // Step 2: normalize to 0–100 (max raw = 120 for 4 vitals)
    double score = (rawScore / 120) * 100;

    // Step 3: activity context multiplier
    switch (activity) {
      case ActivityType.running:
        score *= 0.85;
        break;
      case ActivityType.walking:
        score *= 0.92;
        break;
      case ActivityType.resting:
      case ActivityType.lyingDown:
        break;
    }

    // Step 4: clamp to 0–100
    return score.clamp(0.0, 100.0);
  }
}
