// Placeholder for future accelerometer-based activity classification.
// Currently activity is reported directly by the wearable / mock service.
import '../models/vital_reading.dart';

class ActivityClassifier {
  ActivityClassifier._();

  // Future: derive ActivityType from raw accelerometer magnitude values.
  static ActivityType classify(double accelerometerMagnitude) {
    if (accelerometerMagnitude > 2.5) return ActivityType.running;
    if (accelerometerMagnitude > 1.2) return ActivityType.walking;
    return ActivityType.resting;
  }
}
