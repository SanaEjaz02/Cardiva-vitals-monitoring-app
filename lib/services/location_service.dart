import '../core/errors/app_exceptions.dart';

/// Stub position — replaces geolocator during development.
/// Swap back to the real geolocator implementation once NDK is installed.
class Position {
  final double latitude;
  final double longitude;
  const Position({required this.latitude, required this.longitude});
}

class LocationService {
  LocationService._();

  static Future<Position> getCurrentPosition() async {
    // Returns a fixed Karachi coordinate as a development stub.
    // Real GPS via geolocator is re-enabled once NDK is available.
    try {
      return const Position(latitude: 24.8607, longitude: 67.0011);
    } catch (e) {
      throw LocationException('Location unavailable: $e');
    }
  }
}
