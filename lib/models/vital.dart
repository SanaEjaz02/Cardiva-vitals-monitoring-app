import '../theme/app_colors.dart';

enum VitalKind {
  heartRate,
  spo2,
  hrv,
  respiration,
  activity,
  fallDetection,
}

enum AlertSource { auto, manual }

enum AlertStatus { pending, sent, cancelled, falseAlarm }

class Vital {
  final VitalKind kind;
  final dynamic value;
  final String unit;
  final VitalDisplayStatus status;
  final List<double> history;
  final DateTime updatedAt;

  const Vital({
    required this.kind,
    required this.value,
    required this.unit,
    required this.status,
    required this.history,
    required this.updatedAt,
  });

  String get displayName {
    switch (kind) {
      case VitalKind.heartRate:
        return 'Heart Rate';
      case VitalKind.spo2:
        return 'SpO₂';
      case VitalKind.hrv:
        return 'HRV';
      case VitalKind.respiration:
        return 'Respiration';
      case VitalKind.activity:
        return 'Activity';
      case VitalKind.fallDetection:
        return 'Fall Detection';
    }
  }

  String get routeId {
    switch (kind) {
      case VitalKind.heartRate:
        return 'heartRate';
      case VitalKind.spo2:
        return 'spo2';
      case VitalKind.hrv:
        return 'hrv';
      case VitalKind.respiration:
        return 'respiration';
      case VitalKind.activity:
        return 'activity';
      case VitalKind.fallDetection:
        return 'fallDetection';
    }
  }

  double get percent {
    switch (kind) {
      case VitalKind.heartRate:
        final v = value is num ? (value as num).toDouble() : 72.0;
        return ((v - 40) / (180 - 40)).clamp(0.0, 1.0);
      case VitalKind.spo2:
        final v = value is num ? (value as num).toDouble() : 98.0;
        return ((v - 85) / 15).clamp(0.0, 1.0);
      case VitalKind.hrv:
        final v = value is num ? (value as num).toDouble() : 45.0;
        return (v / 100).clamp(0.0, 1.0);
      case VitalKind.respiration:
        final v = value is num ? (value as num).toDouble() : 16.0;
        return ((v - 8) / (30 - 8)).clamp(0.0, 1.0);
      case VitalKind.activity:
        return 0.65;
      case VitalKind.fallDetection:
        return 1.0;
    }
  }
}
