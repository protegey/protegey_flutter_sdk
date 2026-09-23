# protegey_sdk

Official Protegey SDK for Flutter. Device intelligence, transaction reporting, identity verification and behavioral biometrics, called directly from your app with your own API key.

## Install

Not yet published to pub.dev — install directly from GitHub for now:

```yaml
dependencies:
  protegey_sdk:
    git:
      url: https://github.com/protegey/protegey_flutter_sdk.git
      ref: main # or pin a tag once one exists, e.g. v0.1.0
```

Once published, this becomes:

```yaml
dependencies:
  protegey_sdk: ^0.1.0
```

Source: [github.com/protegey/protegey_flutter_sdk](https://github.com/protegey/protegey_flutter_sdk)

## Usage

```dart
import 'package:protegey_sdk/protegey_sdk.dart';

final protegey = Protegey(apiKey: 'YOUR_API_KEY', baseUrl: 'https://api.protegey.com');

// Device intelligence — call on login / session start.
// Computes a real, stable per-device fingerprint on Android/iOS via device_info_plus.
final identify = await protegey.device.identify(
  externalCustomerId: 'cust-9981',
  phoneNumber: '+22890000001', // optional — you already have it, never read off the device
);

// Transactions
final result = await protegey.transactions.report(TransactionInput(
  externalTransactionId: 'tx-00234',
  externalCustomerId: 'cust-9981',
  direction: TransactionDirection.debit,
  amount: 250000,
  currency: 'XOF',
  transactionType: 'cashout',
  isCash: true,
  visitorId: identify.visitorId, // fold the same device signal into this transaction's decision
));

// Identity verification — no manual API call needed, the SDK starts the session and hands back the link
final session = await protegey.kyc.startSession(externalUserId: 'cust-9981');

// Polling fallback — webhook delivery is best-effort (one retry, no queue), so use this if
// you're not sure a delivery ever arrived, or just want to double-check a session's status.
final current = await protegey.kyc.getSession(session.sessionId);

// Behavioral biometrics — aggregated keystroke/touch/navigation metadata only, never raw content
final behavioral = await protegey.behavioral.report(ReportBehavioralEventInput(
  externalCustomerId: 'cust-9981',
  sessionId: 'sess-20260115-01',
  keystroke: const KeystrokeMetrics(avgInterKeyLatencyMs: 145, typingSpeedCharsPerSec: 4.2, errorRate: 0.02),
  touch: const TouchMetrics(avgSwipeVelocity: 22, scrollBehaviorScore: 0.8),
  navigation: const NavigationMetrics(screenSequence: ['login', 'dashboard', 'transfer', 'confirm']),
));
// behavioral.status == 'learning' for the first few sessions of any given customer — expected, not an error.
// Once scored: behavioral.stepUpRecommended tells you whether to challenge this user yourself (OTP, biometric, ...).
```

## `baseUrl` — no default, on purpose

This package ships inside apps that can't be force-updated the moment Protegey's own API domain
changes. Baking in a guess would risk every already-shipped app silently talking to a stale host
later — so `baseUrl` is required, with no fallback. Confirm the current value with Protegey before
you ship (it can differ between environments and change independently of this package's version).

## Device attributes

`device.identify()` uses only policy-safe, non-hardware identifiers — Android ID (Android) /
`identifierForVendor` (iOS), never IMEI/UDID/serial — per Apple/Google platform policy and
GDPR/CPRA. On any other platform (desktop, unsupported), there's no reliable stable id available
through `device_info_plus`; pass your own via `visitorId` if you need one.

**Tier 1/2 enrichment (2026-09-23)**: `isRooted` is now detected via `flutter_jailbreak_detection`
(previously unimplemented — `device_info_plus` only exposes `isPhysicalDevice`, used for
`isEmulator`). Also collected, all zero-extra-permission on both platforms: `manufacturer`,
`connectionType`/`isVpnActive` (via `connectivity_plus`), `batteryLevel`/`isCharging` (via
`battery_plus`). Deliberately NOT collected: mobile carrier/MCC-MNC (unreliable without a
sensitive Android permission, heavily restricted on iOS), CPU/RAM/storage (no already-adopted,
well-maintained plugin exposes them), GPS location, and the advertising identifier (IDFA/AAID) —
the latter would require the iOS App Tracking Transparency prompt for no proportionate fraud-signal
gain. Every enrichment call is independently best-effort: a plugin failure never breaks
`identify()`, the field is just omitted.

## Development

This repo uses [fvm](https://fvm.app) to pin the Flutter version — see `.fvmrc`.

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

## Security note

Your API key is used directly from your app — the same key your backend would otherwise use
server-side. Keep it out of source control and public repos the same way you would any other
secret. Protegey does not perform request rate-limiting or origin/bundle-id allowlisting on your
behalf today.
