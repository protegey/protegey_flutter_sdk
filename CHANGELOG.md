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
