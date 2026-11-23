/// The Protegey SDK for Flutter — one client for device intelligence, transaction reporting,
/// identity verification and behavioral biometrics.
library protegey_sdk;

import 'package:http/http.dart' as http;

import 'src/behavioral.dart';
import 'src/cash_deposits.dart';
import 'src/client.dart';
import 'src/device.dart';
import 'src/kyc.dart';
import 'src/liveness.dart';
import 'src/transactions.dart';

export 'src/types.dart';
export 'src/kyc.dart'
    show
        KycModule,
        StartKycSessionResult,
        KycSessionStatus,
        KycSessionSummary,
        KycOutcome,
        KycRecommendation,
        KycReviewStatus,
        KycImage,
        KycImages;
export 'src/cash_deposits.dart' show CashDepositsModule, CashDepositInput, RecordCashDepositResult, CashDeposit;
export 'src/kyc_webview.dart' show ProtegeyKycView, ProtegeyKycPresentation;
export 'src/liveness.dart'
    show LivenessModule, LivenessMode, LivenessSession, StartLivenessSessionResult, ProtegeyLivenessPresentation, no3dEnrollmentErrorCode;
export 'src/behavioral.dart'
    show
        BehavioralConfidenceTier,
        KeystrokeMetrics,
        NavigationMetrics,
        ReportBehavioralEventInput,
        ReportBehavioralEventResult,
        SessionMetrics,
        TouchMetrics;

/// ```dart
/// final protegey = Protegey(apiKey: 'YOUR_API_KEY', baseUrl: 'https://api.protegey.com');
/// final identify = await protegey.device.identify(externalCustomerId: 'cust-1');
/// final status = await protegey.kyc.presentVerification(context, externalUserId: 'cust-1');
/// final check = await protegey.liveness.presentLiveness(context, externalUserId: 'cust-1');
/// final again = await protegey.liveness.presentReverification(context, externalUserId: 'cust-1');
/// final behavioral = await protegey.behavioral.report(ReportBehavioralEventInput(
///   externalCustomerId: 'cust-1',
///   sessionId: 'sess-1',
///   keystroke: const KeystrokeMetrics(avgInterKeyLatencyMs: 145),
/// ));
/// ```
///
/// `baseUrl` has no default — confirm the current value with Protegey (it may differ between
/// environments and can change independently of this package). See [ProtegeyHttpClient]'s doc
/// comment for why.
///
/// Namespaced (`.device`, `.transactions`, `.cashDeposits`, `.kyc`, `.behavioral`) so more of the partner-api
/// surface can be added later without breaking this shape.
class Protegey {
  final DeviceModule device;
  final TransactionsModule transactions;
  final CashDepositsModule cashDeposits;
  final KycModule kyc;

  /// 3D liveness and re-verification — a separate, paid product (KYC is unaffected).
  final LivenessModule liveness;
  final BehavioralModule behavioral;

  Protegey({required String apiKey, required String baseUrl, http.Client? httpClient})
      : this._(ProtegeyHttpClient(apiKey, baseUrl: baseUrl, httpClient: httpClient));

  Protegey._(ProtegeyHttpClient http)
      : device = DeviceModule(http),
        transactions = TransactionsModule(http),
        cashDeposits = CashDepositsModule(http),
        kyc = KycModule(http),
        liveness = LivenessModule(http),
        behavioral = BehavioralModule(http);
}
