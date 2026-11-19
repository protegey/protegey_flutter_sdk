import 'client.dart';
import 'types.dart';

/// Body of `POST /partner-api/cash-deposits`. Only [externalCustomerId], [amount] (> 0) and
/// [currency] (ISO 4217) are required.
class CashDepositInput {
  /// Your own reference for this deposit. Send it to make retries safe: a second call with the
  /// same value is rejected with a 409 `ProtegeyApiException`. Protegey generates one (`cd_<uuid>`)
  /// when omitted.
  final String? externalTransactionId;
  final String externalCustomerId;

  /// Account holder's display name, as you know it. Self-declared, never verified by Protegey.
  final String? customerName;
  final num amount;

  /// ISO 4217 code, e.g. 'XOF'. Any casing.
  final String currency;

  /// When the cash was handed over. Defaults to the time of the call.
  final DateTime? depositedAt;
  final TransactionChannel? channel;
  final String? branchId;
  final String? agentId;
  final String? location;

  /// Who physically brought the cash, when different from the account holder.
  final String? depositorName;
  final Map<String, dynamic>? metadata;

  const CashDepositInput({
    this.externalTransactionId,
    required this.externalCustomerId,
    this.customerName,
    required this.amount,
    required this.currency,
    this.depositedAt,
    this.channel,
    this.branchId,
    this.agentId,
    this.location,
    this.depositorName,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        if (externalTransactionId != null) 'externalTransactionId': externalTransactionId,
        'externalCustomerId': externalCustomerId,
        if (customerName != null) 'customerName': customerName,
        'amount': amount,
        'currency': currency,
        if (depositedAt != null) 'depositedAt': depositedAt!.toUtc().toIso8601String(),
        if (channel != null) 'channel': channel!.wireValue,
        if (branchId != null) 'branchId': branchId,
        if (agentId != null) 'agentId': agentId,
        if (location != null) 'location': location,
        if (depositorName != null) 'depositorName': depositorName,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Response of `POST /partner-api/cash-deposits`.
class RecordCashDepositResult {
  final String cashDepositId;

  /// Yours, or the `cd_<uuid>` Protegey generated when you sent none.
  final String externalTransactionId;

  /// 'CLEAR' | 'REVIEW' | 'BLOCKED'.
  final String decision;

  /// 0-100.
  final int riskScore;

  /// Alert summaries raised by this deposit (`id`, `alertNumber`, `ruleCode`, `status`,
  /// `decisionVerdict`, `triggeredAt`), left untyped like on [ReportTransactionResult].
  final List<Map<String, dynamic>> alerts;

  const RecordCashDepositResult({
    required this.cashDepositId,
    required this.externalTransactionId,
    required this.decision,
    required this.riskScore,
    required this.alerts,
  });

  factory RecordCashDepositResult.fromJson(Map<String, dynamic> json) {
    return RecordCashDepositResult(
      cashDepositId: json['cashDepositId'] as String,
      externalTransactionId: json['externalTransactionId'] as String,
      decision: json['decision'] as String,
      riskScore: (json['riskScore'] as num).toInt(),
      alerts: (json['alerts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

/// One cash deposit, as returned by `GET /partner-api/cash-deposits` (list rows) and
/// `GET /partner-api/cash-deposits/:id` (which also fills [alerts]).
class CashDeposit {
  final String cashDepositId;
  final String externalTransactionId;
  final String externalCustomerId;
  final String? customerName;

  /// A decimal string on the wire (e.g. '2500000.00'), kept as-is so no precision is lost.
  final String amount;
  final String currency;

  /// UPPER_SNAKE_CASE, e.g. 'BRANCH', 'MOBILE_APP'. Null when none was sent.
  final String? channel;
  final String? branchId;
  final String? agentId;
  final String? location;
  final String? depositorName;
  final Map<String, dynamic>? metadata;

  /// 'CLEAR' | 'REVIEW' | 'BLOCKED'.
  final String decision;
  final int? riskScore;
  final DateTime? depositedAt;
  final DateTime? createdAt;

  /// Only on the single lookup — empty for list rows.
  final List<Map<String, dynamic>> alerts;

  const CashDeposit({
    required this.cashDepositId,
    required this.externalTransactionId,
    required this.externalCustomerId,
    this.customerName,
    required this.amount,
    required this.currency,
    this.channel,
    this.branchId,
    this.agentId,
    this.location,
    this.depositorName,
    this.metadata,
    required this.decision,
    this.riskScore,
    this.depositedAt,
    this.createdAt,
    this.alerts = const [],
  });

  factory CashDeposit.fromJson(Map<String, dynamic> json) {
    return CashDeposit(
      cashDepositId: json['cashDepositId'] as String,
      externalTransactionId: json['externalTransactionId'] as String,
      externalCustomerId: json['externalCustomerId'] as String,
      customerName: json['customerName'] as String?,
      amount: json['amount'].toString(),
      currency: json['currency'] as String,
      channel: json['channel'] as String?,
      branchId: json['branchId'] as String?,
      agentId: json['agentId'] as String?,
      location: json['location'] as String?,
      depositorName: json['depositorName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      decision: json['decision'] as String,
      riskScore: (json['riskScore'] as num?)?.toInt(),
      depositedAt: _parseDate(json['depositedAt']),
      createdAt: _parseDate(json['createdAt']),
      alerts: (json['alerts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

DateTime? _parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// Cash deposit reporting — `POST/GET /partner-api/cash-deposits`. A deposit runs through the same
/// rule engine as any transaction (structuring, large-cash rules) and raises the same alerts.
///
/// Like [TransactionsModule], this belongs server-to-server in production: it needs the
/// full-privilege API key, and your teller/agent system is the one holding the authoritative data.
/// It is here for sandbox testing and for Flutter back-office tools that already run with that key.
class CashDepositsModule {
  final ProtegeyHttpClient _http;

  CashDepositsModule(this._http);

  /// Throws a 409 [ProtegeyApiException] when [CashDepositInput.externalTransactionId] was
  /// already used.
  Future<RecordCashDepositResult> record(CashDepositInput input) async {
    final response = await _http.post('/partner-api/cash-deposits', input.toJson());
    return RecordCashDepositResult.fromJson(response);
  }

  /// Newest first. Every filter is optional; [limit] is capped at 100 by the backend. [dateFrom] /
  /// [dateTo] apply to `depositedAt`. [decision] is 'CLEAR' | 'REVIEW' | 'BLOCKED' (any casing).
  Future<ProtegeyPage<CashDeposit>> list({
    int? page,
    int? limit,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? externalCustomerId,
    num? minAmount,
    num? maxAmount,
    String? currency,
    TransactionChannel? channel,
    String? decision,
    String? branchId,
    String? agentId,
  }) async {
    final response = await _http.get('/partner-api/cash-deposits', query: {
      'page': page,
      'limit': limit,
      'dateFrom': dateFrom?.toUtc().toIso8601String(),
      'dateTo': dateTo?.toUtc().toIso8601String(),
      'externalCustomerId': externalCustomerId,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'currency': currency,
      'channel': channel?.wireValue,
      'decision': decision,
      'branchId': branchId,
      'agentId': agentId,
    });
    return ProtegeyPage.fromJson(response, CashDeposit.fromJson);
  }

  /// [id] is either Protegey's `cashDepositId` or your own `externalTransactionId`. Throws a 404
  /// [ProtegeyApiException] when neither matches.
  Future<CashDeposit> get(String id) async {
    final response = await _http.get('/partner-api/cash-deposits/${Uri.encodeComponent(id)}');
    return CashDeposit.fromJson(response);
  }
}
