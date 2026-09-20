/// The Protegey SDK for Flutter — one client for device intelligence, transaction reporting and
/// identity verification.
library protegey_sdk;

import 'package:http/http.dart' as http;

import 'src/client.dart';
import 'src/device.dart';
import 'src/kyc.dart';
import 'src/transactions.dart';

export 'src/types.dart';
export 'src/kyc.dart' show StartKycSessionResult;

/// ```dart
/// final protegey = Protegey(apiKey: 'YOUR_API_KEY', baseUrl: 'https://api.protegey.com');
/// final identify = await protegey.device.identify(externalCustomerId: 'cust-1');
/// await protegey.transactions.report(TransactionInput(...));
/// final session = await protegey.kyc.startSession(externalUserId: 'cust-1');
/// ```
///
/// `baseUrl` has no default — confirm the current value with Protegey (it may differ between
/// environments and can change independently of this package). See [ProtegeyHttpClient]'s doc
/// comment for why.
///
/// Namespaced (`.device`, `.transactions`, `.kyc`) so more of the partner-api surface can be added
/// later without breaking this shape.
class Protegey {
  final DeviceModule device;
  final TransactionsModule transactions;
  final KycModule kyc;

  Protegey({required String apiKey, required String baseUrl, http.Client? httpClient})
      : this._(ProtegeyHttpClient(apiKey, baseUrl: baseUrl, httpClient: httpClient));

  Protegey._(ProtegeyHttpClient http)
      : device = DeviceModule(http),
        transactions = TransactionsModule(http),
        kyc = KycModule(http);
}
