import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

class DeanAnalyticsData {
  const DeanAnalyticsData({
    required this.summary,
    required this.batchData,
    required this.industryData,
    required this.topEmployers,
    required this.jobRelevance,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> batchData;
  final List<Map<String, dynamic>> industryData;
  final List<Map<String, dynamic>> topEmployers;
  final Map<String, dynamic> jobRelevance;

  factory DeanAnalyticsData.fromJson(Map<String, dynamic> decoded) {
    return DeanAnalyticsData(
      summary: Map<String, dynamic>.from(decoded['summary'] ?? const {}),
      batchData: ((decoded['batch_data'] ?? []) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      industryData: ((decoded['industries'] ?? []) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      topEmployers: ((decoded['top_employers'] ?? []) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      jobRelevance: Map<String, dynamic>.from(
        decoded['job_relevance'] ?? const {'related': 0, 'other': 0},
      ),
    );
  }
}

class DeanAnalyticsService {
  static Future<DeanAnalyticsData> fetch({String program = 'All'}) async {
    final response = await http.get(
      ApiService.uri(
        'dean_dashboard.php',
        queryParameters: {'program': program},
      ),
      headers: ApiService.authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    return DeanAnalyticsData.fromJson(decoded);
  }
}
