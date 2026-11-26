import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:protegey_sdk_location/protegey_sdk_location.dart';

class _FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  Future<Position> Function()? current;
  Position? lastKnown;
  int permissionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permissionAfterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) => current!();

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => lastKnown;
}

Position _position({double latitude = 5.3599, double longitude = -4.0083, double accuracy = 25, bool isMocked = false, DateTime? at}) => Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: at ?? DateTime.utc(2026, 11, 26, 10),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: isMocked,
    );

void main() {
  late _FakeGeolocator fake;

  setUp(() {
    fake = _FakeGeolocator()..current = () async => _position();
    GeolocatorPlatform.instance = fake;
  });

  test('returns the current position when the permission is already granted', () async {
    final location = await ProtegeyLocation.current();

    expect(location!.toJson(), {'latitude': 5.3599, 'longitude': -4.0083, 'accuracyMeters': 25.0, 'capturedAt': '2026-11-26T10:00:00.000Z', 'isMocked': false});
  });

  test('passes the mock-location flag through', () async {
    fake.current = () async => _position(isMocked: true);

    expect((await ProtegeyLocation.current())!.isMocked, isTrue);
  });

  test('never shows the permission prompt by default', () async {
    fake.permission = LocationPermission.denied;

    expect(await ProtegeyLocation.current(), isNull);
    expect(fake.permissionRequests, 0);
  });

  test('shows the prompt when requestPermission is true, and reads the position once granted', () async {
    fake.permission = LocationPermission.denied;

    final location = await ProtegeyLocation.current(requestPermission: true);

    expect(fake.permissionRequests, 1);
    expect(location, isNotNull);
  });

  test('never re-asks a permanently denied permission', () async {
    fake.permission = LocationPermission.deniedForever;

    expect(await ProtegeyLocation.current(requestPermission: true), isNull);
    expect(fake.permissionRequests, 0);
  });

  test('returns null when location services are off', () async {
    fake.serviceEnabled = false;

    expect(await ProtegeyLocation.current(), isNull);
  });

  test('falls back to the last known position when no fresh fix arrives in time', () async {
    fake.current = () => Completer<Position>().future; // never completes
    fake.lastKnown = _position(latitude: 14.7167, longitude: -17.4677, at: DateTime.utc(2026, 11, 26, 9, 55));

    final location = await ProtegeyLocation.current(timeout: const Duration(milliseconds: 50));

    expect(location!.latitude, 14.7167);
    expect(location.capturedAt, DateTime.utc(2026, 11, 26, 9, 55));
  });

  test('returns null instead of throwing when the platform fails', () async {
    fake.current = () async => throw Exception('boom');
    fake.lastKnown = null;

    expect(await ProtegeyLocation.current(), isNull);
  });
}
