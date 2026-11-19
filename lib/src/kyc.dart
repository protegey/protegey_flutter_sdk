import 'client.dart';
import 'types.dart';

class StartKycSessionResult {
  final String sessionId;

  /// Hosted Protegey identity verification link — single-use, valid for 30 minutes. Send it to your user however
  /// you like (SMS, email, in-app), or let `presentVerification()` open it.
  final String url;

  const StartKycSessionResult({required this.sessionId, required this.url});

  factory StartKycSessionResult.fromJson(Map<String, dynamic> json) {
    return StartKycSessionResult(sessionId: json['sessionId'] as String, url: json['url'] as String);
  }
}

/// 'success' = confident match, auto-approved. 'manual' = the hard checks (liveness, ID
/// scan) passed but the match confidence was below the configurable auto-approve threshold (80%
/// by default) — a human needs to review it; reported as session status 'IN_REVIEW'. 'failed' = a
/// hard check itself failed (liveness never proven, ID scan failed, or no face match at all);
/// reported as session status 'DECLINED'. `unknown` before a verification result has come back yet, or
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

/// Protegey's own verdict on a session, from the automated verification result: [approve] (outcome SUCCESS),
/// [review] (MANUAL), [reject] (FAILED). It never changes after a manual override — the session's
/// `status` is the final decision, this is what Protegey recommended. Null on the wire (and
/// `null` here) before a verification result exists.
enum KycRecommendation { approve, review, reject }

KycRecommendation? _kycRecommendationFromJson(Object? value) {
  switch (value) {
    case 'APPROVE':
      return KycRecommendation.approve;
    case 'REVIEW':
      return KycRecommendation.review;
    case 'REJECT':
      return KycRecommendation.reject;
    default:
      return null;
  }
}

/// A pre-signed S3 link to one KYC photo. Valid 1 hour ([expiresAt]); every GET on the session
/// (or the list) issues fresh links, so fetch the session again rather than storing [url].
class KycImage {
  final String url;
  final DateTime expiresAt;

  const KycImage({required this.url, required this.expiresAt});

  static KycImage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = json['url'];
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    if (url is! String || expiresAt == null) return null;
    return KycImage(url: url, expiresAt: expiresAt);
  }
}

/// The session's `images` block. Each photo is null when it doesn't exist (e.g. no back side on a
/// passport), was anonymized, or couldn't be signed.
class KycImages {
  final KycImage? documentFront;
  final KycImage? documentBack;
  final KycImage? selfie;
  final KycImage? documentFaceCrop;

  const KycImages({this.documentFront, this.documentBack, this.selfie, this.documentFaceCrop});

  static KycImages? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return KycImages(
      documentFront: KycImage.fromJson(json['documentFront']),
      documentBack: KycImage.fromJson(json['documentBack']),
      selfie: KycImage.fromJson(json['selfie']),
      documentFaceCrop: KycImage.fromJson(json['documentFaceCrop']),
    );
  }
}

/// Status values accepted by [KycModule.updateSession].
enum KycReviewStatus { approved, declined, inReview }

extension on KycReviewStatus {
  String get wireValue => switch (this) {
        KycReviewStatus.approved => 'APPROVED',
        KycReviewStatus.declined => 'DECLINED',
        KycReviewStatus.inReview => 'IN_REVIEW',
      };
}

/// Returned by [KycModule.getSession] (the polling fallback for the `kyc.status_changed` webhook)
/// and [KycModule.updateSession] (which fills only the identity/status fields, no scores or
/// photos). The webhook is retried up to 5 times over ~3 h and also fires on manual status
/// changes; its `sessionId` is this same [sessionId]. Polling stays the way to be certain of a
/// session's current status.
class KycSessionStatus {
  final String sessionId;
  final String? externalUserId;

  /// UPPER_SNAKE_CASE on the wire: 'NOT_STARTED' | 'IN_PROGRESS' | 'AWAITING_USER' | 'IN_REVIEW' |
  /// 'APPROVED' | 'DECLINED' | 'RESUBMITTED' | 'ABANDONED' | 'EXPIRED' | 'KYC_EXPIRED'. In practice
  /// a verification session goes IN_PROGRESS → APPROVED / IN_REVIEW / DECLINED.
  final String status;

  /// Typed mirror of the response's top-level `outcome` — see [KycOutcome]. A manual review
  /// override keeps the original outcome, so this can stay [KycOutcome.manual] while [status] is
  /// 'APPROVED'.
  final KycOutcome outcome;

  /// Protegey's recommendation — see [KycRecommendation]. [status] is the final decision (it can
  /// differ after a manual override); this never changes.
  final KycRecommendation? recommendation;

  /// The verification decision blob. A manual override adds `decision['manualReview']`
  /// (`reviewedBy`, `reviewedAt`, `previousStatus`, `newStatus` — both UPPER_SNAKE_CASE — and `note`).
  final Map<String, dynamic>? decision;

  /// The verified user's full name, as read off their scanned ID document — null until the
  /// verification has produced a result.
  final String? fullName;

  /// The scanned document's type (e.g. national ID, passport), as identified during verification — null
  /// until a result is available.
  final String? documentType;

  /// ISO-3166 alpha-2 country, extracted from the verification decision once available.
  final String? country;

  /// 0-100 liveness-check score, once available.
  final double? livenessScore;

  /// 0-100 face-match score — selfie vs. ID portrait similarity — once available.
  final double? faceMatchScore;

  /// Pre-signed photo links (1 hour, re-issued on every GET) — prefer these over the base64
  /// fields below, which are kept for backward compatibility. Null when the response has no
  /// `images` block (e.g. [KycModule.updateSession]).
  final KycImages? images;

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
    this.recommendation,
    required this.decision,
    this.fullName,
    this.documentType,
    this.country,
    this.livenessScore,
    this.faceMatchScore,
    this.images,
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
      recommendation: _kycRecommendationFromJson(json['recommendation']),
      decision: json['decision'] as Map<String, dynamic>?,
      fullName: json['fullName'] as String?,
      documentType: json['documentType'] as String?,
      country: json['country'] as String?,
      livenessScore: (json['livenessScore'] as num?)?.toDouble(),
      faceMatchScore: (json['faceMatchScore'] as num?)?.toDouble(),
      images: KycImages.fromJson(json['images']),
      documentPhoto: json['documentPhoto'] as String?,
      documentBackPhoto: json['documentBackPhoto'] as String?,
      selfiePhoto: json['selfiePhoto'] as String?,
      documentFaceCrop: json['documentFaceCrop'] as String?,
    );
  }
}

/// One row of [KycModule.listSessions] — no scores, no base64 photos, only pre-signed [images].
class KycSessionSummary {
  final String sessionId;
  final String? externalUserId;

  /// UPPER_SNAKE_CASE, same values as [KycSessionStatus.status].
  final String status;
  final KycOutcome outcome;
  final KycRecommendation? recommendation;
  final String? fullName;
  final String? documentType;
  final String? country;
  final DateTime? createdAt;
  final KycImages? images;

  const KycSessionSummary({
    required this.sessionId,
    required this.externalUserId,
    required this.status,
    required this.outcome,
    this.recommendation,
    this.fullName,
    this.documentType,
    this.country,
    this.createdAt,
    this.images,
  });

  factory KycSessionSummary.fromJson(Map<String, dynamic> json) {
    return KycSessionSummary(
      sessionId: json['sessionId'] as String,
      externalUserId: json['externalUserId'] as String?,
      status: json['status'] as String,
      outcome: _kycOutcomeFromJson(json['outcome'] as String?),
      recommendation: _kycRecommendationFromJson(json['recommendation']),
      fullName: json['fullName'] as String?,
      documentType: json['documentType'] as String?,
      country: json['country'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      images: KycImages.fromJson(json['images']),
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
  /// arrived. [sessionId] is the value returned by [startSession]. Throws a 404
  /// `ProtegeyApiException` for an unknown session.
  Future<KycSessionStatus> getSession(String sessionId) async {
    final response = await _http.get('/partner-api/kyc/sessions/${Uri.encodeComponent(sessionId)}');
    return KycSessionStatus.fromJson(response);
  }

  /// Paginated list of your KYC sessions, newest first. [externalUserId] is an exact,
  /// case-sensitive match on your own id (use it to find a customer's sessions); [search] is a
  /// partial match on name or external id; [status] accepts the UPPER_SNAKE_CASE values the API
  /// returns (e.g. 'IN_REVIEW'). [limit] is capped at 100 by the backend.
  Future<ProtegeyPage<KycSessionSummary>> listSessions({
    String? externalUserId,
    String? status,
    String? search,
    int? page,
    int? limit,
  }) async {
    final response = await _http.get('/partner-api/kyc/sessions', query: {
      'externalUserId': externalUserId,
      'status': status,
      'search': search,
      'page': page,
      'limit': limit,
    });
    return ProtegeyPage.fromJson(response, KycSessionSummary.fromJson);
  }

  /// Overrides a session's status (e.g. resolves an IN_REVIEW session) with an optional
  /// [reviewNote] for the audit trail — recorded as `decision.manualReview`, actor 'Partner API'.
  /// Triggers a `kyc.status_changed` webhook. A review decision is a back-office job: in
  /// production call this from your backend, not from a shipped app.
  Future<KycSessionStatus> updateSession(String sessionId, {KycReviewStatus? status, String? reviewNote}) async {
    final response = await _http.patch('/partner-api/kyc/sessions/${Uri.encodeComponent(sessionId)}', {
      if (status != null) 'status': status.wireValue,
      if (reviewNote != null) 'reviewNote': reviewNote,
    });
    return KycSessionStatus.fromJson(response);
  }
}
