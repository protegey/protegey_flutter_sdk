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

class KycModule {
  final ProtegeyHttpClient _http;

  KycModule(this._http);

  /// Starts an identity verification session for one of your end users — no manual API call needed.
  Future<StartKycSessionResult> startSession({required String externalUserId}) async {
    final response = await _http.post('/partner-api/kyc/sessions', {'externalUserId': externalUserId});
    return StartKycSessionResult.fromJson(response);
  }
}
