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
/// by default) — a human needs to review it; reported as session status 'IN_REVIEW'. 'failed' = a
/// hard check itself failed (liveness never proven, ID scan failed, or no face match at all);
/// reported as session status 'DECLINED'. `unknown` before a FaceTec result has come back yet, or
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

  /// The verified user's full name, as read off their scanned ID document — null until FaceTec
  /// has produced a result.
  final String? fullName;

  /// The scanned document's type (e.g. national ID, passport), as FaceTec identified it — null
  /// until a result is available.
  final String? documentType;

  /// ISO-3166 alpha-2 country, extracted from the FaceTec decision once available.
  final String? country;

  /// 0-100 liveness-check score, once available.
  final double? livenessScore;

  /// 0-100 face-match score — selfie vs. ID portrait similarity — once available.
  final double? faceMatchScore;

  /// Base64-encoded image of the scanned ID document's front, once available. Sensitive —
  /// handle like any other government-ID photo.
  final String? documentPhoto;

  /// Base64-encoded image of the scanned ID document's back, when the document type has one
  /// (e.g. a national ID card; a passport has none).
  final String? documentBackPhoto;

  /// Base64-encoded selfie/liveness capture image, once available. Sensitive biometric data.
  final String? selfiePhoto;

  /// Base64-encoded face crop taken directly from the ID document's own printed photo —
  /// distinct from [documentPhoto] (the whole front of the card) and [selfiePhoto] (the live
  /// face captured during liveness).
  final String? documentFaceCrop;

  const KycSessionStatus({
    required this.sessionId,
    required this.externalUserId,
    required this.status,
    required this.outcome,
    required this.decision,
    this.fullName,
    this.documentType,
    this.country,
    this.livenessScore,
    this.faceMatchScore,
    this.documentPhoto,
    this.documentBackPhoto,
    this.selfiePhoto,
    this.documentFaceCrop,
  });

  factory KycSessionStatus.fromJson(Map<String, dynamic> json) {
    return KycSessionStatus(
      sessionId: json['sessionId'] as String,
      externalUserId: json['externalUserId'] as String?,
      status: json['status'] as String,
      outcome: _kycOutcomeFromJson(json['outcome'] as String?),
      decision: json['decision'] as Map<String, dynamic>?,
      fullName: json['fullName'] as String?,
      documentType: json['documentType'] as String?,
      country: json['country'] as String?,
      livenessScore: (json['livenessScore'] as num?)?.toDouble(),
      faceMatchScore: (json['faceMatchScore'] as num?)?.toDouble(),
      documentPhoto: json['documentPhoto'] as String?,
      documentBackPhoto: json['documentBackPhoto'] as String?,
      selfiePhoto: json['selfiePhoto'] as String?,
      documentFaceCrop: json['documentFaceCrop'] as String?,
    );
  }
}

class KycModule {
  final ProtegeyHttpClient _http;

  KycModule(this._http);

  /// Starts an identity verification session for one of your end users — no manual API call needed.
  ///
  /// [email] and [phone] are never Protegey-verified — trusted as given, same model as Pan
  /// Studio's self-reported fields — and feed identity-resolution's cross-partner matching. Omit
  /// either if unknown.
  Future<StartKycSessionResult> startSession({required String externalUserId, String? email, String? phone}) async {
    final response = await _http.post('/partner-api/kyc/sessions', {
      'externalUserId': externalUserId,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    });
    return StartKycSessionResult.fromJson(response);
  }

  /// Polling fallback for the webhook — call this if you're not sure a webhook delivery ever
  /// arrived (best-effort: one retry, no queue). [sessionId] is the value returned by [startSession].
  Future<KycSessionStatus> getSession(String sessionId) async {
    final response = await _http.get('/partner-api/kyc/sessions/${Uri.encodeComponent(sessionId)}');
    return KycSessionStatus.fromJson(response);
  }
}
