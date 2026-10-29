import 'dart:io';
class ApiConstants {
  static const String baseUrl = 'https://epic-qa-v2.mvp-apps.ae/api/';
  static const String apiKeyHeader = 'X-Api-Key';
  static String get apiKey => Platform.isIOS
      ? 'eiIz8hG6svJPpbm4SbywVKX7G7L3qAWleRdSV8XNFlsY9ljT'
      : 'PkFSGeS4rnIkDGcPWNNjJFxGksJdlXT2Fjze39DtOYFYz9Im';
}
