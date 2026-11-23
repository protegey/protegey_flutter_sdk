import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'client.dart';
import 'types.dart';

/// Error code of a re-verification requested for someone with no 3D record from KYC — see
/// [LivenessModule.startReverification].
const String no3dEnrollmentErrorCode = 'NO_3D_ENROLLMENT';

/// 'LIVENESS': a selfie-only 3D liveness check. 'REVERIFICATION': a 3D liveness check, then a
/// 3D:3D match against the face enrolled during the person's KYC verification.
enum LivenessMode { liveness, reverification }

LivenessMode _modeFromJson(Object? value) => value == 'REVERIFICATION' ? LivenessMode.reverification : LivenessMode.liveness;

class StartLivenessSessionResult {
  final String sessionId;

  /// Hosted capture link — single-use, valid for 30 minutes. Open it yourself, or let
  /// [ProtegeyLivenessPresentation.presentLiveness] / `presentReverification` show it.
  final String url;
  final LivenessMode mode;

  const StartLivenessSessionResult({required this.sessionId, required this.url, required this.mode});

  factory StartLivenessSessionResult.fromJson(Map<String, dynamic> json) {
    return StartLivenessSessionResult(
      sessionId: json['sessionId'] as String,
      url: (json['url'] ?? json['captureUrl']) as String,
      mode: _modeFromJson(json['mode']),
    );
  }
}

/// A 3D liveness session — the separate, paid product (KYC verifications are not these).
class LivenessSession {
  final String sessionId;
  final LivenessMode mode;

  /// 'PENDING' (waiting for the person; also after an inconclusive scan, which they can retry),
  /// 'COMPLETED' or 'EXPIRED'.
  final String status;
  final String? externalUserId;

  /// Null until a scan was evaluated. True: a real, live person was in front of the camera.
  final bool? livenessProven;

  /// Re-verification only: whether the face is the same person as their KYC verification (3D:3D
  /// match). Null for a plain liveness check, or before a result.
  final bool? matched;

  /// Re-verification only: the 3D:3D match level (0 = different person, 15 = same person).
  final int? matchLevel;

  /// The KYC verification (session id) the face was matched against — re-verification only.
  final String? referenceEnrollmentId;

  /// Reserved — not populated at the moment (always null).
  final List<String>? duplicateFaceEnrollmentIds;
  final int attempts;

  /// How many of this session's checks are billed, and the billed amount (USD, as a string).
  final int billableChecks;
  final String amount;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const LivenessSession({
    required this.sessionId,
    required this.mode,
    required this.status,
    this.externalUserId,
    this.livenessProven,
    this.matched,
    this.matchLevel,
    this.referenceEnrollmentId,
    this.duplicateFaceEnrollmentIds,
    this.attempts = 0,
    this.billableChecks = 0,
    this.amount = '0.00',
    this.createdAt,
    this.completedAt,
  });

  bool get isFinished => status == 'COMPLETED' || status == 'EXPIRED';

  factory LivenessSession.fromJson(Map<String, dynamic> json) {
    return LivenessSession(
      sessionId: (json['sessionId'] ?? json['id']) as String,
      mode: _modeFromJson(json['mode']),
      status: json['status'] as String,
      externalUserId: json['externalUserId'] as String?,
      livenessProven: json['livenessProven'] as bool?,
      matched: json['matched'] as bool?,
      matchLevel: (json['matchLevel'] as num?)?.toInt(),
      referenceEnrollmentId: json['referenceEnrollmentId'] as String?,
      duplicateFaceEnrollmentIds: (json['duplicateFaceEnrollmentIds'] as List?)?.cast<String>(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      billableChecks: (json['billableChecks'] as num?)?.toInt() ?? 0,
      amount: json['amount']?.toString() ?? '0.00',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
    );
  }
}

/// 3D liveness — a selfie-only check that a real, live person is in front of the camera, or a
/// re-verification that a returning customer is the same person as their KYC verification. Billed
/// per proven check; separate from [KycModule] (KYC is unaffected).
class LivenessModule {
  final ProtegeyHttpClient _http;

  LivenessModule(this._http);

  /// Starts a selfie-only 3D liveness check. [externalUserId] is optional — your own id for the person.
  Future<StartLivenessSessionResult> startSession({String? externalUserId}) async {
    final response = await _http.post('/partner-api/liveness/sessions', {
      'mode': 'LIVENESS',
      if (externalUserId != null) 'externalUserId': externalUserId,
    });
    return StartLivenessSessionResult.fromJson(response);
  }

  /// Starts a re-verification of a customer you already verified with KYC — matched against the
  /// face from their latest KYC verification under [externalUserId]. Throws a
  /// `ProtegeyApiException` with `errorCode == 'NO_3D_ENROLLMENT'` ([no3dEnrollmentErrorCode]) when
  /// no 3D record (KYC) exists for that person.
  Future<StartLivenessSessionResult> startReverification({required String externalUserId}) async {
    final response = await _http.post('/partner-api/liveness/sessions', {'mode': 'REVERIFICATION', 'externalUserId': externalUserId});
    return StartLivenessSessionResult.fromJson(response);
  }

  Future<LivenessSession> getSession(String sessionId) async {
    final response = await _http.get('/partner-api/liveness/sessions/${Uri.encodeComponent(sessionId)}');
    return LivenessSession.fromJson(response);
  }

  Future<ProtegeyPage<LivenessSession>> listSessions({String? externalUserId, LivenessMode? mode, int? page, int? limit}) async {
    final response = await _http.get('/partner-api/liveness/sessions', query: {
      'externalUserId': externalUserId,
      'mode': mode == null ? null : (mode == LivenessMode.reverification ? 'REVERIFICATION' : 'LIVENESS'),
      'page': page,
      'limit': limit,
    });
    return ProtegeyPage.fromJson(response, LivenessSession.fromJson);
  }
}

const _autoCloseDelay = Duration(seconds: 4);

/// Shows the hosted capture page in a bottom sheet and polls the session until it finishes —
/// same presentation as `presentVerification` for KYC.
extension ProtegeyLivenessPresentation on LivenessModule {
  /// Runs a selfie-only 3D liveness check. Returns the session as last seen (null if the sheet was
  /// closed before any status was read).
  Future<LivenessSession?> presentLiveness(BuildContext context, {String? externalUserId}) async {
    final session = await startSession(externalUserId: externalUserId);
    if (!context.mounted) return null;
    return _present(context, session);
  }

  /// Runs a re-verification of [externalUserId] against their KYC face. Throws a
  /// `ProtegeyApiException` with errorCode 'NO_3D_ENROLLMENT' when they have no KYC face on file.
  Future<LivenessSession?> presentReverification(BuildContext context, {required String externalUserId}) async {
    final session = await startReverification(externalUserId: externalUserId);
    if (!context.mounted) return null;
    return _present(context, session);
  }

  Future<LivenessSession?> _present(BuildContext context, StartLivenessSessionResult session) async {
    LivenessSession? last;
    Timer? autoCloseTimer;
    final maxHeight = MediaQuery.of(context).size.height * 0.95;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (sheetContext) => _LivenessSheet(
        liveness: this,
        sessionId: session.sessionId,
        url: session.url,
        title: session.mode == LivenessMode.reverification ? 'Re-verifying your identity…' : 'Checking your face…',
        onUpdate: (status) {
          last = status;
          if (status.isFinished && autoCloseTimer == null) {
            autoCloseTimer = Timer(_autoCloseDelay, () {
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            });
          }
        },
      ),
    );
    autoCloseTimer?.cancel();
    return last ?? await getSession(session.sessionId).catchError((Object _) => LivenessSession(sessionId: session.sessionId, mode: session.mode, status: 'PENDING'));
  }
}

class _LivenessSheet extends StatefulWidget {
  final LivenessModule liveness;
  final String sessionId;
  final String url;
  final String title;
  final void Function(LivenessSession status) onUpdate;

  const _LivenessSheet({required this.liveness, required this.sessionId, required this.url, required this.title, required this.onUpdate});

  @override
  State<_LivenessSheet> createState() => _LivenessSheetState();
}

class _LivenessSheetState extends State<_LivenessSheet> {
  late final WebViewController _controller;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
    // Camera access for our own capture page (webview_flutter denies it by default).
    _controller.platform.setOnPlatformPermissionRequest((request) => request.grant());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      widget.onUpdate(await widget.liveness.getSession(widget.sessionId));
    } catch (_) {
      // Transient network error — next tick retries.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
