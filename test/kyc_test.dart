import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/client.dart';
import 'package:protegey_sdk/src/kyc.dart';

void main() {
  group('KycModule.startSession', () {
    test('posts the externalUserId to /partner-api/kyc/sessions', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'sessionId': 'sess_1', 'url': 'https://verify.didit.me/session/1'}), 200);
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await kyc.startSession(externalUserId: 'cust-1');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['externalUserId'], 'cust-1');
    });

    test('returns the sessionId and hosted verification url', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'sessionId': 'sess_abc', 'url': 'https://verify.didit.me/session/abc'}),
            200,
          ));
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.startSession(externalUserId: 'cust-1');

      expect(result.sessionId, 'sess_abc');
      expect(result.url, 'https://verify.didit.me/session/abc');
    });
  });

  group('KycModule.getSession', () {
    test('GETs /partner-api/kyc/sessions/:sessionId — the webhook polling fallback', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'sessionId': 'sess_1', 'externalUserId': 'cust-1', 'status': 'Approved', 'decision': null}),
          200,
        );
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.getSession('sess_1');

      expect(captured!.method, 'GET');
      expect(captured!.url.toString(), 'https://api.example.com/partner-api/kyc/sessions/sess_1');
      expect(result.status, 'Approved');
      expect(result.externalUserId, 'cust-1');
    });

    test('URL-encodes the sessionId', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'sessionId': 's', 'externalUserId': null, 'status': 'Not Started', 'decision': null}), 200);
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await kyc.getSession('sess/with slash');

      expect(captured!.url.toString(), 'https://api.example.com/partner-api/kyc/sessions/sess%2Fwith%20slash');
    });
  });
}
