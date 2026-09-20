import 'package:uuid/uuid.dart';

import 'client.dart';
import 'fingerprint.dart';
import 'types.dart';

const _uuid = Uuid();

/// Device/session intelligence — replaces what a Keverd SDK call used to do.
class DeviceModule {
  final ProtegeyHttpClient _http;

  DeviceModule(this._http);

  /// Computes a device/session fingerprint (real, stable per-device on Android/iOS via
  /// device_info_plus) and reports it to Protegey.
  ///
  /// [visitorId] overrides the auto-computed fingerprint — useful on a platform
  /// device_info_plus doesn't cover, or if you already maintain your own stable device id.
  /// [phoneNumber] is never read off the device — pass your own customer's phone number if you
  /// already have it (the SDK stores it encrypted, never in the clear).
  /// [eventId] is your own idempotency key for this event — defaults to a fresh random id.
  Future<IdentifyResult> identify({
    String? externalCustomerId,
    String? phoneNumber,
    String? visitorId,
    DeviceAttributes? deviceAttributes,
    String? eventId,
  }) async {
    final computed = visitorId != null
        ? (visitorId: visitorId, attributes: const DeviceAttributes())
        : await computeFingerprint();
    final attributes = (deviceAttributes ?? const DeviceAttributes()).mergeOver(computed.attributes);

    final response = await _http.post('/partner-api/device-events', {
      'eventId': eventId ?? _uuid.v4(),
      if (externalCustomerId != null) 'externalCustomerId': externalCustomerId,
      'visitorId': computed.visitorId,
      'deviceAttributes': attributes.toJson(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });

    return IdentifyResult(
      recorded: response['recorded'] as bool? ?? false,
      action: deviceActionFromWire(response['action'] as String?),
      riskScore: response['riskScore'] as int?,
      visitorId: computed.visitorId,
    );
  }
}
