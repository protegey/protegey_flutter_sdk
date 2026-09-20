import 'dart:convert';

import 'package:http/http.dart' as http;

import 'types.dart';

/// Thin HTTP wrapper shared by every SDK module — one place that knows about auth, base URL and
/// error shape. Accepts an injectable [http.Client] so tests can use `http.testing.MockClient`
/// without a real network call.
///
/// [baseUrl] is deliberately required, with NO built-in default: this SDK ships inside partner
/// apps (especially mobile), which can't be force-updated the moment Protegey's own production
/// domain changes. Baking in a guess now would risk every already-shipped app silently talking to
/// a stale/wrong host later — requiring it here means the value only ever needs updating in the
/// caller's own config, never in this package.
class ProtegeyHttpClient {
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  ProtegeyHttpClient(this.apiKey, {required String baseUrl, http.Client? httpClient})
      : baseUrl = _stripTrailingSlash(baseUrl),
        _httpClient = httpClient ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ArgumentError('Protegey: apiKey is required');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Protegey: baseUrl is required — point it at your Protegey API environment (e.g. https://api.protegey.com)');
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
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: {'x-api-key': apiKey},
    );
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
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
