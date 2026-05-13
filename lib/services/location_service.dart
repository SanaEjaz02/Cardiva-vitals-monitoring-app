import 'package:geolocator/geolocator.dart';
import '../core/errors/app_exceptions.dart';

export 'package:geolocator/geolocator.dart' show Position;

class LocationService {
  LocationService._();

  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled on this device.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission was denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Location permission permanently denied. Enable it in Settings.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // Fall back to last known position if fresh fix times out
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw LocationException('Could not determine location: $e');
    }
  }
}
