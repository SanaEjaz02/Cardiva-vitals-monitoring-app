import 'vital.dart';

class AlertEvent {
  final String id;
  final String type; // fall | lowSpo2 | highHr | manual | noMotion
  final AlertSource source;
  AlertStatus status;
  final DateTime triggeredAt;
  final DateTime countdownEndsAt;
  final Map<String, double> location;
  final List<String> contactsNotified;
  final List<String> attendantsNotified;
  bool called1122;

  AlertEvent({
    required this.id,
    required this.type,
    required this.source,
    required this.status,
    required this.triggeredAt,
    required this.countdownEndsAt,
    required this.location,
    required this.contactsNotified,
    required this.attendantsNotified,
    this.called1122 = false,
  });

  String get displayType {
    switch (type) {
      case 'fall':
        return 'A fall has been detected.';
      case 'lowSpo2':
        return 'Critical vitals detected.';
      case 'highHr':
        return 'Critical vitals detected.';
      case 'manual':
        return 'SOS activated.';
      default:
        return 'Emergency detected.';
    }
  }
}
