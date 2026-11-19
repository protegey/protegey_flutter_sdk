import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/cash_deposits.dart';
import 'package:protegey_sdk/src/client.dart';
import 'package:protegey_sdk/src/types.dart';

const _depositRow = {
  'cashDepositId': 'cd-uuid-1',
  'externalTransactionId': 'dep-0001',
  'externalCustomerId': 'cust-9981',
  'customerName': 'Moussa Traoré',
  'amount': '2500000.00',
  'currency': 'XOF',
  'channel': 'BRANCH',
  'branchId': 'DKR-PLATEAU',
  'agentId': null,
  'location': 'Dakar, Plateau',
  'depositorName': 'Awa Diallo',
  'metadata': {'tellerId': 'T-04'},
  'decision': 'REVIEW',
  'riskScore': 20,
  'depositedAt': '2026-11-18T09:30:00.000Z',
  'createdAt': '2026-11-18T09:30:01.204Z',
};

CashDepositsModule _module(MockClient mock) =>
    CashDepositsModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

void main() {
  group('CashDepositsModule.record', () {
    test('posts the deposit to /partner-api/cash-deposits with lowercase channel and ISO dates', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'cashDepositId': 'cd-uuid-1',
            'externalTransactionId': 'dep-0001',
            'decision': 'REVIEW',
            'riskScore': 20,
            'alerts': [
              {'id': 'a1', 'alertNumber': 1043, 'ruleCode': 'IND006-KYC1', 'status': 'OPEN', 'decisionVerdict': 'REVIEW', 'triggeredAt': '2026-11-18T09:30:01.204Z'}
            ],
          }),
          201,
        );
      });

      final result = await _module(mock).record(CashDepositInput(
        externalTransactionId: 'dep-0001',
        externalCustomerId: 'cust-9981',
        amount: 2500000,
        currency: 'XOF',
        channel: TransactionChannel.branch,
        branchId: 'DKR-PLATEAU',
        depositorName: 'Awa Diallo',
        depositedAt: DateTime.utc(2026, 11, 18, 9, 30),
        metadata: const {'tellerId': 'T-04'},
      ));

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'https://api.example.com/partner-api/cash-deposits');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['externalTransactionId'], 'dep-0001');
      expect(body['amount'], 2500000);
      expect(body['currency'], 'XOF');
      expect(body['channel'], 'branch');
      expect(body['depositedAt'], '2026-11-18T09:30:00.000Z');
      expect(body['metadata'], {'tellerId': 'T-04'});
      expect(body.containsKey('agentId'), isFalse);

      expect(result.cashDepositId, 'cd-uuid-1');
      expect(result.decision, 'REVIEW');
      expect(result.riskScore, 20);
      expect(result.alerts.single['ruleCode'], 'IND006-KYC1');
    });

    test('a duplicate externalTransactionId surfaces as a 409 ProtegeyApiException', () async {
      final mock = MockClient((_) async => http.Response(jsonEncode({'statusCode': 409, 'message': 'Transaction already submitted'}), 409));

      expect(
        () => _module(mock).record(const CashDepositInput(externalTransactionId: 'dep-0001', externalCustomerId: 'c', amount: 1, currency: 'XOF')),
        throwsA(isA<ProtegeyApiException>().having((e) => e.status, 'status', 409)),
      );
    });
  });

  group('CashDepositsModule.list', () {
    test('sends only the filters that were set, as query parameters', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'data': [_depositRow], 'total': 1, 'page': 2, 'limit': 50, 'totalPages': 1}), 200);
      });

      final page = await _module(mock).list(
        page: 2,
        limit: 50,
        dateFrom: DateTime.utc(2026, 11, 1),
        externalCustomerId: 'cust-9981',
        minAmount: 1000000,
        currency: 'XOF',
        channel: TransactionChannel.mobileApp,
        decision: 'REVIEW',
        branchId: 'DKR-PLATEAU',
        agentId: 'AG-1',
      );

      expect(captured!.url.path, '/partner-api/cash-deposits');
      expect(captured!.url.queryParameters, {
        'page': '2',
        'limit': '50',
        'dateFrom': '2026-11-01T00:00:00.000Z',
        'externalCustomerId': 'cust-9981',
        'minAmount': '1000000',
        'currency': 'XOF',
        'channel': 'mobile_app',
        'decision': 'REVIEW',
        'branchId': 'DKR-PLATEAU',
        'agentId': 'AG-1',
      });
      expect(page.total, 1);
      expect(page.page, 2);
      expect(page.data.single.amount, '2500000.00');
      expect(page.data.single.alerts, isEmpty);
    });

    test('no filters means no query string', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'data': [], 'total': 0, 'page': 1, 'limit': 20, 'totalPages': 1}), 200);
      });

      await _module(mock).list();

      expect(captured!.url.toString(), 'https://api.example.com/partner-api/cash-deposits');
    });
  });

  group('CashDepositsModule.get', () {
    test('GETs by id (or externalTransactionId) and parses the deposit with its alerts', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            ..._depositRow,
            'alerts': [
              {'id': 'a1', 'alertNumber': 1043, 'ruleCode': 'IND006-KYC1', 'status': 'OPEN', 'decisionVerdict': 'REVIEW', 'triggeredAt': '2026-11-18T09:30:01.204Z'}
            ],
          }),
          200,
        );
      });

      final deposit = await _module(mock).get('dep 0001');

      expect(captured!.url.toString(), 'https://api.example.com/partner-api/cash-deposits/dep%200001');
      expect(deposit.externalTransactionId, 'dep-0001');
      expect(deposit.amount, '2500000.00');
      expect(deposit.channel, 'BRANCH');
      expect(deposit.metadata, {'tellerId': 'T-04'});
      expect(deposit.depositedAt, DateTime.utc(2026, 11, 18, 9, 30));
      expect(deposit.alerts.single['alertNumber'], 1043);
    });
  });
}
