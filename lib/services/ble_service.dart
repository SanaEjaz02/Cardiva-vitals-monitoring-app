// BleService is disabled — hardware is not ready.
// This stub satisfies imports without pulling in flutter_blue_plus.
// Re-enable by adding flutter_blue_plus to pubspec and restoring the full
// implementation when the wearable firmware is ready.

import '../core/errors/app_exceptions.dart';

class BleService {
  static const String serviceUuid = '0000180D-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid = '00002A37-0000-1000-8000-00805F9B34FB';

  Stream<Map<String, dynamic>> get vitalStream =>
      throw const BleException('BleService not enabled — hardware not ready.');

  Future<void> scanAndConnect() async =>
      throw const BleException('BleService not enabled — hardware not ready.');

  Future<void> disconnect() async {}
  void dispose() {}
}