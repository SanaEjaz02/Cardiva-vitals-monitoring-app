import 'dart:async';
import 'dart:convert' show utf8;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vital_reading.dart';

class BleService {
  // UUIDs match ESP32 firmware (BLEDevice::init("Cardiva"), SERVICE_UUID, VITALS_CHAR_UUID)
  static const _svcUuid  = '12345678-1234-5678-1234-56789abcdef0';
  static const _charUuid = '12345678-1234-5678-1234-56789abcdef1';

  static const targetDeviceName = 'Cardiva';

  final _controller = StreamController<VitalReading>.broadcast();
  StreamSubscription<List<int>>? _notifSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  BluetoothDevice? _device;
  bool _connected = false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  // Median-of-5 filter on raw heart rate: the MAX30100's beat-detection
  // hasn't locked onto a stable signal for the first second or two after
  // finger contact, producing spurious spikes. A median rejects a single
  // bad sample without lagging behind genuine sustained changes.
  final List<double> _hrWindow = [];
  static const _hrWindowSize = 5;

  double _smoothedHr(double raw) {
    _hrWindow.add(raw);
    if (_hrWindow.length > _hrWindowSize) _hrWindow.removeAt(0);
    final sorted = [..._hrWindow]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Fired whenever the internal connection state changes.
  /// Wire this up in vital_provider.dart to keep bleConnectedProvider in sync.
  Function(bool)? onConnectionChanged;

  Stream<VitalReading> get readingStream => _controller.stream;
  bool get isConnected => _connected;
  String get deviceName => _device?.platformName ?? targetDeviceName;

  /// Attaches to an already-connected [device] and enables BLE notifications.
  /// Throws [StateError] if the expected service/characteristic is not found.
  Future<void> attachDevice(BluetoothDevice device) async {
    await _cleanup();   // cancel subs only — preserves reconnect timer if running
    _device = device;
    _reconnectAttempts = 0;

    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _connected = false;
        onConnectionChanged?.call(false);
        _scheduleReconnect(device);
      } else if (s == BluetoothConnectionState.connected) {
        _connected = true;
        onConnectionChanged?.call(true);
      }
    });

    // Android needs a moment after GATT connection before services are stable.
    await Future.delayed(const Duration(milliseconds: 600));

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
    onConnectionChanged?.call(true);
    debugPrint('[BLE] Notifications enabled. Streaming vitals...');
  }

  /// Try to reconnect to the device that was last used.
  /// Loads device ID from SharedPreferences, scans briefly, then connects.
  /// Safe to call at any time — returns early if already connected or no saved device.
  Future<void> reconnectFromPrefs() async {
    if (_connected) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('ble_device_id');
      if (savedId == null || savedId.isEmpty) return;

      debugPrint('[BLE] Auto-reconnect: looking for $savedId');

      // Check system/bonded devices first — no scan needed
      BluetoothDevice? target;
      try {
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        for (final d in systemDevices) {
          if (d.remoteId.toString() == savedId) {
            target = d;
            break;
          }
        }
      } catch (_) {}

      // Fall back to a scan if not found in system list
      if (target == null) {
        debugPrint('[BLE] Not in system list, starting scan...');
        final completer = Completer<BluetoothDevice?>();
        StreamSubscription? scanSub;

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 8),
        );
        scanSub = FlutterBluePlus.onScanResults.listen((results) {
          for (final r in results) {
            if (r.device.remoteId.toString() == savedId &&
                !completer.isCompleted) {
              completer.complete(r.device);
            }
          }
        });

        target = await completer.future.timeout(
          const Duration(seconds: 9),
          onTimeout: () => null,
        );
        await scanSub.cancel();
        await FlutterBluePlus.stopScan();
      }

      if (target == null) {
        debugPrint('[BLE] Auto-reconnect: device not found');
        return;
      }

      debugPrint('[BLE] Auto-reconnect: found device, connecting...');
      await target.connect(timeout: const Duration(seconds: 12));
      await attachDevice(target);
      debugPrint('[BLE] Auto-reconnect: success');
    } catch (e) {
      debugPrint('[BLE] Auto-reconnect failed: $e');
    }
  }

  // Schedules a retry after a connection drop within a live session.
  void _scheduleReconnect(BluetoothDevice device) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[BLE] Max reconnect attempts reached, giving up.');
      _reconnectAttempts = 0;
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 8), () async {
      if (_connected) {
        _reconnectAttempts = 0;
        return;
      }
      _reconnectAttempts++;
      debugPrint(
          '[BLE] Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts...');
      try {
        await device.connect(timeout: const Duration(seconds: 12));
        await attachDevice(device);
        _reconnectAttempts = 0;
        debugPrint('[BLE] In-session reconnect success');
      } catch (e) {
        debugPrint('[BLE] In-session reconnect failed: $e');
        _scheduleReconnect(device);
      }
    });
  }

  // Strip braces/whitespace and lowercase — handles flutter_blue_plus
  // returning UUIDs as "{uuid}" on some Android versions.
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

  // Firmware CSV format — two supported variants:
  //   4-field: "HR,SpO2,HRV,Resp"
  //   8-field: "HR,SpO2,HRV,Resp,AcX,AcY,AcZ,Activity"
  // AcX/Y/Z (if present) are in g-units → converted to m/s² (* 9.81).
  // Activity (if present): STILL | MOVING | FALL
  VitalReading? _parse(List<int> bytes) {
    try {
      final raw = utf8.decode(bytes).trim();
      debugPrint('[BLE] Packet: $raw');
      final fields = raw.split(',');
      if (fields.length < 4) {
        debugPrint('[BLE] Bad CSV (expected ≥4 fields, got ${fields.length})');
        return null;
      }

      final hr   = _smoothedHr(double.tryParse(fields[0]) ?? 0.0);
      final spo2 = double.tryParse(fields[1]) ?? 0.0;
      final hrv  = double.tryParse(fields[2]) ?? 0.0;
      final rr   = double.tryParse(fields[3]) ?? 0.0;


      // Extended fields — present only when firmware sends accel (+ optional activity)
      double axG = 0.0, ayG = 1.0, azG = 0.0;
      bool fallDetected = false;
      ActivityType activity = ActivityType.resting;

      if (fields.length >= 7) {
        axG = double.tryParse(fields[4]) ?? 0.0;
        ayG = double.tryParse(fields[5]) ?? 1.0;
        azG = double.tryParse(fields[6]) ?? 0.0;
      }
      if (fields.length >= 8) {
        final actStr = fields[7].trim().toUpperCase();
        fallDetected = actStr == 'FALL';
        activity = actStr == 'MOVING' ? ActivityType.walking : ActivityType.resting;
      }

      return VitalReading(
        heartRate:       hr,
        spO2:            spo2,
        hrv:             hrv,
        respirationRate: rr,
        activity:        activity,
        fallDetected:    fallDetected,
        accelX:          axG * 9.81,
        accelY:          ayG * 9.81,
        accelZ:          azG * 9.81,
      );
    } catch (e) {
      debugPrint('[BLE] Parse error: $e');
      return null;
    }
  }

  /// Cancels BLE subscriptions only — does NOT cancel the reconnect timer.
  /// Used internally before re-attaching to a device.
  Future<void> _cleanup() async {
    _connected = false;
    await _notifSub?.cancel();
    _notifSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
  }

  /// Full disconnect — cancels reconnect timer so the device stays disconnected.
  /// Call this when the user explicitly presses "Disconnect".
  Future<void> detach() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    await _cleanup();
    _device = null;
    onConnectionChanged?.call(false);
  }

  /// Push a synthetic reading directly into the stream (for debug/testing only).
  void injectReading(VitalReading reading) => _controller.add(reading);

  void dispose() {
    _reconnectTimer?.cancel();
    _cleanup();
    _controller.close();
  }
}
