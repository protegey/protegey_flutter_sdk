## 0.10.0

- New `DeviceLocation` (latitude, longitude, `accuracyMeters`, `capturedAt`, `isMocked`) and an optional `location` on `device.identify()` and `TransactionInput`. A transaction without one reuses the location of the customer's last `identify()` (about 15 minutes). Protegey stores it rounded to about 100 m and erases it after 12 months. It feeds four Pan Studio rule fields: `isMockLocation`, `gpsIpDistanceKm`, `impliedTravelSpeedKmh` (impossible travel) and `isNewGpsArea`.
- `ReportTransactionResult.location` (`TransactionLocation`): the position Protegey used for the transaction (rounded) and the signals derived from it, or null when it had none.
- The SDK still never reads the location itself and adds no dependency or permission. The new optional package `protegey_sdk_location` (in this repo) reads it with `ProtegeyLocation.current()` (high accuracy by default; `accuracy: LocationAccuracy.medium` saves battery).

## 0.9.0

Aligned with the partner API (2026-11-19).

- New `protegey.cashDeposits` module: `record()` (`POST /partner-api/cash-deposits`), `list()` with every filter the backend accepts (`page`, `limit` up to 100, `dateFrom`, `dateTo`, `externalCustomerId`, `minAmount`, `maxAmount`, `currency`, `channel`, `decision`, `branchId`, `agentId`) and `get()` by Protegey id or `externalTransactionId`. A reused `externalTransactionId` throws a 409 `ProtegeyApiException`. `CashDeposit.amount` is a `String`, as the API returns it.
- KYC: `KycSessionStatus` gains `recommendation` (`KycRecommendation` approve / review / reject, null before a result) and `images` (`KycImages`: `documentFront`, `documentBack`, `selfie`, `documentFaceCrop`, each a `KycImage` with `url` + `expiresAt`, or null). The links are valid 1 hour and re-issued on every GET.
- KYC: new `kyc.listSessions()` (`GET /partner-api/kyc/sessions`, filters `externalUserId` exact match, `status`, `search`, `page`, `limit`), returning `KycSessionSummary` rows.
- KYC: new `kyc.updateSession()` (`PATCH /partner-api/kyc/sessions/:id`) with `status` (`KycReviewStatus`) and `reviewNote`.
- New shared `ProtegeyPage<T>` for paginated responses. `ProtegeyHttpClient.get()` accepts query parameters and the client gains `patch()`.
- `TransactionChannel`'s wire-value extension is now public (`TransactionChannelWire`).
- Docs: corrected the webhook notes. `kyc.status_changed` also fires on manual status changes, its `sessionId` is the session id (not null), and it carries `recommendation`. `kyb.status_changed.submissionStatus` and `decision.manualReview.previousStatus/newStatus` are UPPER_SNAKE_CASE. Retries: 5 attempts over about 3 h, deduplicate on `eventId`.

## 0.8.0

Audited against the current partner API (2026-11-18). Wire format was already correct for every endpoint this SDK calls; this release fills the remaining gaps.

- `DeviceAttributes` gains `cpuCores`, `totalMemoryMb`, `totalStorageMb`, `freeStorageMb`, the last four fields of the backend's `DeviceAttributesDto`. They are not auto-collected; pass them via `deviceAttributes` if you have them.
- `ProtegeyApiException` gains `errorCode`, filled from the backend's `errorCode` (`PARTNER_SUSPENDED`, `PARTNER_CONTRACT_REQUIRED` on 403).
- `riskScore` / `deviationScore` parsing accepts any JSON number instead of requiring an int.
- Docs: the webhook retry policy is now up to 5 attempts over about 3 h, not "one retry, no queue". The `kyc.status_changed` webhook carries no usable session id, so correlate on `externalUserId` or poll `getSession()`. Also documented the wire values of `KycSessionStatus.status`, the transaction `decision`, and behavioral `status`, plus the KYC link lifetime (30 min, single-use).
- README: new Scope section listing exactly which endpoints the SDK wraps and why the back-office ones (KYB, alerts, sanctions, shared-signal, webhook verification) are server-side only.

## 0.7.0

- `KycSessionStatus` (returned by `kyc.getSession()` / `presentVerification()`) now parses `fullName`, `documentType`, `country`, `livenessScore`, `faceMatchScore`, `documentPhoto`, `documentBackPhoto`, `selfiePhoto`, `documentFaceCrop` — these were already in the backend response but silently dropped before.
- `kyc.startSession()` / `presentVerification()` gain optional `email`/`phone` — never Protegey-verified, feeds identity-resolution's cross-partner matching. Omit either if unknown.
- `TransactionInput.segment` is now a `CustomerSegment` enum (`kyc1`/`kyc2`/`agent`/`superAgent`/`merchant`/`corporate`) instead of a loose `String?`, matching the closed set the backend validates against — same pattern as `TransactionDirection`/`TransactionChannel`.
- Docs: fixed stale references to a previous provider (Protegey's own hosted identity verification app is the only capture flow) and a stale backend path in doc comments. No behavior change.
- Docs: `behavioral.status` comments now show the actual uppercase wire value (`'LEARNING'`/`'SCORED'`) instead of a stale lowercase one.

## 0.6.0

- `TransactionInput` gains `customerName` — shows up directly in the Pan Studio transactions table instead of just the opaque `externalCustomerId`. Self-declared, never verified by Protegey. Send it once and it's remembered on this customer's later transactions too, even if you omit it on some of them.

## 0.5.0

- `TransactionInput` gains `accountBalanceBefore` — lets a Pan Studio rule flag a withdrawal/transfer that drains most of the account balance, a classic mule-account/account-drain signal. Omit it and the corresponding rule field simply never fires.

## 0.4.0

- `TransactionInput` gains `lastPasswordChangeAt`, `lastEmailChangeAt`, `lastPhoneChangeAt` — lets a Pan Studio rule flag a large transaction shortly after an account credential change, a classic account-takeover pattern. `lastPhoneChangeAt` also covers a SIM swap for telcos. Omit any of them and the corresponding rule field simply never fires — Protegey never guesses this.

## 0.3.0

- `TransactionInput` gains `channel` (new `TransactionChannel` enum: branch/atm/pos/online/mobileApp/ussd/agent/api/callCenter), `counterpartyInstitutionCode`, and `counterpartyCountry` — lets Pan Studio rules target bank-wire and cross-border scenarios, not just mobile-money structuring.

## 0.2.2

- Docs: clarified that `transactions.report()` isn't the recommended way to report a transaction
  from a shipped app — that call belongs server-to-server, from your own backend, now that
  Protegey auto-links a `device.identify()` signal to a later transaction by `externalCustomerId`
  alone (no `visitorId` relay needed). No code change; `protegey.transactions` still works.

## 0.2.1

- Fix: `presentVerification()`'s bottom sheet could cover 100% of the screen instead of the
  intended ~80% on some Android devices (`FractionallySizedBox` inside `showModalBottomSheet` is
  unreliable there) — now constrained via `showModalBottomSheet`'s own `constraints` parameter.

## 0.2.0

- `ProtegeyKycView` — shows the hosted KYC flow in an in-app webview (`webview_flutter`) instead of
  requiring you to open it yourself. Polls `kyc.getSession()` in the background and reports status
  changes via `onStatusChange`; you decide when that means "close this view".

## 0.1.0

- Initial release.
- `protegey.device.identify()` — device/session intelligence (Android/iOS fingerprinting via `device_info_plus`).
- `protegey.transactions.report()` — transaction monitoring.
- `protegey.kyc.startSession()` / `protegey.kyc.getSession()` — identity verification + webhook-polling fallback.
- `protegey.behavioral.report()` — behavioral biometrics.
- `baseUrl` is a required constructor parameter, with no built-in default — see the README for why.
