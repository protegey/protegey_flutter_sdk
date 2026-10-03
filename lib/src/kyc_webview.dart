import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'kyc.dart';

/// Shows the Didit-hosted KYC flow inside the host app — the end user never leaves the partner's
/// app. Didit is a third party Protegey doesn't control the completion redirect of, so this
/// doesn't watch navigation: it polls [KycModule.getSession] in the background (the same
/// best-effort polling fallback [KycModule] already documents) and reports every status change via
/// [onStatusChange]. The host app decides what counts as "done" (e.g. the first non-"pending"
/// status) and pops this view itself — it's a bare widget with no AppBar/Scaffold of its own, so
/// the host controls its own chrome (title, close button, back behavior).
class ProtegeyKycView extends StatefulWidget {
  final KycModule kyc;
  final String sessionId;
  final String url;
  final void Function(KycSessionStatus status) onStatusChange;
  final Duration pollInterval;

  const ProtegeyKycView({
    super.key,
    required this.kyc,
    required this.sessionId,
    required this.url,
    required this.onStatusChange,
    this.pollInterval = const Duration(seconds: 3),
  });

  @override
  State<ProtegeyKycView> createState() => _ProtegeyKycViewState();
}

class _ProtegeyKycViewState extends State<ProtegeyKycView> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final status = await widget.kyc.getSession(widget.sessionId);
      if (status.status != _lastStatus) {
        _lastStatus = status.status;
        widget.onStatusChange(status);
      }
    } catch (_) {
      // Transient network error — next tick retries, same best-effort spirit as the rest of the
      // SDK's polling fallback.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

/// The one-call integration: starts a session and shows it in a draggable bottom sheet — no UI
/// code needed on your end. The sheet has a drag handle and a Close button (swipe down or tap it
/// to back out at any point); it auto-dismisses itself on the first non-pending status. Returns
/// that final status, or `null` if the user closed the sheet before one arrived.
///
/// Prefer this for the common case. Reach for [ProtegeyKycView] directly only if you need a
/// different presentation (e.g. a full page instead of a sheet) or want to drive the polling UI
/// yourself.
extension ProtegeyKycPresentation on KycModule {
  Future<KycSessionStatus?> presentVerification(BuildContext context, {required String externalUserId}) async {
    final session = await startSession(externalUserId: externalUserId);
    KycSessionStatus? finalStatus;

    if (!context.mounted) return null;
    // isScrollControlled alone doesn't reliably cap the sheet's height on every platform — on
    // Android it was observed covering the full screen instead of leaving the app visible
    // underneath. Setting `constraints` directly on the sheet (not just on a child widget) is the
    // approach that holds across platforms.
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (sheetContext) => _ProtegeyKycSheet(
        kyc: this,
        sessionId: session.sessionId,
        url: session.url,
        onStatusChange: (status) {
          finalStatus = status;
          if (status.status != 'pending' && status.status != 'Not Started') {
            Navigator.pop(sheetContext); // done — closes the sheet on its own
          }
        },
      ),
    );

    return finalStatus;
  }
}

class _ProtegeyKycSheet extends StatelessWidget {
  final KycModule kyc;
  final String sessionId;
  final String url;
  final void Function(KycSessionStatus status) onStatusChange;

  const _ProtegeyKycSheet({required this.kyc, required this.sessionId, required this.url, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  const Text('Verifying your identity…', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 64), // balances the Close button so the title stays centered
                ],
              ),
            ),
            Expanded(
              child: ProtegeyKycView(kyc: kyc, sessionId: sessionId, url: url, onStatusChange: onStatusChange),
            ),
          ],
        ),
      ),
    );
  }
}
