import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/vital_reading.dart';

class BleService {
  // UUIDs must match the ESP32 firmware exactly (sourced from BleManager.java)
  static const _svcUuid  = '12345678-1234-5678-1234-56789abcdef0';
  static const _charUuid = '12345678-1234-5678-1234-56789abcdef1';

  static const targetDeviceName = 'Cardiva-ESP32';

  final _controller = StreamController<VitalReading>.broadcast();
  StreamSubscription<List<int>>? _notifSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  BluetoothDevice? _device;
  bool _connected = false;

  Stream<VitalReading> get readingStream => _controller.stream;
  bool get isConnected => _connected;
  String get deviceName => _device?.platformName ?? targetDeviceName;

  /// Attaches to an already-connected [device] and enables BLE notifications.
  /// Throws [StateError] if the expected service/characteristic is not found.
  Future<void> attachDevice(BluetoothDevice device) async {
    await detach();
    _device = device;

    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _connected = false;
      }
    });

    final services = await device.discoverServices();

    // Log every UUID so any mismatch is immediately visible in debug output
    debugPrint('[BLE] Discovered ${services.length} service(s):');
    for (final svc in services) {
      debugPrint('[BLE]  svc: ${svc.uuid}');
      for (final c in svc.characteristics) {
        debugPrint('[BLE]    char: ${c.uuid}');
      }
    }
    debugPrint('[BLE] Looking for svc=$_svcUuid  char=$_charUuid');

    BluetoothCharacteristic? char;
    for (final svc in services) {
      if (_norm(svc.uuid.toString()) == _svcUuid) {
        for (final c in svc.characteristics) {
          if (_norm(c.uuid.toString()) == _charUuid) {
            char = c;
            break;
          }
        }
      }
    }

    if (char == null) {
      _connected = false;
      throw StateError(
        'Vitals characteristic not found.\n'
        'Expected svc: $_svcUuid\n'
        'Expected char: $_charUuid\n'
        'Check the debug log for what the device actually advertises.',
      );
    }

    await char.setNotifyValue(true);
    _notifSub = char.onValueReceived.listen((bytes) {
      final reading = _parse(bytes);
      if (reading != null) _controller.add(reading);
    });

    _connected = true;
    debugPrint('[BLE] Notifications enabled. Streaming vitals...');
  }

  // Strip braces/whitespace and lowercase — handles flutter_blue_plus
  // returning UUIDs as "{uuid}" on some Android versions.
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

  // JSON shape: { "hr": 78.0, "spo2": 97.5, "hrv": 42.3, "rr": 16.0, "act": "Walking", "fall": false }
  VitalReading? _parse(List<int> bytes) {
    try {
      final raw = utf8.decode(bytes);
      debugPrint('[BLE] Packet: $raw');
      final map = json.decode(raw) as Map<String, dynamic>;

      final hr   = (map['hr']   as num?)?.toDouble() ?? 0;
      final spo2 = (map['spo2'] as num?)?.toDouble() ?? 0;

      final actStr = (map['act'] as String? ?? '').toLowerCase();
      final activity = actStr == 'walking'
          ? ActivityType.walking
          : actStr == 'active'
              ? ActivityType.running
              : ActivityType.resting;

      return VitalReading(
        heartRate:       hr,
        spO2:            spo2,
        hrv:             (map['hrv'] as num?)?.toDouble() ?? 0,
        respirationRate: (map['rr']  as num?)?.toDouble() ?? 0,
        activity:        activity,
        fallDetected:    map['fall'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[BLE] Parse error: $e');
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

  /// Push a synthetic reading directly into the stream (for debug/testing only).
  void injectReading(VitalReading reading) => _controller.add(reading);

  void dispose() {
    detach();
    _controller.close();
  }
}
