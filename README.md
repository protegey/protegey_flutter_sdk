# protegey_sdk

Official Protegey SDK for Flutter. Device intelligence, identity verification and behavioral biometrics, called directly from your app with your own API key.

## Install

Not yet published to pub.dev — install directly from GitHub for now:

```yaml
dependencies:
  protegey_sdk:
    git:
      url: https://github.com/protegey/protegey_flutter_sdk.git
      ref: main # or pin a tag once one exists, e.g. v0.9.0
```

Once published, this becomes:

```yaml
dependencies:
  protegey_sdk: ^0.9.0
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

// Identity verification — one call starts the session AND shows it in a draggable bottom sheet
// (drag handle + Close button). The user never leaves your app, and there's no UI code to write
// for that on your end. Resolves with the final status, or null if closed before one arrived.
final status = await protegey.kyc.presentVerification(context, externalUserId: 'cust-9981');

// Polling fallback for the kyc.status_changed webhook — use this if you're not sure a delivery
// ever arrived, or to double-check a status later. presentVerification() already polls this
// internally while its sheet is open.
// status.status is UPPER_SNAKE_CASE ('APPROVED', 'IN_REVIEW', 'DECLINED', ...) — the final decision;
// status.recommendation is Protegey's own verdict (approve / review / reject), unchanged by a
// manual override; status.outcome is the typed KycOutcome (success / manual / failed / unknown).
if (status != null) {
  final current = await protegey.kyc.getSession(status.sessionId);
  // Pre-signed photo links, valid 1 hour and re-issued on every GET — fetch again rather than
  // storing them. Each one is null when the photo doesn't exist.
  final selfieUrl = current.images?.selfie?.url;
}

// Find a customer's sessions by your own id (exact match), newest first.
final sessions = await protegey.kyc.listSessions(externalUserId: 'cust-9981');

// Behavioral biometrics — aggregated keystroke/touch/navigation metadata only, never raw content
final behavioral = await protegey.behavioral.report(ReportBehavioralEventInput(
  externalCustomerId: 'cust-9981',
  sessionId: 'sess-20260115-01',
  keystroke: const KeystrokeMetrics(avgInterKeyLatencyMs: 145, typingSpeedCharsPerSec: 4.2, errorRate: 0.02),
  touch: const TouchMetrics(avgSwipeVelocity: 22, scrollBehaviorScore: 0.8),
  navigation: const NavigationMetrics(screenSequence: ['login', 'dashboard', 'transfer', 'confirm']),
));
// behavioral.status == 'LEARNING' for the first few sessions of any given customer — expected, not an error.
// Once scored: behavioral.stepUpRecommended tells you whether to challenge this user yourself (OTP, biometric, ...).
```

## Transactions — report these from your backend, not from this app

`POST /partner-api/transactions` is meant to be called server-to-server, from your own backend,
not from this SDK — it carries the full-privilege API key, and your backend already has the
authoritative transaction data (amount, currency, parties) since it's the one processing it.
Calling `device.identify()` above is this app's actual job: as long as your backend sends the
same `externalCustomerId` when it reports the transaction a few minutes later, Protegey picks up
this device/session signal automatically — nothing to relay yourself. `protegey.transactions`
still exists on this client for a quick local/sandbox test, but shipping a real app through it
means embedding your secret key in the app bundle, which this package does nothing to restrict
(see Security below) — use one of the server-side SDKs (`@protegey/sdk`, PHP, Java) instead.

## Cash deposits — also a backend job

`protegey.cashDeposits` wraps `POST/GET /partner-api/cash-deposits`. Same caveat as transactions:
in production your teller/agent system reports deposits server-to-server. The wrapper is here for
sandbox testing and for Flutter back-office tools that already hold the key.

```dart
final deposit = await protegey.cashDeposits.record(const CashDepositInput(
  externalTransactionId: 'dep-0001', // optional, but makes retries safe: reusing it returns 409
  externalCustomerId: 'cust-9981',
  amount: 2500000,
  currency: 'XOF',
  channel: TransactionChannel.branch,
  branchId: 'DKR-PLATEAU',
));
// deposit.decision: 'CLEAR' | 'REVIEW' | 'BLOCKED', plus riskScore and any alerts raised.

final page = await protegey.cashDeposits.list(externalCustomerId: 'cust-9981', limit: 20); // limit <= 100
final one = await protegey.cashDeposits.get('dep-0001'); // Protegey id or your externalTransactionId
// one.amount is a decimal string ('2500000.00'), exactly as the API returns it.
```

## Webhooks

Webhooks are verified on your backend, never in the app, but their shape matters for what you poll:

- `kyc.status_changed` fires on an automated verification result **and** on every manual status change (portal or
  `PATCH /partner-api/kyc/sessions/:id`). Its `sessionId` is the same id `startSession()` returns,
  and it carries `recommendation` next to `status`.
- `kyb.status_changed` carries `submissionStatus` in UPPER_SNAKE_CASE, like every other status field.
  In a KYC `decision.manualReview`, `previousStatus` / `newStatus` are UPPER_SNAKE_CASE too.
- A failed delivery is retried, up to 5 attempts over about 3 hours. A rare duplicate is possible:
  deduplicate on `eventId`.

## Scope

This SDK wraps only the client-side part of the partner API:

| SDK call | Endpoint |
|---|---|
| `device.identify()` | `POST /partner-api/device-events` |
| `behavioral.report()` | `POST /partner-api/behavioral-events` |
| `kyc.startSession()` / `presentVerification()` | `POST /partner-api/kyc/sessions` |
| `kyc.getSession()` | `GET /partner-api/kyc/sessions/:sessionId` |
| `kyc.listSessions()` | `GET /partner-api/kyc/sessions` |
| `kyc.updateSession()` (review override, back-office) | `PATCH /partner-api/kyc/sessions/:sessionId` |
| `transactions.report()` (sandbox/testing only, see above) | `POST /partner-api/transactions` |
| `cashDeposits.record()` / `list()` / `get()` (sandbox/back-office, see above) | `POST/GET /partner-api/cash-deposits`, `GET /partner-api/cash-deposits/:id` |

Everything else — KYB applicants, alerts (list/update/convert-to-case/flag-transaction),
transaction queries, sanctions screening, the shared fraud signal check and
webhook signature verification — is a back-office job and belongs on your backend, with a
server-side SDK. Webhooks (`X-Signature` = hex HMAC-SHA256 of `"{X-Timestamp}.{rawBody}"`) must be
verified with your webhook secret, which must never ship in an app.

Errors: any non-2xx response throws `ProtegeyApiException` (`status`, `message`, and `errorCode`
when the backend sends one — `PARTNER_SUSPENDED` / `PARTNER_CONTRACT_REQUIRED` on 403). Sandbox
keys are capped at 10 KYC sessions and 100 transactions per UTC day (400 once exceeded). A key is
live or sandbox depending on which one you generated in the portal — nothing in this SDK selects
the mode.

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
server-side. The partner API has no restricted/publishable key type today: whoever extracts the
key from your app bundle can call every partner-api endpoint, including the back-office ones listed
under Scope. Keep it out of source control and public repos the same way you would any other
secret. Protegey does not perform request rate-limiting or origin/bundle-id allowlisting on your
behalf today.
