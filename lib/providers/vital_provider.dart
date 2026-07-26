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
  svc.onConnectionChanged = (connected) {
    ref.read(bleConnectedProvider.notifier).state = connected;
  };
  ref.onDispose(svc.dispose);
  return svc;
});

// true when BLE device is attached and notifications are active
final bleConnectedProvider = StateProvider<bool>((ref) => false);

// ── Live vital stream — only emits once a real band is connected ─────────────
final latestReadingProvider = StreamProvider<VitalReading>((ref) {
  final bleConnected = ref.watch(bleConnectedProvider);
  if (bleConnected) {
    return ref.watch(bleServiceProvider).readingStream;
  }
  // No band connected — stay idle (AsyncLoading) until one is.
  return const Stream<VitalReading>.empty();
});

// ── Derived health event ─────────────────────────────────────────────────────
final healthEventProvider = Provider<AsyncValue<HealthEvent>>((ref) {
  return ref.watch(latestReadingProvider).whenData((reading) {
    final user = ref.read(userProvider);
    final gender = (user?.gender ?? 'male').toLowerCase();

    // Rule-based classification with gender-adjusted WHO/AHA/ESC thresholds
    final event = HealthStatusEngine.analyze(reading, gender: gender);

    // Side-effects — all fire-and-forget; never block UI
    final userId = user?.id ?? 'demo-user-001';
    final cloud = ref.read(cloudServiceProvider);

    cloud.saveVitalReading(reading, userId).catchError((_) {});
    cloud.saveHealthEvent(event, userId).catchError((_) {});

    // Class 1 (emergency) and Class 2 (fall alert): immediate contact notification
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
