import 'client.dart';

class StartKycSessionResult {
  final String sessionId;

  /// Hosted verification link — send it to your user however you like (SMS, email, in-app).
  final String url;

  const StartKycSessionResult({required this.sessionId, required this.url});

  factory StartKycSessionResult.fromJson(Map<String, dynamic> json) {
    return StartKycSessionResult(sessionId: json['sessionId'] as String, url: json['url'] as String);
  }
}

/// 'success' = confident match, auto-approved. 'manual' = FaceTec's hard checks (liveness, ID
/// scan) passed but the match confidence was below the configurable auto-approve threshold (80%
/// by default) — a human needs to review it; reported as session status 'In Review'. 'failed' = a
/// hard check itself failed (liveness never proven, ID scan failed, or no face match at all);
/// reported as session status 'Declined'. `unknown` before a FaceTec result has come back yet, or
/// for a status value this SDK version doesn't recognize.
enum KycOutcome { success, manual, failed, unknown }

KycOutcome _kycOutcomeFromJson(String? value) {
  switch (value) {
    case 'SUCCESS':
      return KycOutcome.success;
    case 'MANUAL':
      return KycOutcome.manual;
    case 'FAILED':
      return KycOutcome.failed;
    default:
      return KycOutcome.unknown;
  }
}

/// Same shape as the outbound KYC webhook payload, minus eventId — returned by
/// [KycModule.getSession], the webhook polling fallback: delivery is best-effort (one retry, no
/// queue), so this is the only way to be certain of a session's current status.
class KycSessionStatus {
  final String sessionId;
  final String? externalUserId;
  final String status;

  /// Typed convenience mirror of decision['outcome'] — see [KycOutcome].
  final KycOutcome outcome;
  final Map<String, dynamic>? decision;

  const KycSessionStatus({
    required this.sessionId,
    required this.externalUserId,
    required this.status,
    required this.outcome,
    required this.decision,
  });

  factory KycSessionStatus.fromJson(Map<String, dynamic> json) {
    return KycSessionStatus(
      sessionId: json['sessionId'] as String,
      externalUserId: json['externalUserId'] as String?,
      status: json['status'] as String,
      outcome: _kycOutcomeFromJson(json['outcome'] as String?),
      decision: json['decision'] as Map<String, dynamic>?,
    );
  }
}

class KycModule {
  final ProtegeyHttpClient _http;

  KycModule(this._http);

  /// Starts an identity verification session for one of your end users — no manual API call needed.
  Future<StartKycSessionResult> startSession({required String externalUserId}) async {
    final response = await _http.post('/partner-api/kyc/sessions', {'externalUserId': externalUserId});
    return StartKycSessionResult.fromJson(response);
  }

  /// Polling fallback for the webhook — call this if you're not sure a webhook delivery ever
  /// arrived (best-effort: one retry, no queue). [sessionId] is the value returned by [startSession].
  Future<KycSessionStatus> getSession(String sessionId) async {
    final response = await _http.get('/partner-api/kyc/sessions/${Uri.encodeComponent(sessionId)}');
    return KycSessionStatus.fromJson(response);
  }
}
