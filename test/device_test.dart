import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/client.dart';
import 'package:protegey_sdk/src/device.dart';
import 'package:protegey_sdk/src/types.dart';

const _successBody = {'recorded': true, 'action': 'allow', 'riskScore': 0};

void main() {
  group('DeviceModule.identify', () {
    test('uses the provided visitorId override instead of computing one', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await device.identify(visitorId: 'my-own-stable-id', externalCustomerId: 'cust-1');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['visitorId'], 'my-own-stable-id');
      expect(body['externalCustomerId'], 'cust-1');
      expect(result.visitorId, 'my-own-stable-id');
    });

    test('falls back to computeFingerprint() when no visitorId override is given (random id on a non-Android/iOS test host)', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await device.identify();

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['visitorId'], isNotEmpty);
      expect(result.visitorId, body['visitorId']);
    });

    test('merges caller-supplied deviceAttributes on top of the computed ones', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await device.identify(visitorId: 'v1', deviceAttributes: const DeviceAttributes(isRooted: true));

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['deviceAttributes'], {'isRooted': true});
    });

    test('passes phoneNumber through untouched', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await device.identify(visitorId: 'v1', phoneNumber: '+22890000001');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['phoneNumber'], '+22890000001');
    });

    test('uses the caller-supplied eventId when given', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(_successBody), 200);
      });
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      await device.identify(visitorId: 'v1', eventId: 'my-idempotency-key');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['eventId'], 'my-idempotency-key');
    });

    test('parses the backend action into the DeviceAction enum', () async {
      final mock = MockClient((request) async => http.Response(jsonEncode({'recorded': true, 'action': 'soft_challenge', 'riskScore': 15}), 200));
      final device = DeviceModule(ProtegeyHttpClient('key', baseUrl: 'https://api.example.com', httpClient: mock));

      final result = await device.identify(visitorId: 'v1');

      expect(result.action, DeviceAction.softChallenge);
      expect(result.riskScore, 15);
      expect(result.recorded, isTrue);
    });
  });
}
