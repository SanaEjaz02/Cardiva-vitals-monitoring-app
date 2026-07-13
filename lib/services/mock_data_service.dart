import 'dart:async';
import 'dart:math';
import '../models/vital_reading.dart';

class MockDataService {
  final _controller = StreamController<VitalReading>.broadcast();
  Timer? _timer;
  final _random = Random();
  int _readingCount = 0;

  Stream<VitalReading> get stream => _controller.stream;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _readingCount++;
      _controller.add(_generate());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Debug injection methods ───────────────────────────────────────────────

  void injectNormal() => _controller.add(_generateNormal());

  void injectWarning() => _controller.add(VitalReading(
        heartRate: 125,
        spO2: 91,
        hrv: 22,
        respirationRate: 26,
        activity: ActivityType.resting,
        fallDetected: false,
        accelX: _random.nextDouble() * 2 - 1,
        accelY: 9.8 + _random.nextDouble() * 0.5,
        accelZ: _random.nextDouble() * 2 - 1,
      ));

  void injectEmergency() => _controller.add(VitalReading(
        heartRate: 155,
        spO2: 85,
        hrv: 18,
        respirationRate: 32,
        activity: ActivityType.resting,
        fallDetected: false,
        accelX: _random.nextDouble() * 2 - 1,
        accelY: 9.8 + _random.nextDouble() * 0.5,
        accelZ: _random.nextDouble() * 2 - 1,
      ));

  // Fall: sudden large acceleration spike then near-zero (free-fall then impact)
  void injectFall() => _controller.add(VitalReading(
        heartRate: 95,
        spO2: 94,
        hrv: 28,
        respirationRate: 22,
        activity: ActivityType.resting,
        fallDetected: true,
        accelX: 28 + _random.nextDouble() * 10,
        accelY: 1.5 + _random.nextDouble() * 1.5,
        accelZ: _random.nextDouble() * 8,
      ));

  // ── Internal generators ───────────────────────────────────────────────────

  VitalReading _generate() {
    if (_readingCount % 200 == 0 && _readingCount > 0) {
      return VitalReading(
        heartRate: 78,
        spO2: 88,
        hrv: 55,
        respirationRate: 15,
        activity: ActivityType.resting,
        fallDetected: false,
        accelX: _random.nextDouble() * 2 - 1,
        accelY: 9.8 + _random.nextDouble() * 0.5,
        accelZ: _random.nextDouble() * 2 - 1,
      );
    }
    return _generateNormal();
  }

  VitalReading _generateNormal() {
    // Realistic resting wrist accel: gravity mostly in Y, small noise from movement
    return VitalReading(
      heartRate: 60 + _random.nextDouble() * 40,
      spO2: 95 + _random.nextDouble() * 5,
      hrv: 40 + _random.nextDouble() * 40,
      respirationRate: 12 + _random.nextDouble() * 8,
      activity: ActivityType.resting,
      fallDetected: false,
      accelX: _random.nextDouble() * 2.0 - 1.0,
      accelY: 9.0 + _random.nextDouble() * 1.6,
      accelZ: _random.nextDouble() * 2.0 - 1.0,
    );
  }
}
