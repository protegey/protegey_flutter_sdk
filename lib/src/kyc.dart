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

/// Same shape as the outbound KYC webhook payload, minus eventId — returned by
/// [KycModule.getSession], the webhook polling fallback: delivery is best-effort (one retry, no
/// queue), so this is the only way to be certain of a session's current status.
class KycSessionStatus {
  final String sessionId;
  final String? externalUserId;
  final String status;
  final Map<String, dynamic>? decision;

  const KycSessionStatus({required this.sessionId, required this.externalUserId, required this.status, required this.decision});

  factory KycSessionStatus.fromJson(Map<String, dynamic> json) {
    return KycSessionStatus(
      sessionId: json['sessionId'] as String,
      externalUserId: json['externalUserId'] as String?,
      status: json['status'] as String,
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
