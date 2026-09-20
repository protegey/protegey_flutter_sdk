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
}
