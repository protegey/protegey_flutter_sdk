/// Optional GPS add-on for the Protegey Flutter SDK.
///
/// ```dart
/// // One call: reads the position and sends it with device.identify().
/// await protegey.location.update(externalCustomerId: 'cust-1');
///
/// // Or, in two steps:
/// final location = await ProtegeyLocation.current();
/// await protegey.device.identify(externalCustomerId: 'cust-1', location: location);
/// ```
library protegey_sdk_location;

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:protegey_sdk/protegey_sdk.dart';

export 'package:geolocator/geolocator.dart' show LocationAccuracy;
export 'package:protegey_sdk/protegey_sdk.dart' show DeviceLocation;

/// Reads the device's position for `device.identify(location:)` and `TransactionInput.location`.
///
/// Never throws and never blocks your flow: when location services are off, the permission isn't
/// granted, or no fix arrives in time, it returns `null` and you send the call without a location.
class ProtegeyLocation {
  ProtegeyLocation._();

  /// Returns the current position, or `null`.
  ///
  /// By default it does not show the permission prompt: it only reads the position if your app
  /// already holds the location permission, so you decide when and how to ask (with your own
  /// explanation screen). Pass [requestPermission] `true` to let it show the OS prompt itself when
  /// the permission hasn't been decided yet. A permanently denied permission is never re-asked.
  ///
  /// Waits at most [timeout] for a fresh fix, then falls back to the last known position (which
  /// may be a few minutes old — its `capturedAt` says when it was taken).
  ///
  /// [accuracy] defaults to [LocationAccuracy.high] (GPS, a few meters outdoors). Pass
  /// [LocationAccuracy.medium] to save battery: Wi-Fi/cell only, about 100 m.
  static Future<DeviceLocation?> current({
    bool requestPermission = false,
    Duration timeout = const Duration(milliseconds: 1500),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final platform = GeolocatorPlatform.instance;
      if (!await platform.isLocationServiceEnabled()) return null;

      var permission = await platform.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await platform.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return null;

      Position? position;
      try {
        position = await platform
            .getCurrentPosition(locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout))
            .timeout(timeout);
      } catch (_) {
        position = await _lastKnown(platform);
      }
      return position == null ? null : _toDeviceLocation(position);
    } catch (_) {
      return null;
    }
  }

  static Future<Position?> _lastKnown(GeolocatorPlatform platform) async {
    try {
      return await platform.getLastKnownPosition();
    } catch (_) {
      return null; // not available on web
    }
  }

  static DeviceLocation _toDeviceLocation(Position position) => DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
        capturedAt: position.timestamp,
        isMocked: position.isMocked,
      );
}

/// Adds `protegey.location` to the core client. Import `protegey_sdk_location` to use it.
extension ProtegeyLocationClient on Protegey {
  /// Keeps Protegey up to date with the customer's last device position.
  ProtegeyLocationUpdater get location => ProtegeyLocationUpdater._(this);
}

/// See [ProtegeyLocationUpdater.update].
class ProtegeyLocationUpdater {
  final Protegey _protegey;

  const ProtegeyLocationUpdater._(this._protegey);

  /// Reads the device position (same rules as [ProtegeyLocation.current]) and, when there is one,
  /// sends it with `device.identify(externalCustomerId:, location:)`.
  ///
  /// Returns the [DeviceLocation] it sent, or `null` when there was none (location off,
  /// permission not granted or refused, no fix) or the call failed. It never throws, so you can
  /// call it without awaiting (`unawaited(protegey.location.update(...))`) and carry on.
  ///
  /// Call it at app start / resume and right before a payment: a transaction your backend
  /// reports for the same customer within about 15 minutes reuses this position.
  Future<DeviceLocation?> update({
    required String externalCustomerId,
    bool requestPermission = false,
    Duration timeout = const Duration(milliseconds: 1500),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      final location = await ProtegeyLocation.current(requestPermission: requestPermission, timeout: timeout, accuracy: accuracy);
      if (location == null) return null;
      await _protegey.device.identify(externalCustomerId: externalCustomerId, location: location);
      return location;
    } catch (_) {
      return null;
    }
  }
}
