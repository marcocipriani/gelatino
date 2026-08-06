import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is DeviceLocation &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

final class LocationFailure implements Exception {
  const LocationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class LocationGateway {
  Future<bool> isServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<DeviceLocation> getCurrentLocation();
}

final class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

final class DeviceLocationService {
  const DeviceLocationService(this._gateway);

  final LocationGateway _gateway;

  Future<DeviceLocation> currentLocation() async {
    if (!await _gateway.isServiceEnabled()) {
      throw const LocationFailure(
        'I servizi di localizzazione GPS sono disattivi.',
      );
    }

    var permission = await _gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gateway.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        'I permessi di localizzazione GPS sono stati negati.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'I permessi GPS sono stati disattivati permanentemente.',
      );
    }

    return _gateway.getCurrentLocation();
  }
}

final locationGatewayProvider = Provider<LocationGateway>(
  (ref) => const GeolocatorLocationGateway(),
);

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => DeviceLocationService(ref.watch(locationGatewayProvider)),
);
