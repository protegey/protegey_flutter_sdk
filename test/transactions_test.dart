import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/client.dart';
import 'package:protegey_sdk/src/transactions.dart';
import 'package:protegey_sdk/src/types.dart';

const _successBody = {
  'transactionId': 'tx-uuid-1',
  'decision': 'clear',
  'riskScore': 0,
  'alerts': [],
  'deviceAction': null,
};

TransactionInput _baseInput({String? visitorId, DeviceAttributes? deviceAttributes, DateTime? occurredAt}) {
  return TransactionInput(
    externalTransactionId: 'tx-1',
    externalCustomerId: 'cust-1',
    direction: TransactionDirection.debit,
    amount: 1000,
    transactionType: 'cashout',
    visitorId: visitorId,
    deviceAttributes: deviceAttributes,
    occurredAt: occurredAt,
  );
}

void main() {
  group('TransactionsModule.report', () {
    test('posts a faithful mapping of the input to /partner-api/transactions', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final transactions = TransactionsModule(ProtegeyHttpClient('key', httpClient: mock));

      await transactions.report(_baseInput());

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['externalTransactionId'], 'tx-1');
      expect(body['externalCustomerId'], 'cust-1');
      expect(body['direction'], 'DEBIT');
      expect(body['amount'], 1000);
      expect(body['transactionType'], 'cashout');
    });

    test('defaults occurredAt to now when not provided', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final transactions = TransactionsModule(ProtegeyHttpClient('key', httpClient: mock));

      await transactions.report(_baseInput());

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(DateTime.tryParse(body['occurredAt'] as String), isNotNull);
    });

    test('preserves a caller-supplied occurredAt instead of overriding it', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final transactions = TransactionsModule(ProtegeyHttpClient('key', httpClient: mock));

      final fixed = DateTime.utc(2026, 1, 1);
      await transactions.report(_baseInput(occurredAt: fixed));

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['occurredAt'], fixed.toIso8601String());
    });

    test('passes device-intelligence fields through when given', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final transactions = TransactionsModule(ProtegeyHttpClient('key', httpClient: mock));

      await transactions.report(_baseInput(visitorId: 'v1', deviceAttributes: const DeviceAttributes(isRooted: true)));

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['visitorId'], 'v1');
      expect(body['deviceAttributes'], {'isRooted': true});
    });

    test('parses the response into a ReportTransactionResult', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({
              'transactionId': 'tx-uuid-2',
              'decision': 'review',
              'riskScore': 35,
              'alerts': [
                {'id': 'alert-1', 'ruleCode': 'IND012-KYC1', 'status': 'open'}
              ],
              'deviceAction': 'hard_challenge',
            }),
            200,
          ));
      final transactions = TransactionsModule(ProtegeyHttpClient('key', httpClient: mock));

      final result = await transactions.report(_baseInput());

      expect(result.transactionId, 'tx-uuid-2');
      expect(result.decision, 'review');
      expect(result.riskScore, 35);
      expect(result.alerts, hasLength(1));
      expect(result.deviceAction, DeviceAction.hardChallenge);
    });
  });
}
