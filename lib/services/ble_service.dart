import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/vital_reading.dart';

class BleService {
  static const _svcUuid  = '12345678-1234-1234-1234-123456789012';
  static const _charUuid = '87654321-4321-4321-4321-210987654321';

  final _controller = StreamController<VitalReading>.broadcast();
  StreamSubscription<List<int>>? _notifSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  BluetoothDevice? _device;
  bool _connected = false;

  Stream<VitalReading> get readingStream => _controller.stream;
  bool get isConnected => _connected;
  String get deviceName => _device?.platformName ?? 'Cardiva Band';

  Future<void> attachDevice(BluetoothDevice device) async {
    await detach();
    _device = device;

    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _connected = false;
      }
    });

    final services = await device.discoverServices();
    BluetoothCharacteristic? char;
    for (final svc in services) {
      if (svc.uuid.toString().toLowerCase() == _svcUuid) {
        for (final c in svc.characteristics) {
          if (c.uuid.toString().toLowerCase() == _charUuid) {
            char = c;
            break;
          }
        }
      }
    }

    if (char == null) {
      _connected = false;
      return;
    }

    await char.setNotifyValue(true);
    _notifSub = char.onValueReceived.listen((bytes) {
      final reading = _parse(bytes);
      if (reading != null) _controller.add(reading);
    });

    _connected = true;
  }

  VitalReading? _parse(List<int> bytes) {
    try {
      final raw = utf8.decode(bytes);
      final map = json.decode(raw) as Map<String, dynamic>;

      final heart = (map['heart'] as num?)?.toInt() ?? 0;
      final spo2  = (map['spo2']  as num?)?.toInt() ?? 0;

      if (heart == 0 && spo2 == 0) return null;

      final actStr = (map['activity'] as String? ?? '').toUpperCase();
      final activity = actStr == 'WALK'
          ? ActivityType.walking
          : actStr == 'RUN'
              ? ActivityType.running
              : ActivityType.resting;

      return VitalReading(
        heartRate:       heart.toDouble(),
        spO2:            spo2.toDouble(),
        hrv:             (map['hrv_sdnn'] as num?)?.toDouble() ?? 0,
        respirationRate: (map['resp'] as num?)?.toDouble() ?? 0,
        activity:        activity,
        fallDetected:    map['fall'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> detach() async {
    _connected = false;
    await _notifSub?.cancel();
    _notifSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    _device = null;
  }

  void dispose() {
    detach();
    _controller.close();
  }
}
