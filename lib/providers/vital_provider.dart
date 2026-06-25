import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/emergency_trigger.dart';
import '../engine/health_status_engine.dart';
import '../models/alert_class.dart';
import '../models/health_event.dart';
import '../models/vital_reading.dart';
import '../services/ble_service.dart';
import '../services/cloud_service.dart';
import 'user_provider.dart';

// ── Service singletons ───────────────────────────────────────────────────────

final cloudServiceProvider = Provider<CloudService>((ref) => CloudService());

final bleServiceProvider = Provider<BleService>((ref) {
  final svc = BleService();
  ref.onDispose(svc.dispose);
  return svc;
});

// true when BLE device is attached and notifications are active
final bleConnectedProvider = StateProvider<bool>((ref) => false);

// ── Live vital stream — ALWAYS from the real hardware sensor ─────────────────
final latestReadingProvider = StreamProvider<VitalReading>((ref) {
  return ref.watch(bleServiceProvider).readingStream;
});

// ── Derived health event ─────────────────────────────────────────────────────
final healthEventProvider = Provider<AsyncValue<HealthEvent>>((ref) {
  return ref.watch(latestReadingProvider).whenData((reading) {
    final event = HealthStatusEngine.analyze(reading);

    // Side-effects — all fire-and-forget; never block UI
    final user = ref.read(userProvider);
    final userId = user?.id ?? 'demo-user-001';
    final cloud = ref.read(cloudServiceProvider);

    cloud.saveVitalReading(reading, userId).catchError((_) {});
    cloud.saveHealthEvent(event, userId).catchError((_) {});

    // Class 1 (emergency) and Class 2 (fall alert) both require immediate
    // contact notification — vitalsAlert (Class 3) is handled separately
    // via the result screen where the user confirms before sending.
    if (event.alertClass.requiresAction) {
      EmergencyTrigger.handle(
        event: event,
        userName: user?.name ?? 'Patient',
        userPhone: user?.phone ?? '',
        userId: userId,
      ).catchError((_) {});
    }

    return event;
  });
});
