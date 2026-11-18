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
        return http.Response(jsonEncode({'sessionId': 'sess_1', 'url': 'https://capture.example.com/?enrollmentId=1&token=t'}), 200);
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await kyc.startSession(externalUserId: 'cust-1');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['externalUserId'], 'cust-1');
    });

    test('returns the sessionId and hosted verification url', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'sessionId': 'sess_abc', 'url': 'https://capture.example.com/?enrollmentId=abc&token=t'}),
            200,
          ));
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.startSession(externalUserId: 'cust-1');

      expect(result.sessionId, 'sess_abc');
      expect(result.url, 'https://capture.example.com/?enrollmentId=abc&token=t');
    });
  });

  group('KycModule.getSession', () {
    test('GETs /partner-api/kyc/sessions/:sessionId — the webhook polling fallback', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'sessionId': 'sess_1', 'externalUserId': 'cust-1', 'status': 'APPROVED', 'decision': null}),
          200,
        );
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.getSession('sess_1');

      expect(captured!.method, 'GET');
      expect(captured!.url.toString(), 'https://api.example.com/partner-api/kyc/sessions/sess_1');
      expect(result.status, 'APPROVED');
      expect(result.externalUserId, 'cust-1');
    });

    test('URL-encodes the sessionId', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'sessionId': 's', 'externalUserId': null, 'status': 'NOT_STARTED', 'decision': null}), 200);
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await kyc.getSession('sess/with slash');

      expect(captured!.url.toString(), 'https://api.example.com/partner-api/kyc/sessions/sess%2Fwith%20slash');
    });
  });

  group('KycSessionStatus.fromJson', () {
    test('parses the full GET /partner-api/kyc/sessions/:id response, outcome from the top level', () {
      final status = KycSessionStatus.fromJson({
        'sessionId': 'enr-1',
        'externalUserId': 'user-123',
        'status': 'IN_REVIEW',
        'outcome': 'MANUAL',
        'decision': {'source': 'biometric', 'outcome': 'MANUAL', 'passed': true, 'confidenceScore': 0.4286, 'livenessScore': 100, 'matchScore': 43},
        'fullName': 'Jane Doe',
        'documentType': 'ID_CARD',
        'country': 'CM',
        'livenessScore': 100,
        'faceMatchScore': 43,
        'documentPhoto': 'aGVsbG8=',
        'documentBackPhoto': null,
        'selfiePhoto': null,
        'documentFaceCrop': null,
      });

      expect(status.status, 'IN_REVIEW');
      expect(status.outcome, KycOutcome.manual);
      expect(status.decision!['confidenceScore'], 0.4286);
      expect(status.fullName, 'Jane Doe');
      expect(status.country, 'CM');
      expect(status.livenessScore, 100.0);
      expect(status.faceMatchScore, 43.0);
      expect(status.documentPhoto, 'aGVsbG8=');
      expect(status.documentBackPhoto, isNull);
    });

    test('outcome is unknown before a biometric result exists', () {
      final status = KycSessionStatus.fromJson({'sessionId': 'enr-1', 'externalUserId': 'u', 'status': 'IN_PROGRESS', 'outcome': null, 'decision': null});
      expect(status.outcome, KycOutcome.unknown);
    });
  });
}
