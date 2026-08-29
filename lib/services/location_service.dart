import 'package:geolocator/geolocator.dart';

/// Wraps device location access via `geolocator`.
///
/// Phase 2 only needs the onboarding permission request; [getCurrentPosition]
/// (used to fetch weather in Phase 5) lives here too so callers have one
/// place to go for anything location-related.
class LocationService {
  /// Requests location permission if not already granted.
  /// Returns true if permission ends up granted (while-in-use or always).
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Returns the device's current position, or null if permission is
  /// missing or location services are disabled.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }
}
