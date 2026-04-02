import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class FilterOptionsData {
  const FilterOptionsData({
    required this.programs,
    required this.years,
    required this.statuses,
    required this.relatedOptions,
  });

  final List<String> programs;
  final List<String> years;
  final List<String> statuses;
  final List<String> relatedOptions;

  factory FilterOptionsData.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return FilterOptionsData(
      programs: toStringList(json['programs']),
      years: toStringList(json['years']),
      statuses: toStringList(json['statuses']),
      relatedOptions: toStringList(json['related_options']),
    );
  }
}

class FilterOptionsService {
  static Future<FilterOptionsData> fetch({String? program}) async {
    final response = await http.get(
      ApiService.uri(
        'get_filter_options.php',
        queryParameters: {
          if (program != null && program.trim().isNotEmpty) 'program': program,
        },
      ),
      headers: ApiService.authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load filter options (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected filter response format');
    }

    return FilterOptionsData.fromJson(decoded);
  }
}
