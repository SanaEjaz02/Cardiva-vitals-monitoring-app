import '../models/emergency_contact.dart';
import '../models/health_event.dart';
import '../models/vital_reading.dart';

/// Stub CloudService — all operations are no-ops during development.
/// Replace method bodies with real Supabase calls once credentials are wired in.
class CloudService {
  Future<void> saveVitalReading(VitalReading reading, String userId) async {}

  Future<void> saveHealthEvent(HealthEvent event, String userId) async {}

  Future<void> saveAlert(
    String userId,
    String alertMessage,
    String alertType,
    double lat,
    double lng,
  ) async {}

  Future<List<VitalReading>> fetchRecentReadings(String userId,
      {int limit = 50}) async => [];

  Future<List<HealthEvent>> fetchHealthHistory(String userId,
      {int limit = 50}) async => [];

  Future<List<EmergencyContact>> fetchEmergencyContacts(String userId) async =>
      [];

  Future<void> saveEmergencyContact(EmergencyContact contact) async {}
}
