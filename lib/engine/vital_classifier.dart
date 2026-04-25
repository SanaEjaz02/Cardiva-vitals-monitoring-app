import '../core/constants/thresholds.dart';
import '../models/vital_reading.dart';
import '../models/vital_status.dart';

class VitalClassifier {
  VitalClassifier._();

  static VitalStatus classifyHeartRate(double hr, ActivityType activity) {
    final t = VitalThresholds.hrThresholdsFor(activity);
    if (hr <= t['emergencyLow']! || hr >= t['emergencyHigh']!) {
      return VitalStatus.emergency;
    }
    if (hr <= t['warningLow']! || hr >= t['warningHigh']!) {
      return VitalStatus.warning;
    }
    if (t.containsKey('stableLow') && hr <= t['stableLow']!) {
      return VitalStatus.stable;
    }
    if (t.containsKey('stableHigh') && hr >= t['stableHigh']!) {
      return VitalStatus.stable;
    }
    return VitalStatus.normal;
  }

  static VitalStatus classifySpO2(double spo2) {
    if (spo2 < VitalThresholds.spo2WarningLow) return VitalStatus.emergency;
    if (spo2 < VitalThresholds.spo2StableLow) return VitalStatus.warning;
    if (spo2 < VitalThresholds.spo2Normal) return VitalStatus.stable;
    return VitalStatus.normal;
  }

  static VitalStatus classifyHRV(double hrv) {
    if (hrv < VitalThresholds.hrvWarningLow) return VitalStatus.emergency;
    if (hrv < VitalThresholds.hrvStableLow) return VitalStatus.warning;
    if (hrv <= VitalThresholds.hrvNormal) return VitalStatus.stable;
    return VitalStatus.normal;
  }

  static VitalStatus classifyRespirationRate(double rr) {
    if (rr < VitalThresholds.rrEmergencyLow || rr > VitalThresholds.rrEmergencyHigh) {
      return VitalStatus.emergency;
    }
    if (rr < VitalThresholds.rrWarningLow || rr > VitalThresholds.rrWarningHigh) {
      return VitalStatus.warning;
    }
    if (rr < VitalThresholds.rrNormalLow || rr > VitalThresholds.rrNormalHigh) {
      return VitalStatus.stable;
    }
    return VitalStatus.normal;
  }
}
