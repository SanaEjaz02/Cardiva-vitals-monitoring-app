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

  // ── Debug injection methods (exposed for Debug Panel in Profile) ──────────

  void injectNormal() => _controller.add(_generateNormal());

  void injectWarning() => _controller.add(VitalReading(
        heartRate: 125,
        spO2: 91,
        hrv: 22,
        respirationRate: 26,
        activity: ActivityType.resting,
        fallDetected: false,
      ));

  void injectEmergency() => _controller.add(VitalReading(
        heartRate: 155,
        spO2: 85,
        hrv: 18,
        respirationRate: 32,
        activity: ActivityType.resting,
        fallDetected: false,
      ));

  void injectFall() => _controller.add(VitalReading(
        heartRate: 80,
        spO2: 96,
        hrv: 55,
        respirationRate: 16,
        activity: ActivityType.resting,
        fallDetected: true,
      ));

  // ── Internal generators ───────────────────────────────────────────────────

  VitalReading _generate() {
    // Every 30th reading injects low SpO2 to test emergency flow
    if (_readingCount % 30 == 0) {
      return VitalReading(
        heartRate: 78,
        spO2: 88, // emergency threshold (<90)
        hrv: 55,
        respirationRate: 15,
        activity: ActivityType.resting,
        fallDetected: false,
      );
    }
    return _generateNormal();
  }

  VitalReading _generateNormal() {
    return VitalReading(
      heartRate: 60 + _random.nextDouble() * 40,
      spO2: 95 + _random.nextDouble() * 5,
      hrv: 40 + _random.nextDouble() * 40,
      respirationRate: 12 + _random.nextDouble() * 8,
      activity: ActivityType.resting,
      fallDetected: false,
    );
  }
}
