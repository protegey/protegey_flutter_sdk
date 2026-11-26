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

    test('parses expiresAt when the backend returns it', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'sessionId': 'sess_abc', 'url': 'https://capture.example.com/?t=1', 'expiresAt': '2026-11-27T15:00:00.000Z'}),
            200,
          ));
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.startSession(externalUserId: 'cust-1');

      expect(result.expiresAt, DateTime.utc(2026, 11, 27, 15));
    });
  });

  group('KYB-linked sessions', () {
    test('getSession exposes kybClientId and kybNameMatch', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'sessionId': 'sess_1', 'externalUserId': null, 'kybClientId': 'client_1', 'kybNameMatch': 'MATCH', 'status': 'APPROVED', 'decision': null}),
            200,
          ));
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.getSession('sess_1');

      expect(result.kybClientId, 'client_1');
      expect(result.kybNameMatch, 'MATCH');
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
        'decision': {'source': 'protegey', 'outcome': 'MANUAL', 'passed': true, 'confidenceScore': 0.4286, 'livenessScore': 100, 'matchScore': 43},
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

    test('outcome is unknown before a verification result exists', () {
      final status = KycSessionStatus.fromJson({'sessionId': 'enr-1', 'externalUserId': 'u', 'status': 'IN_PROGRESS', 'outcome': null, 'decision': null});
      expect(status.outcome, KycOutcome.unknown);
    });
  });

  group('recommendation and images', () {
    test('KycSessionStatus parses recommendation and the pre-signed images block', () {
      final status = KycSessionStatus.fromJson({
        'sessionId': 'enr-1',
        'externalUserId': 'cust-1',
        'status': 'IN_REVIEW',
        'outcome': 'SUCCESS',
        'recommendation': 'APPROVE',
        'decision': null,
        'images': {
          'documentFront': {'url': 'https://s3.example/front.jpg?sig=1', 'expiresAt': '2026-11-19T13:00:00.000Z'},
          'documentBack': null,
          'selfie': {'url': 'https://s3.example/selfie.jpg?sig=2', 'expiresAt': '2026-11-19T13:00:00.000Z'},
          'documentFaceCrop': null,
        },
      });

      expect(status.recommendation, KycRecommendation.approve);
      expect(status.images!.documentFront!.url, 'https://s3.example/front.jpg?sig=1');
      expect(status.images!.documentFront!.expiresAt, DateTime.utc(2026, 11, 19, 13));
      expect(status.images!.documentBack, isNull);
      expect(status.images!.selfie!.url, 'https://s3.example/selfie.jpg?sig=2');
    });

    test('recommendation is null before a result, and images null when absent', () {
      final status = KycSessionStatus.fromJson({'sessionId': 'enr-1', 'externalUserId': null, 'status': 'IN_PROGRESS', 'recommendation': null, 'decision': null});
      expect(status.recommendation, isNull);
      expect(status.images, isNull);
    });
  });

  group('KycModule.listSessions', () {
    test('GETs /partner-api/kyc/sessions with the externalUserId filter and parses rows', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'sessionId': 'enr-1',
                'externalUserId': 'cust-9981',
                'status': 'IN_REVIEW',
                'outcome': 'MANUAL',
                'recommendation': 'REVIEW',
                'fullName': 'AWA DIALLO',
                'documentType': 'Passport',
                'country': 'CI',
                'createdAt': '2026-11-19T12:00:00.000Z',
                'images': {'documentFront': null, 'documentBack': null, 'selfie': null, 'documentFaceCrop': null},
              }
            ],
            'total': 1,
            'page': 1,
            'limit': 20,
            'totalPages': 1,
          }),
          200,
        );
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final page = await kyc.listSessions(externalUserId: 'cust-9981', status: 'IN_REVIEW', limit: 20);

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/partner-api/kyc/sessions');
      expect(captured!.url.queryParameters, {'externalUserId': 'cust-9981', 'status': 'IN_REVIEW', 'limit': '20'});
      final row = page.data.single;
      expect(row.sessionId, 'enr-1');
      expect(row.outcome, KycOutcome.manual);
      expect(row.recommendation, KycRecommendation.review);
      expect(row.createdAt, DateTime.utc(2026, 11, 19, 12));
      expect(row.images!.selfie, isNull);
      expect(page.totalPages, 1);
    });
  });

  group('KycModule.updateSession', () {
    test('PATCHes status (UPPER_SNAKE) and reviewNote', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'sessionId': 'enr-1',
            'externalUserId': 'cust-1',
            'status': 'APPROVED',
            'outcome': 'MANUAL',
            'recommendation': 'REVIEW',
            'decision': {
              'outcome': 'MANUAL',
              'manualReview': {'reviewedBy': 'Partner API', 'previousStatus': 'IN_REVIEW', 'newStatus': 'APPROVED', 'note': 'Checked'},
            },
          }),
          200,
        );
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await kyc.updateSession('enr-1', status: KycReviewStatus.approved, reviewNote: 'Checked');

      expect(captured!.method, 'PATCH');
      expect(captured!.url.toString(), 'https://api.example.com/partner-api/kyc/sessions/enr-1');
      expect(jsonDecode(captured!.body), {'status': 'APPROVED', 'reviewNote': 'Checked'});
      expect(result.status, 'APPROVED');
      expect(result.recommendation, KycRecommendation.review);
      expect((result.decision!['manualReview'] as Map)['newStatus'], 'APPROVED');
    });

    test('inReview maps to IN_REVIEW and omitted fields are not sent', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'sessionId': 'enr-1', 'externalUserId': null, 'status': 'IN_REVIEW', 'decision': null}), 200);
      });
      final kyc = KycModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await kyc.updateSession('enr-1', status: KycReviewStatus.inReview);

      expect(jsonDecode(captured!.body), {'status': 'IN_REVIEW'});
    });
  });
}
