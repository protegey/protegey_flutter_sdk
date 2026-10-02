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
