/// Mirrors the backend's DeviceAttributesDto — a closed, all-optional list.
class DeviceAttributes {
  final String? platform;
  final String? osVersion;
  final String? deviceModel;
  final String? userAgent;
  final int? screenWidth;
  final int? screenHeight;
  final String? timezone;
  final String? language;
  final String? appVersion;
  final bool? isRooted;
  final bool? isEmulator;

  // ── Tier 1/2 enrichment (2026-09-23) — see fingerprint.dart for exactly which plugin backs
  // each field and why cpuCores/totalMemory/storage were deliberately left out for now (no
  // already-adopted plugin exposes them without pulling in an extra, less-maintained package).
  final String? manufacturer;

  /// Often fractional on real devices (e.g. 2.625, 3.5) — never assume an integer.
  final double? devicePixelRatio;

  /// "wifi" | "cellular" | "ethernet" | "vpn" | "unknown" per the backend docs (not enforced
  /// server-side) — from connectivity_plus, which can also report "none" when offline.
  final String? connectionType;

  /// True only when connectivity_plus itself reports the active transport as VPN — not a guess.
  final bool? isVpnActive;

  /// 0-100, from battery_plus.
  final int? batteryLevel;
  final bool? isCharging;

  // Accepted by the backend but never auto-collected by this SDK (no already-adopted plugin
  // exposes them — see fingerprint.dart). Pass them yourself via `deviceAttributes` if you have them.
  final int? cpuCores;
  final int? totalMemoryMb;
  final int? totalStorageMb;
  final int? freeStorageMb;

  const DeviceAttributes({
    this.platform,
    this.osVersion,
    this.deviceModel,
    this.userAgent,
    this.screenWidth,
    this.screenHeight,
    this.timezone,
    this.language,
    this.appVersion,
    this.isRooted,
    this.isEmulator,
    this.manufacturer,
    this.devicePixelRatio,
    this.connectionType,
    this.isVpnActive,
    this.batteryLevel,
    this.isCharging,
    this.cpuCores,
    this.totalMemoryMb,
    this.totalStorageMb,
    this.freeStorageMb,
  });

  DeviceAttributes mergeOver(DeviceAttributes base) {
    return DeviceAttributes(
      platform: platform ?? base.platform,
      osVersion: osVersion ?? base.osVersion,
      deviceModel: deviceModel ?? base.deviceModel,
      userAgent: userAgent ?? base.userAgent,
      screenWidth: screenWidth ?? base.screenWidth,
      screenHeight: screenHeight ?? base.screenHeight,
      timezone: timezone ?? base.timezone,
      language: language ?? base.language,
      appVersion: appVersion ?? base.appVersion,
      isRooted: isRooted ?? base.isRooted,
      isEmulator: isEmulator ?? base.isEmulator,
      manufacturer: manufacturer ?? base.manufacturer,
      devicePixelRatio: devicePixelRatio ?? base.devicePixelRatio,
      connectionType: connectionType ?? base.connectionType,
      isVpnActive: isVpnActive ?? base.isVpnActive,
      batteryLevel: batteryLevel ?? base.batteryLevel,
      isCharging: isCharging ?? base.isCharging,
      cpuCores: cpuCores ?? base.cpuCores,
      totalMemoryMb: totalMemoryMb ?? base.totalMemoryMb,
      totalStorageMb: totalStorageMb ?? base.totalStorageMb,
      freeStorageMb: freeStorageMb ?? base.freeStorageMb,
    );
  }

  Map<String, dynamic> toJson() => {
        if (platform != null) 'platform': platform,
        if (osVersion != null) 'osVersion': osVersion,
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (userAgent != null) 'userAgent': userAgent,
        if (screenWidth != null) 'screenWidth': screenWidth,
        if (screenHeight != null) 'screenHeight': screenHeight,
        if (timezone != null) 'timezone': timezone,
        if (language != null) 'language': language,
        if (appVersion != null) 'appVersion': appVersion,
        if (isRooted != null) 'isRooted': isRooted,
        if (isEmulator != null) 'isEmulator': isEmulator,
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (devicePixelRatio != null) 'devicePixelRatio': devicePixelRatio,
        if (connectionType != null) 'connectionType': connectionType,
        if (isVpnActive != null) 'isVpnActive': isVpnActive,
        if (batteryLevel != null) 'batteryLevel': batteryLevel,
        if (isCharging != null) 'isCharging': isCharging,
        if (cpuCores != null) 'cpuCores': cpuCores,
        if (totalMemoryMb != null) 'totalMemoryMb': totalMemoryMb,
        if (totalStorageMb != null) 'totalStorageMb': totalStorageMb,
        if (freeStorageMb != null) 'freeStorageMb': freeStorageMb,
      };
}

enum DeviceAction { allow, softChallenge, hardChallenge, block }

/// Every status/decision/action-like field on partner-api moved to UPPER_SNAKE_CASE on
/// 2026-11-14 (backend commit f2b2375 and follow-ups) — this now expects 'ALLOW',
/// 'SOFT_CHALLENGE', 'HARD_CHALLENGE', 'BLOCK' on the wire, matching both the standalone
/// device-events response and the deviceAction field embedded in a transaction response.
DeviceAction? deviceActionFromWire(String? value) {
  switch (value) {
    case 'ALLOW':
      return DeviceAction.allow;
    case 'SOFT_CHALLENGE':
      return DeviceAction.softChallenge;
    case 'HARD_CHALLENGE':
      return DeviceAction.hardChallenge;
    case 'BLOCK':
      return DeviceAction.block;
    default:
      return null;
  }
}

class IdentifyResult {
  final bool recorded;
  final DeviceAction? action;
  final int? riskScore;

  /// The fingerprint the SDK computed (or the one you passed in) — save it if you want to correlate later.
  final String visitorId;

  const IdentifyResult({
    required this.recorded,
    required this.action,
    required this.riskScore,
    required this.visitorId,
  });
}

enum TransactionDirection { debit, credit }

extension on TransactionDirection {
  String get wireValue => this == TransactionDirection.debit ? 'DEBIT' : 'CREDIT';
}

/// How the transaction was initiated — lets a Pan Studio rule distinguish e.g. a USSD cash-out
/// from an API-initiated transfer. Omit if not meaningful for your integration.
enum TransactionChannel { branch, atm, pos, online, mobileApp, ussd, agent, api, callCenter }

/// Wire value of a [TransactionChannel] as the backend's request DTOs accept it (lower snake case,
/// e.g. 'mobile_app'). Responses echo the channel back UPPER_SNAKE_CASE ('MOBILE_APP').
extension TransactionChannelWire on TransactionChannel {
  String get wireValue => switch (this) {
        TransactionChannel.branch => 'branch',
        TransactionChannel.atm => 'atm',
        TransactionChannel.pos => 'pos',
        TransactionChannel.online => 'online',
        TransactionChannel.mobileApp => 'mobile_app',
        TransactionChannel.ussd => 'ussd',
        TransactionChannel.agent => 'agent',
        TransactionChannel.api => 'api',
        TransactionChannel.callCenter => 'call_center',
      };
}

/// Mirrors the backend's `CustomerSegment` enum (monitoring/enums/customer-segment.enum.ts) —
/// used by Pan Studio rules to apply different thresholds per customer tier.
enum CustomerSegment { kyc1, kyc2, agent, superAgent, merchant, corporate }

extension on CustomerSegment {
  String get wireValue => switch (this) {
        CustomerSegment.kyc1 => 'KYC1',
        CustomerSegment.kyc2 => 'KYC2',
        CustomerSegment.agent => 'AGENT',
        CustomerSegment.superAgent => 'SUPER_AGENT',
        CustomerSegment.merchant => 'MERCHANT',
        CustomerSegment.corporate => 'CORPORATE',
      };
}

class TransactionInput {
  final String externalTransactionId;
  final String externalCustomerId;

  /// The customer's display name, as you know it — self-declared, never verified by Protegey
  /// (same trust model as [isPep]). Shows up directly in the Pan Studio transactions table. Omit
  /// to reuse whatever name you sent on a previous transaction for this customer — once sent,
  /// it's remembered and keeps showing on their later transactions too.
  final String? customerName;
  final TransactionDirection direction;
  final num amount;
  final String? currency;
  final String transactionType;
  final String? counterpartyExternalId;

  /// How this transaction was initiated — see [TransactionChannel].
  final TransactionChannel? channel;

  /// SWIFT/BIC or a local bank/MNO code for the counterparty's institution — bank-wire and
  /// cross-institution mobile-money scenarios. Free-form: no single format fits every network.
  final String? counterpartyInstitutionCode;

  /// The counterparty's country (ISO 3166-1 recommended, not enforced) — compare against your
  /// customer's own [country] in a Pan Studio rule to flag cross-border activity.
  final String? counterpartyCountry;
  final bool? isCash;

  /// Defaults to now if omitted.
  final DateTime? occurredAt;

  /// This customer's segment/tier — see [CustomerSegment].
  final CustomerSegment? segment;
  final String? country;
  final bool? isPep;

  /// Same device-intelligence fields as [ProtegeyDevice.identify] — pass them here too and
  /// Protegey folds the device signal into this transaction's own decision automatically.
  final String? visitorId;
  final DeviceAttributes? deviceAttributes;
  final String? devicePhoneNumber;

  /// When this customer's login password was last changed, if you track it — lets a Pan Studio
  /// rule flag a large transaction shortly after a credential change (a classic account-takeover
  /// pattern). Omit if unknown; the corresponding rule field then simply never fires — Protegey
  /// never guesses this.
  final DateTime? lastPasswordChangeAt;

  /// Same idea as [lastPasswordChangeAt], for the account's registered email address.
  final DateTime? lastEmailChangeAt;

  /// Same idea as [lastPasswordChangeAt], for the account's registered phone number — also
  /// covers a SIM swap for telcos, which is the same signal from your point of view.
  final DateTime? lastPhoneChangeAt;

  /// The account's balance immediately before this transaction, if you track it — lets a Pan
  /// Studio rule flag a withdrawal/transfer that drains most of the balance (a classic mule-
  /// account/account-drain signal). Only meaningful for a DEBIT. Omit if unknown.
  final num? accountBalanceBefore;

  const TransactionInput({
    required this.externalTransactionId,
    required this.externalCustomerId,
    this.customerName,
    required this.direction,
    required this.amount,
    this.currency,
    required this.transactionType,
    this.counterpartyExternalId,
    this.channel,
    this.counterpartyInstitutionCode,
    this.counterpartyCountry,
    this.isCash,
    this.occurredAt,
    this.segment,
    this.country,
    this.isPep,
    this.visitorId,
    this.deviceAttributes,
    this.devicePhoneNumber,
    this.lastPasswordChangeAt,
    this.lastEmailChangeAt,
    this.lastPhoneChangeAt,
    this.accountBalanceBefore,
  });

  Map<String, dynamic> toJson() => {
        'externalTransactionId': externalTransactionId,
        'externalCustomerId': externalCustomerId,
        if (customerName != null) 'customerName': customerName,
        'direction': direction.wireValue,
        'amount': amount,
        if (currency != null) 'currency': currency,
        'transactionType': transactionType,
        if (counterpartyExternalId != null) 'counterpartyExternalId': counterpartyExternalId,
        if (channel != null) 'channel': channel!.wireValue,
        if (counterpartyInstitutionCode != null) 'counterpartyInstitutionCode': counterpartyInstitutionCode,
        if (counterpartyCountry != null) 'counterpartyCountry': counterpartyCountry,
        if (isCash != null) 'isCash': isCash,
        'occurredAt': (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
        if (segment != null) 'segment': segment!.wireValue,
        if (country != null) 'country': country,
        if (isPep != null) 'isPep': isPep,
        if (visitorId != null) 'visitorId': visitorId,
        if (deviceAttributes != null) 'deviceAttributes': deviceAttributes!.toJson(),
        if (devicePhoneNumber != null) 'devicePhoneNumber': devicePhoneNumber,
        if (lastPasswordChangeAt != null) 'lastPasswordChangeAt': lastPasswordChangeAt!.toUtc().toIso8601String(),
        if (lastEmailChangeAt != null) 'lastEmailChangeAt': lastEmailChangeAt!.toUtc().toIso8601String(),
        if (lastPhoneChangeAt != null) 'lastPhoneChangeAt': lastPhoneChangeAt!.toUtc().toIso8601String(),
        if (accountBalanceBefore != null) 'accountBalanceBefore': accountBalanceBefore,
      };
}

class ReportTransactionResult {
  final String transactionId;

  /// 'CLEAR' | 'REVIEW' | 'BLOCKED'. If rule evaluation times out (3 s fail-safe) the backend
  /// answers 'REVIEW' with riskScore 50.
  final String decision;

  /// 0-100.
  final int riskScore;

  /// Raw alert objects as returned by the backend (`status` e.g. 'OPEN', `decisionVerdict`
  /// 'BLOCK' | 'STEP_UP' | 'ESCALATE' | 'ALERT' | null) — left untyped on purpose, since triaging
  /// alerts is a server-side job.
  final List<Map<String, dynamic>> alerts;
  final DeviceAction? deviceAction;

  const ReportTransactionResult({
    required this.transactionId,
    required this.decision,
    required this.riskScore,
    required this.alerts,
    required this.deviceAction,
  });

  factory ReportTransactionResult.fromJson(Map<String, dynamic> json) {
    return ReportTransactionResult(
      transactionId: json['transactionId'] as String,
      decision: json['decision'] as String,
      riskScore: (json['riskScore'] as num).toInt(),
      alerts: (json['alerts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      deviceAction: deviceActionFromWire(json['deviceAction'] as String?),
    );
  }
}

/// A page of results — the partner API's `{ data, total, page, limit, totalPages }` envelope.
class ProtegeyPage<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ProtegeyPage({required this.data, required this.total, required this.page, required this.limit, required this.totalPages});

  factory ProtegeyPage.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    return ProtegeyPage(
      data: (json['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().map(parse).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Thrown for any non-2xx response from the Protegey API.
class ProtegeyApiException implements Exception {
  final int status;
  final String message;

  /// Machine-readable code when the backend sends one — currently 'PARTNER_SUSPENDED' or
  /// 'PARTNER_CONTRACT_REQUIRED' (both 403, mutating calls only). Null otherwise.
  final String? errorCode;

  const ProtegeyApiException(this.status, this.message, {this.errorCode});

  @override
  String toString() => 'ProtegeyApiException($status${errorCode != null ? ', $errorCode' : ''}): $message';
}
