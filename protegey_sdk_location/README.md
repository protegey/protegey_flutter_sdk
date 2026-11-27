# protegey_sdk_location

Optional GPS add-on for [`protegey_sdk`](../README.md). It reads the device position so Protegey can
flag a fake GPS position, a GPS position far from the IP address, impossible travel and a
never-seen area.

The core `protegey_sdk` never reads the location itself, so apps that don't install this package
have no location permission to declare.

## Install

```yaml
dependencies:
  protegey_sdk: ...
  protegey_sdk_location: ...
```

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`ACCESS_COARSE_LOCATION` alone also works; positions are then about 1–3 km accurate.

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location helps us protect your account against fraud.</string>
```

Apple requires this key as soon as the app contains location code, even if it never asks. Write
the text in your own words and languages; it is shown in the system prompt.

## Keep Protegey up to date (one call)

In production your backend reports transactions server-to-server, so the app's only job is to
keep Protegey up to date with the customer's last device position:

```dart
import 'package:protegey_sdk_location/protegey_sdk_location.dart';

// At app start / resume, and right before a payment:
unawaited(protegey.location.update(externalCustomerId: 'cust-1'));
```

- It reads the position (same rules as `ProtegeyLocation.current()` below) and, if there is one,
  sends it with `device.identify(externalCustomerId:, location:)`.
- **Silent.** No UI is shown. By default it never shows the permission prompt
  (`requestPermission: false`); when the permission is refused there is simply no position.
- **Never throws, never blocks.** It returns the `DeviceLocation` it sent, or `null` when there was
  none or the call failed. You don't need to await it.
- **Your backend's transactions reuse it.** A transaction reported server-to-server for the same
  customer within about 15 minutes uses this position — nothing to relay.
- `timeout` and `accuracy` work as for `current()`.

## Read the position yourself

```dart
import 'package:protegey_sdk_location/protegey_sdk_location.dart';

final location = await ProtegeyLocation.current();
await protegey.device.identify(externalCustomerId: 'cust-1', location: location);
```

- **The permission prompt is yours to show.** By default `current()` only reads the position if
  your app already holds the permission, so you can ask at the right moment, after your own
  explanation screen. Pass `requestPermission: true` to let it show the system prompt when the
  permission hasn't been decided yet. A permanently denied permission is never re-asked.
- **It never blocks your flow.** It waits at most 1.5 s (`timeout`) for a fresh fix, then falls back
  to the last known position. When location is off, denied or unavailable, it returns `null`:
  send the call without a location.
- **Precise by default.** It asks for a GPS fix (`LocationAccuracy.high`, a few meters outdoors).
  Pass `accuracy: LocationAccuracy.medium` to save battery (Wi-Fi/cell only, about 100 m). Indoors a
  GPS fix can take a few seconds: raise `timeout` if you can wait.
- **Transactions reuse it.** A transaction reported for the same customer within about 15 minutes
  of `identify(location: ...)` reuses that position, so your backend doesn't need to relay it.
  You can also pass it explicitly with `TransactionInput(location: ...)`.

## Privacy

Protegey stores the position rounded to about 100 m, never the exact one, and erases the
coordinates after 12 months. Tell your users in your privacy policy that the position is used for
fraud prevention.
