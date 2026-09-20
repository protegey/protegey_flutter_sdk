import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protegey_sdk/src/client.dart';
import 'package:protegey_sdk/src/types.dart';

void main() {
  group('ProtegeyHttpClient', () {
    test('throws when constructed without an apiKey', () {
      expect(() => ProtegeyHttpClient(''), throwsArgumentError);
    });

    test('sends the api key as the x-api-key header', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final client = ProtegeyHttpClient('secret-key', baseUrl: 'https://api.example.com', httpClient: mock);
      await client.post('/foo', {'a': 1});

      expect(captured!.headers['x-api-key'], 'secret-key');
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test('strips a trailing slash from a custom baseUrl', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      final client = ProtegeyHttpClient('key', baseUrl: 'https://api.example.com/', httpClient: mock);
      await client.post('/foo', {});

      expect(captured!.url.toString(), 'https://api.example.com/foo');
    });

    test('throws ProtegeyApiException with the backend message on a non-2xx response', () async {
      final mock = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Insufficient permissions'}), 403);
      });

      final client = ProtegeyHttpClient('key', httpClient: mock);
      expect(
        () => client.post('/foo', {}),
        throwsA(isA<ProtegeyApiException>().having((e) => e.status, 'status', 403).having((e) => e.message, 'message', 'Insufficient permissions')),
      );
    });

    test('joins an array-shaped validation error message', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': ['amount must be positive', 'currency required']
          }),
          400,
        );
      });

      final client = ProtegeyHttpClient('key', httpClient: mock);
      expect(
        () => client.post('/foo', {}),
        throwsA(isA<ProtegeyApiException>().having((e) => e.message, 'message', 'amount must be positive, currency required')),
      );
    });

    test('falls back to reasonPhrase when the response body is not JSON', () async {
      final mock = MockClient((request) async {
        return http.Response('not json', 500, reasonPhrase: 'Internal Server Error');
      });

      final client = ProtegeyHttpClient('key', httpClient: mock);
      expect(
        () => client.post('/foo', {}),
        throwsA(isA<ProtegeyApiException>().having((e) => e.message, 'message', 'Internal Server Error')),
      );
    });
  });
}
