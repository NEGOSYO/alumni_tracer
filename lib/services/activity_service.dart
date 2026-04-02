import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../state/user_store.dart';
import 'api_service.dart';

class ActivityService {
  ActivityService._();

  static Future<void> logImportantFlow({
    required String action,
    required String title,
    required String type,
    int? userId,
    String? userName,
    String? userEmail,
    String? role,
    String? targetId,
    String? targetType,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = UserStore.value;
    final resolvedUserId =
        userId ??
        int.tryParse(
          (currentUser?['id'] ?? currentUser?['user_id'] ?? '').toString(),
        );
    final resolvedName =
        _cleanText(userName) ??
        _cleanText(currentUser?['name']) ??
        _buildNameFromParts(currentUser);
    final resolvedEmail =
        _cleanText(userEmail) ?? _cleanText(currentUser?['email']);
    final resolvedRole =
        _cleanText(role) ?? _cleanText(currentUser?['role']) ?? 'alumni';
    final resolvedProgram = _cleanText(
      currentUser?['program'] ??
          currentUser?['degree'] ??
          currentUser?['major'],
    );
    final normalizedMetadata = <String, dynamic>{
      if (resolvedUserId != null) 'actor_user_id': resolvedUserId,
      if (resolvedEmail != null) 'actor_email': resolvedEmail,
      if (resolvedProgram != null) 'program': resolvedProgram,
      ...?metadata,
    };

    final payload =
        <String, dynamic>{
          'action': action,
          'title': title,
          'type': type,
          'user_id': resolvedUserId,
          'user_name': resolvedName,
          'name': resolvedName,
          'user_email': resolvedEmail,
          'email': resolvedEmail,
          'role': resolvedRole,
          'target_id': _cleanText(targetId),
          'target_type': _cleanText(targetType),
          'description': _cleanText(description),
          'metadata': normalizedMetadata,
          'occurred_at': DateTime.now().toIso8601String(),
          'source': 'flutter_app',
        }..removeWhere((key, value) {
          if (value == null) return true;
          if (value is String && value.trim().isEmpty) return true;
          return false;
        });

    try {
      await http
          .post(
            ApiService.uri('log_activity.php'),
            headers: ApiService.jsonHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (error) {
      debugPrint('Activity logging skipped: $error');
    }
  }

  static String? _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _buildNameFromParts(Map<String, dynamic>? user) {
    if (user == null) return null;
    final firstName = _cleanText(user['first_name'] ?? user['firstName']) ?? '';
    final lastName = _cleanText(user['last_name'] ?? user['lastName']) ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    return fullName.isEmpty ? null : fullName;
  }
}
