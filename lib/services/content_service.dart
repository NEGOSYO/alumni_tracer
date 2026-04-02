import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class ContentService {
  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final response = await http.get(ApiService.uri('get_announcements.php'));
    final list = _extractList(response, primaryKey: 'announcements');

    return list.map((item) {
      final map = Map<String, dynamic>.from(item);
      return {
        ...map,
        'id': _pickValue(map, const ['id']),
        'title': _pickString(map, const ['title']),
        'description': _pickString(
          map,
          const ['description', 'content', 'body'],
        ),
        'category': _pickString(map, const ['category'], fallback: 'General'),
        'created_at': _pickString(
          map,
          const ['created_at', 'date_posted', 'posted_at', 'date'],
        ),
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchJobs() async {
    final response = await http.get(ApiService.uri('get_jobs.php'));
    final list = _extractList(response, primaryKey: 'jobs');

    return list.map((item) {
      final map = Map<String, dynamic>.from(item);
      return {
        ...map,
        'id': _pickValue(map, const ['id']),
        'title': _pickString(map, const ['title']),
        'description': _pickString(
          map,
          const ['description', 'content', 'body'],
        ),
        'company': _pickString(map, const ['company'], fallback: 'Company'),
        'location': _pickString(map, const ['location']),
        'salary': _pickString(map, const ['salary']),
        'requirements': _pickString(map, const ['requirements']),
        'contact_email': _pickString(map, const ['contact_email', 'email']),
        'date_posted': _pickString(
          map,
          const ['date_posted', 'created_at', 'posted_at', 'date'],
        ),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _extractList(
    http.Response response, {
    required String primaryKey,
  }) {
    if (response.statusCode != 200) {
      throw Exception('Request failed with status ${response.statusCode}');
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      return const [];
    }

    if (body.startsWith('<')) {
      throw Exception('Server returned HTML instead of JSON');
    }

    final decoded = jsonDecode(body);
    final dynamic rawList = decoded is List
        ? decoded
        : decoded is Map
        ? (decoded[primaryKey] ?? decoded['data'] ?? const [])
        : const [];

    if (rawList is! List) {
      return const [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  static dynamic _pickValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }
    return null;
  }

  static String _pickString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }
}
