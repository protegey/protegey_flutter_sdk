import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'types.dart';

const _uuid = Uuid();

/// Computes a stable device fingerprint and whatever attributes are safely available from
/// device_info_plus. Deliberately uses only policy-safe, non-hardware identifiers — Android ID
/// (Android) / identifierForVendor (iOS), never IMEI/UDID/serial — per Apple/Google policy and
/// GDPR/CPRA. Root/jailbreak detection is not implemented in v1 (see README) — `isRooted` is
/// always omitted rather than guessed.
Future<({String visitorId, DeviceAttributes attributes})> computeFingerprint() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final info = await deviceInfo.androidInfo;
    final stableId = info.id; // Android ID — resettable pseudo-identifier, not a hardware serial.
    return (
      visitorId: _hash('android', stableId),
      attributes: DeviceAttributes(
        platform: 'Android',
        osVersion: info.version.release,
        deviceModel: '${info.brand} ${info.model}',
        isEmulator: !info.isPhysicalDevice,
      ),
    );
  }

  if (Platform.isIOS) {
    final info = await deviceInfo.iosInfo;
    final stableId = info.identifierForVendor ?? _uuid.v4();
    return (
      visitorId: _hash('ios', stableId),
      attributes: DeviceAttributes(
        platform: 'iOS',
        osVersion: info.systemVersion,
        deviceModel: info.utsname.machine,
        isEmulator: !info.isPhysicalDevice,
      ),
    );
  }

  // Any other platform (desktop, unsupported) — no reliable stable identifier available through
  // device_info_plus; fall back to a fresh random id. Callers on these platforms should pass
  // their own stable `visitorId` (e.g. one they persist themselves) to ProtegeyDevice.identify().
  return (visitorId: _uuid.v4(), attributes: const DeviceAttributes());
}

String _hash(String platform, String stableId) {
  return sha256.convert(utf8.encode('$platform:$stableId')).toString();
}
