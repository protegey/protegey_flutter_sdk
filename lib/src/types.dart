/// Mirrors the backend's DeviceAttributesDto — a closed, all-optional list. Keep in sync with
/// protegey-backend/src/keverd/dto/device-attributes.dto.ts.
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
      };
}

enum DeviceAction { allow, softChallenge, hardChallenge, block }

DeviceAction? deviceActionFromWire(String? value) {
  switch (value) {
    case 'allow':
      return DeviceAction.allow;
    case 'soft_challenge':
      return DeviceAction.softChallenge;
    case 'hard_challenge':
      return DeviceAction.hardChallenge;
    case 'block':
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

class TransactionInput {
  final String externalTransactionId;
  final String externalCustomerId;
  final TransactionDirection direction;
  final num amount;
  final String? currency;
  final String transactionType;
  final String? counterpartyExternalId;
  final bool? isCash;

  /// Defaults to now if omitted.
  final DateTime? occurredAt;
  final String? segment;
  final String? country;
  final bool? isPep;

  /// Same device-intelligence fields as [ProtegeyDevice.identify] — pass them here too and
  /// Protegey folds the device signal into this transaction's own decision automatically.
  final String? visitorId;
  final DeviceAttributes? deviceAttributes;
  final String? devicePhoneNumber;

  const TransactionInput({
    required this.externalTransactionId,
    required this.externalCustomerId,
    required this.direction,
    required this.amount,
    this.currency,
    required this.transactionType,
    this.counterpartyExternalId,
    this.isCash,
    this.occurredAt,
    this.segment,
    this.country,
    this.isPep,
    this.visitorId,
    this.deviceAttributes,
    this.devicePhoneNumber,
  });

  Map<String, dynamic> toJson() => {
        'externalTransactionId': externalTransactionId,
        'externalCustomerId': externalCustomerId,
        'direction': direction.wireValue,
        'amount': amount,
        if (currency != null) 'currency': currency,
        'transactionType': transactionType,
        if (counterpartyExternalId != null) 'counterpartyExternalId': counterpartyExternalId,
        if (isCash != null) 'isCash': isCash,
        'occurredAt': (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
        if (segment != null) 'segment': segment,
        if (country != null) 'country': country,
        if (isPep != null) 'isPep': isPep,
        if (visitorId != null) 'visitorId': visitorId,
        if (deviceAttributes != null) 'deviceAttributes': deviceAttributes!.toJson(),
        if (devicePhoneNumber != null) 'devicePhoneNumber': devicePhoneNumber,
      };
}

class ReportTransactionResult {
  final String transactionId;
  final String decision;
  final int riskScore;
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
      riskScore: json['riskScore'] as int,
      alerts: (json['alerts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      deviceAction: deviceActionFromWire(json['deviceAction'] as String?),
    );
  }
}

/// Thrown for any non-2xx response from the Protegey API.
class ProtegeyApiException implements Exception {
  final int status;
  final String message;

  const ProtegeyApiException(this.status, this.message);

  @override
  String toString() => 'ProtegeyApiException($status): $message';
}
