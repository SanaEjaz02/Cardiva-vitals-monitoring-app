import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/emergency_trigger.dart';
import '../engine/health_status_engine.dart';
import '../models/health_event.dart';
import '../models/vital_reading.dart';
import '../services/cloud_service.dart';
import '../services/mock_data_service.dart';
import 'user_provider.dart';

// ── Service singletons ───────────────────────────────────────────────────────

final mockDataServiceProvider = Provider<MockDataService>((ref) {
  final svc = MockDataService();
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});

final cloudServiceProvider = Provider<CloudService>((ref) => CloudService());

// ── Live vital stream ────────────────────────────────────────────────────────
// Switch this one provider to BleService when hardware is ready.
final latestReadingProvider = StreamProvider<VitalReading>((ref) {
  return ref.watch(mockDataServiceProvider).stream;
});

// ── Derived health event ─────────────────────────────────────────────────────
final healthEventProvider = Provider<AsyncValue<HealthEvent>>((ref) {
  return ref.watch(latestReadingProvider).whenData((reading) {
    final event = HealthStatusEngine.analyze(reading);

    // Side-effects — all fire-and-forget; never block UI
    final user = ref.read(userProvider);
    final contacts = ref.read(emergencyContactsProvider);
    final userId = user?.id ?? 'demo-user-001';
    final cloud = ref.read(cloudServiceProvider);

    cloud.saveVitalReading(reading, userId).catchError((_) {});
    cloud.saveHealthEvent(event, userId).catchError((_) {});

    if (event.isEmergency) {
      final primary = ref.read(emergencyContactsProvider.notifier).primary;
      EmergencyTrigger.handle(
        event: event,
        userName: user?.name ?? 'Patient',
        userPhone: user?.phone ?? '',
        contactPhone: primary?.phone ?? contacts.firstOrNull?.phone ?? '',
        userId: userId,
      ).catchError((_) {});
    }

    return event;
  });
});
