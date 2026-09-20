import 'dart:convert';

import 'package:http/http.dart' as http;

import 'types.dart';

const _defaultBaseUrl = 'https://api.protegey.com';

/// Thin HTTP wrapper shared by every SDK module — one place that knows about auth, base URL and
/// error shape. Accepts an injectable [http.Client] so tests can use `http.testing.MockClient`
/// without a real network call.
class ProtegeyHttpClient {
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  ProtegeyHttpClient(this.apiKey, {String? baseUrl, http.Client? httpClient})
      : baseUrl = _stripTrailingSlash(baseUrl ?? _defaultBaseUrl),
        _httpClient = httpClient ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ArgumentError('Protegey: apiKey is required');
    }
  }

  static String _stripTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Non-JSON body — data stays null, handled below.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = data?['message'];
      final message = rawMessage is List ? rawMessage.join(', ') : (rawMessage?.toString() ?? response.reasonPhrase ?? 'Request failed');
      throw ProtegeyApiException(response.statusCode, message);
    }

    return data ?? {};
  }

  void close() => _httpClient.close();
}
