// Ad-hoc live smoke test against a local backend — not part of the regular test suite (no
// network in CI). Run manually against a locally running protegey-backend + seeded demo data:
//   fvm flutter test test/smoke_live_test.dart --dart-define=PROTEGEY_API_KEY=your-local-demo-key
import 'package:flutter_test/flutter_test.dart';
import 'package:protegey_sdk/protegey_sdk.dart';

const _apiKey = String.fromEnvironment('PROTEGEY_API_KEY', defaultValue: '');

void main() {
  test('identify() and transactions.report() against a live local backend', () async {
    if (_apiKey.isEmpty) {
      // ignore: avoid_print
      print('Skipping: pass --dart-define=PROTEGEY_API_KEY=... to run this against a local backend.');
      return;
    }
    final protegey = Protegey(apiKey: _apiKey, baseUrl: 'http://localhost:3000');

    final identify = await protegey.device.identify(
      externalCustomerId: 'flutter-sdk-smoke-cust-1',
      phoneNumber: '+22890000098',
    );
    // ignore: avoid_print
    print('identify(): recorded=${identify.recorded} action=${identify.action} visitorId=${identify.visitorId}');
    expect(identify.recorded, isTrue);

    final tx = await protegey.transactions.report(TransactionInput(
      externalTransactionId: 'flutter-sdk-smoke-tx-${DateTime.now().millisecondsSinceEpoch}',
      externalCustomerId: 'flutter-sdk-smoke-cust-1',
      direction: TransactionDirection.debit,
      amount: 5000,
      transactionType: 'cashout',
      visitorId: identify.visitorId,
    ));
    // ignore: avoid_print
    print('transactions.report(): transactionId=${tx.transactionId} decision=${tx.decision}');
    expect(tx.transactionId, isNotEmpty);

    final kyc = await protegey.kyc.startSession(externalUserId: 'flutter-sdk-smoke-cust-1');
    // ignore: avoid_print
    print('kyc.startSession(): sessionId=${kyc.sessionId} url=${kyc.url}');
    expect(kyc.sessionId, isNotEmpty);

    final behavioral = await protegey.behavioral.report(const ReportBehavioralEventInput(
      externalCustomerId: 'flutter-sdk-smoke-cust-1',
      sessionId: 'flutter-sdk-smoke-sess-1',
      keystroke: KeystrokeMetrics(avgInterKeyLatencyMs: 145, typingSpeedCharsPerSec: 4.2, errorRate: 0.02),
    ));
    // ignore: avoid_print
    print('behavioral.report(): status=${behavioral.status} deviationScore=${behavioral.deviationScore}');
    expect(behavioral.status, isNotEmpty);
  });
}
