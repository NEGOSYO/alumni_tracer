import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../state/user_store.dart';

/// Centralized API URL builder for the PHP backend.
///
/// Default base URL behavior:
/// - Web on localhost: `http://localhost/alumni_tracer_php-php-final`
/// - Web on deployed hosts: `https://alumnitracking.ct.ws`
/// - Android emulator: `http://10.0.2.2/alumni_tracer_php-php-final`
/// - Everything else (iOS simulator, desktop): `http://localhost/alumni_tracer_php-php-final`
///
/// Override at build/run time with:
/// `--dart-define=API_BASE_URL=https://alumnitracking.ct.ws`
class ApiService {
  static const String _apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _productionBaseUrl = 'https://alumnitracking.ct.ws';

  static String get baseUrl {
    final defined = _apiBaseUrlDefine.trim();
    if (defined.isNotEmpty) return _normalizeBaseUrl(defined);

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isLocalWebHost =
          host.isEmpty ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '0.0.0.0';
      if (!isLocalWebHost) {
        return _productionBaseUrl;
      }
      return _productionBaseUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _productionBaseUrl;
    }
    return _productionBaseUrl;
  }

  static Uri uri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    final base = baseUrl;
    final normalizedEndpoint = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final url = '$base/$normalizedEndpoint';
    final mergedQueryParameters = <String, dynamic>{
      ...?queryParameters,
      ..._requesterContext(),
    };
    return Uri.parse(url).replace(
      queryParameters: mergedQueryParameters.map((k, v) => MapEntry(k, '$v')),
    );
  }

  static Map<String, String> authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{...?(extra)};
    final token = _accessToken();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, String> jsonHeaders({Map<String, String>? extra}) {
    return authHeaders(extra: {'Content-Type': 'application/json', ...?extra});
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  static Map<String, dynamic> _requesterContext() {
    final user = UserStore.value;
    if (user == null) {
      return const {};
    }

    final role = (user['role'] ?? '').toString().trim().toLowerCase();
    final userId = (user['id'] ?? user['user_id'] ?? '').toString().trim();
    final program = (user['program'] ?? '').toString().trim();

    final context = <String, dynamic>{};
    if (role.isNotEmpty) {
      context['requester_role'] = role;
    }
    if (userId.isNotEmpty) {
      context['requester_user_id'] = userId;
    }
    if (program.isNotEmpty) {
      context['requester_program'] = program;
    }
    return context;
  }

  static String _accessToken() {
    final user = UserStore.value;
    if (user == null) return '';
    return (user['access_token'] ?? user['token'] ?? '').toString().trim();
  }
}
