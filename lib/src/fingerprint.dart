import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:uuid/uuid.dart';

import 'types.dart';

const _uuid = Uuid();

/// Computes a stable device fingerprint and whatever attributes are safely available from
/// device_info_plus plus the Tier 1/2 enrichment plugins (connectivity_plus, battery_plus,
/// flutter_jailbreak_detection — all three require zero extra runtime permission on either
/// platform). Deliberately uses only policy-safe, non-hardware identifiers — Android ID
/// (Android) / identifierForVendor (iOS), never IMEI/UDID/serial — per Apple/Google policy and
/// GDPR/CPRA.
Future<({String visitorId, DeviceAttributes attributes})> computeFingerprint() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final info = await deviceInfo.androidInfo;
    final stableId = info.id; // Android ID — resettable pseudo-identifier, not a hardware serial.
    final enrichment = await _computeEnrichment();
    return (
      visitorId: _hash('android', stableId),
      attributes: DeviceAttributes(
        platform: 'Android',
        osVersion: info.version.release,
        deviceModel: '${info.brand} ${info.model}',
        manufacturer: info.manufacturer,
        isEmulator: !info.isPhysicalDevice,
        isRooted: enrichment.isRooted,
        devicePixelRatio: _devicePixelRatio(),
        connectionType: enrichment.connectionType,
        isVpnActive: enrichment.isVpnActive,
        batteryLevel: enrichment.batteryLevel,
        isCharging: enrichment.isCharging,
      ),
    );
  }

  if (Platform.isIOS) {
    final info = await deviceInfo.iosInfo;
    final stableId = info.identifierForVendor ?? _uuid.v4();
    final enrichment = await _computeEnrichment();
    return (
      visitorId: _hash('ios', stableId),
      attributes: DeviceAttributes(
        platform: 'iOS',
        osVersion: info.systemVersion,
        deviceModel: info.utsname.machine,
        manufacturer: 'Apple',
        isEmulator: !info.isPhysicalDevice,
        isRooted: enrichment.isRooted,
        devicePixelRatio: _devicePixelRatio(),
        connectionType: enrichment.connectionType,
        isVpnActive: enrichment.isVpnActive,
        batteryLevel: enrichment.batteryLevel,
        isCharging: enrichment.isCharging,
      ),
    );
  }

  // Any other platform (desktop, unsupported) — no reliable stable identifier available through
  // device_info_plus; fall back to a fresh random id. Callers on these platforms should pass
  // their own stable `visitorId` (e.g. one they persist themselves) to ProtegeyDevice.identify().
  return (visitorId: _uuid.v4(), attributes: const DeviceAttributes());
}

class _Enrichment {
  final bool? isRooted;
  final String? connectionType;
  final bool? isVpnActive;
  final int? batteryLevel;
  final bool? isCharging;

  const _Enrichment({this.isRooted, this.connectionType, this.isVpnActive, this.batteryLevel, this.isCharging});
}

const _enrichmentTimeout = Duration(seconds: 2);

/// Each signal is independently best-effort — a missing plugin implementation on some platform, a
/// transient platform-channel error, or a stream that never emits, must never break (or noticeably
/// delay) the core fingerprint/identify call, hence the timeout on every single call below.
Future<_Enrichment> _computeEnrichment() async {
  bool? isRooted;
  try {
    isRooted = await FlutterJailbreakDetection.jailbroken.timeout(_enrichmentTimeout);
  } catch (_) {
    // Left null — never guessed.
  }

  String? connectionType;
  bool? isVpnActive;
  try {
    final results = await Connectivity().checkConnectivity().timeout(_enrichmentTimeout);
    isVpnActive = results.contains(ConnectivityResult.vpn);
    connectionType = _primaryConnectionType(results);
  } catch (_) {
    // Left null.
  }

  int? batteryLevel;
  bool? isCharging;
  try {
    final battery = Battery();
    batteryLevel = await battery.batteryLevel.timeout(_enrichmentTimeout);
    // The stream form (not a Future getter) is the one API every battery_plus version since v1
    // has exposed — `.first` risks waiting for the NEXT change event rather than the current
    // state on some plugin versions, which is exactly what the timeout above guards against.
    final state = await battery.onBatteryStateChanged.first.timeout(_enrichmentTimeout);
    isCharging = state == BatteryState.charging || state == BatteryState.full;
  } catch (_) {
    // Left null — battery_plus throws on some desktop/web targets this SDK doesn't primarily target.
  }

  return _Enrichment(
    isRooted: isRooted,
    connectionType: connectionType,
    isVpnActive: isVpnActive,
    batteryLevel: batteryLevel,
    isCharging: isCharging,
  );
}

/// connectivity_plus reports every active transport as a list (a device can be on wifi AND vpn
/// at once) — this reports the underlying physical transport, since `isVpnActive` above already
/// carries the VPN signal on its own.
String _primaryConnectionType(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi)) return 'wifi';
  if (results.contains(ConnectivityResult.mobile)) return 'cellular';
  if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
  if (results.contains(ConnectivityResult.none)) return 'none';
  return 'unknown';
}

/// From dart:ui directly — no BuildContext needed, unlike MediaQuery.
double? _devicePixelRatio() {
  final views = ui.PlatformDispatcher.instance.views;
  return views.isNotEmpty ? views.first.devicePixelRatio : null;
}

String _hash(String platform, String stableId) {
  return sha256.convert(utf8.encode('$platform:$stableId')).toString();
}
