import 'client.dart';
import 'types.dart';

/// Transaction reporting — a thin, faithful mapping onto POST /partner-api/transactions. All
/// validation and business logic stays server-side.
///
/// Not the recommended way to report a transaction from a shipped app: this call carries the
/// full-privilege API key, and your backend already has the authoritative transaction data since
/// it's the one processing it. Call [DeviceModule.identify] from this app instead, and report the
/// transaction itself server-to-server (this same endpoint, from one of the server-side SDKs) with
/// the same externalCustomerId — Protegey links the two automatically. See the package README's
/// "Transactions" section.
class TransactionsModule {
  final ProtegeyHttpClient _http;

  TransactionsModule(this._http);

  Future<ReportTransactionResult> report(TransactionInput input) async {
    final response = await _http.post('/partner-api/transactions', input.toJson());
    return ReportTransactionResult.fromJson(response);
  }
}
