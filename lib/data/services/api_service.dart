import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import 'storage_service.dart';
export 'storage_service.dart';
class ApiService {
  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ApiConstants.apiKeyHeader: ApiConstants.apiKey,
    };
    if (withAuth) {
      final token = await StorageService.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(ApiConstants.baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '$basePath$cleanPath',
      queryParameters: query,
    );
  }
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final uri = _uri(path);
    debugPrint('══════════════════════════════');
    debugPrint('[API] POST $uri');
    debugPrint('[API] Headers: $headers');
    debugPrint('[API] Body: ${jsonEncode(body)}');
    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    return _parse(response);
  }
  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final uri = _uri(path);
    debugPrint('══════════════════════════════');
    debugPrint('[API] PUT $uri');
    debugPrint('[API] Headers: $headers');
    debugPrint('[API] Body: ${jsonEncode(body)}');
    final response = await http.put(uri, headers: headers, body: jsonEncode(body));
    return _parse(response);
  }
  static Future<Map<String, dynamic>> delete(
    String path, {
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final uri = _uri(path);
    debugPrint('══════════════════════════════');
    debugPrint('[API] DELETE $uri');
    debugPrint('[API] Headers: $headers');
    final response = await http.delete(uri, headers: headers);
    return _parse(response);
  }
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final uri = _uri(path, query);
    debugPrint('══════════════════════════════');
    debugPrint('[API] GET $uri');
    debugPrint('[API] Headers: $headers');
    final response = await http.get(uri, headers: headers);
    return _parse(response);
  }
  static Map<String, dynamic> _parse(http.Response response) {
    final rawBody = response.body.trim();
    debugPrint('[API] Status: ${response.statusCode}');
    debugPrint('[API] Response: ${rawBody.length > 500 ? rawBody.substring(0, 500) : rawBody}');
    debugPrint('══════════════════════════════');
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(rawBody);
      body = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      throw ApiException(
        'Unexpected server response (${response.statusCode}).',
        response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message = body['message'] ?? body['error'] ?? 'Something went wrong';
    throw ApiException(message.toString(), response.statusCode);
  }
}
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
