import 'client.dart';

/// Aggregated timing/gesture metadata only — never raw keystrokes/content. All fields optional:
/// send whatever your app captured for this session. Mirrors the backend's KeystrokeMetricsDto.
class KeystrokeMetrics {
  final double? avgHoldTimeMs;
  final double? avgInterKeyLatencyMs;
  final double? typingSpeedCharsPerSec;
  final double? errorRate;

  const KeystrokeMetrics({this.avgHoldTimeMs, this.avgInterKeyLatencyMs, this.typingSpeedCharsPerSec, this.errorRate});

  Map<String, dynamic> toJson() => {
        if (avgHoldTimeMs != null) 'avgHoldTimeMs': avgHoldTimeMs,
        if (avgInterKeyLatencyMs != null) 'avgInterKeyLatencyMs': avgInterKeyLatencyMs,
        if (typingSpeedCharsPerSec != null) 'typingSpeedCharsPerSec': typingSpeedCharsPerSec,
        if (errorRate != null) 'errorRate': errorRate,
      };
}

class TouchMetrics {
  final double? avgTapPressure;
  final double? avgSwipeVelocity;
  final double? scrollBehaviorScore;
  final double? mouseAcceleration;

  const TouchMetrics({this.avgTapPressure, this.avgSwipeVelocity, this.scrollBehaviorScore, this.mouseAcceleration});

  Map<String, dynamic> toJson() => {
        if (avgTapPressure != null) 'avgTapPressure': avgTapPressure,
        if (avgSwipeVelocity != null) 'avgSwipeVelocity': avgSwipeVelocity,
        if (scrollBehaviorScore != null) 'scrollBehaviorScore': scrollBehaviorScore,
        if (mouseAcceleration != null) 'mouseAcceleration': mouseAcceleration,
      };
}

class NavigationMetrics {
  /// Ordered screen/action identifiers for this session's task, e.g. ['login','dashboard','transfer','confirm'].
  final List<String>? screenSequence;

  const NavigationMetrics({this.screenSequence});

  Map<String, dynamic> toJson() => {
        if (screenSequence != null) 'screenSequence': screenSequence,
      };
}

class SessionMetrics {
  final int? loginHourBucket;
  final int? loginDayOfWeek;
  final double? sessionDurationMs;

  const SessionMetrics({this.loginHourBucket, this.loginDayOfWeek, this.sessionDurationMs});

  Map<String, dynamic> toJson() => {
        if (loginHourBucket != null) 'loginHourBucket': loginHourBucket,
        if (loginDayOfWeek != null) 'loginDayOfWeek': loginDayOfWeek,
        if (sessionDurationMs != null) 'sessionDurationMs': sessionDurationMs,
      };
}

class ReportBehavioralEventInput {
  final String externalCustomerId;

  /// Groups the metrics you send across one task/session — reuse the same id across calls for the same session.
  final String sessionId;
  final KeystrokeMetrics? keystroke;
  final TouchMetrics? touch;
  final NavigationMetrics? navigation;
  final SessionMetrics? session;

  const ReportBehavioralEventInput({
    required this.externalCustomerId,
    required this.sessionId,
    this.keystroke,
    this.touch,
    this.navigation,
    this.session,
  });

  Map<String, dynamic> toJson() => {
        'externalCustomerId': externalCustomerId,
        'sessionId': sessionId,
        if (keystroke != null) 'keystroke': keystroke!.toJson(),
        if (touch != null) 'touch': touch!.toJson(),
        if (navigation != null) 'navigation': navigation!.toJson(),
        if (session != null) 'session': session!.toJson(),
      };
}

enum BehavioralConfidenceTier { low, medium, high }

BehavioralConfidenceTier? _confidenceTierFromWire(String? value) {
  switch (value) {
    case 'low':
      return BehavioralConfidenceTier.low;
    case 'medium':
      return BehavioralConfidenceTier.medium;
    case 'high':
      return BehavioralConfidenceTier.high;
    default:
      return null;
  }
}

class ReportBehavioralEventResult {
  /// "learning": not enough history for this customer yet — no score, keep sending sessions.
  final String status;
  final int deviationScore;
  final BehavioralConfidenceTier? confidenceTier;
  final bool stepUpRecommended;
  final String? escalatedAlertId;

  const ReportBehavioralEventResult({
    required this.status,
    required this.deviationScore,
    required this.confidenceTier,
    required this.stepUpRecommended,
    required this.escalatedAlertId,
  });

  factory ReportBehavioralEventResult.fromJson(Map<String, dynamic> json) {
    return ReportBehavioralEventResult(
      status: json['status'] as String,
      deviationScore: json['deviationScore'] as int,
      confidenceTier: _confidenceTierFromWire(json['confidenceTier'] as String?),
      stepUpRecommended: json['stepUpRecommended'] as bool,
      escalatedAlertId: json['escalatedAlertId'] as String?,
    );
  }
}

class BehavioralModule {
  final ProtegeyHttpClient _http;

  BehavioralModule(this._http);

  /// Reports one session's aggregated keystroke/touch/navigation/session metadata. The first few
  /// sessions for a customer come back as "learning" (no score yet) while Protegey builds their
  /// baseline — this is expected, not an error.
  Future<ReportBehavioralEventResult> report(ReportBehavioralEventInput input) async {
    final response = await _http.post('/partner-api/behavioral-events', input.toJson());
    return ReportBehavioralEventResult.fromJson(response);
  }
}
