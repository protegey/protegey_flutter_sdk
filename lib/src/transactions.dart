import 'client.dart';
import 'types.dart';

/// Transaction reporting — a thin, faithful mapping onto POST /partner-api/transactions. All
/// validation and business logic stays server-side.
class TransactionsModule {
  final ProtegeyHttpClient _http;

  TransactionsModule(this._http);

  Future<ReportTransactionResult> report(TransactionInput input) async {
    final response = await _http.post('/partner-api/transactions', input.toJson());
    return ReportTransactionResult.fromJson(response);
  }
}
