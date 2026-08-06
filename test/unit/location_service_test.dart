import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gelatino/providers/location_provider.dart';

void main() {
  test(
    'first-use denied requests permission before reading location',
    () async {
      final gateway = _RecordingLocationGateway(
        checkedPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.whileInUse,
        location: const DeviceLocation(latitude: 45.4642, longitude: 9.19),
      );
      final service = DeviceLocationService(gateway);

      final location = await service.currentLocation();

      expect(
        location,
        const DeviceLocation(latitude: 45.4642, longitude: 9.19),
      );
      expect(gateway.calls, <String>[
        'service',
        'check',
        'request',
        'position',
      ]);
    },
  );

  test('deniedForever fails closed without reading a position', () async {
    final gateway = _RecordingLocationGateway(
      checkedPermission: LocationPermission.deniedForever,
      requestedPermission: LocationPermission.whileInUse,
      location: const DeviceLocation(latitude: 45.46, longitude: 9.19),
    );
    final service = DeviceLocationService(gateway);

    await expectLater(
      service.currentLocation(),
      throwsA(
        isA<LocationFailure>().having(
          (failure) => failure.message,
          'message',
          contains('permanentemente'),
        ),
      ),
    );
    expect(gateway.calls, <String>['service', 'check']);
  });
}

final class _RecordingLocationGateway implements LocationGateway {
  _RecordingLocationGateway({
    required this.checkedPermission,
    required this.requestedPermission,
    required this.location,
  });

  final LocationPermission checkedPermission;
  final LocationPermission requestedPermission;
  final DeviceLocation location;
  final List<String> calls = <String>[];

  @override
  Future<bool> isServiceEnabled() async {
    calls.add('service');
    return true;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    calls.add('check');
    return checkedPermission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    calls.add('request');
    return requestedPermission;
  }

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    calls.add('position');
    return location;
  }
}
