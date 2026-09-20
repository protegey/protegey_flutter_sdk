import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/behavioral.dart';
import 'package:protegey_sdk/src/client.dart';

const _learningBody = {'status': 'learning', 'deviationScore': 0, 'confidenceTier': null, 'stepUpRecommended': false, 'escalatedAlertId': null};

ReportBehavioralEventInput _baseInput() {
  return const ReportBehavioralEventInput(
    externalCustomerId: 'cust-1',
    sessionId: 'sess-1',
    keystroke: KeystrokeMetrics(avgInterKeyLatencyMs: 145, typingSpeedCharsPerSec: 4.2, errorRate: 0.02),
    touch: TouchMetrics(avgSwipeVelocity: 22, scrollBehaviorScore: 0.8),
    navigation: NavigationMetrics(screenSequence: ['login', 'dashboard', 'transfer', 'confirm']),
    session: SessionMetrics(loginHourBucket: 14, loginDayOfWeek: 2, sessionDurationMs: 45000),
  );
}

void main() {
  group('BehavioralModule.report', () {
    test('posts a faithful mapping of the input to /partner-api/behavioral-events', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_learningBody), 200);
      });
      final behavioral = BehavioralModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await behavioral.report(_baseInput());

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['externalCustomerId'], 'cust-1');
      expect(body['sessionId'], 'sess-1');
      expect(body['keystroke'], {'avgInterKeyLatencyMs': 145.0, 'typingSpeedCharsPerSec': 4.2, 'errorRate': 0.02});
      expect(body['navigation'], {
        'screenSequence': ['login', 'dashboard', 'transfer', 'confirm']
      });
    });

    test('returns a "learning" result when no score is available yet', () async {
      final mock = MockClient((request) async => http.Response(jsonEncode(_learningBody), 200));
      final behavioral = BehavioralModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await behavioral.report(_baseInput());

      expect(result.status, 'learning');
      expect(result.confidenceTier, isNull);
    });

    test('returns a "scored" result with stepUpRecommended once a baseline exists', () async {
      final mock = MockClient((request) async => http.Response(
            jsonEncode({'status': 'scored', 'deviationScore': 35, 'confidenceTier': 'medium', 'stepUpRecommended': true, 'escalatedAlertId': null}),
            200,
          ));
      final behavioral = BehavioralModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await behavioral.report(_baseInput());

      expect(result.status, 'scored');
      expect(result.confidenceTier, BehavioralConfidenceTier.medium);
      expect(result.stepUpRecommended, isTrue);
    });
  });
}
