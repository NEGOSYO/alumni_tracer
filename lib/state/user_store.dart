import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory user state for the currently logged-in session.
///
/// This is intentionally lightweight (no extra deps like Provider) and helps
/// the UI reflect profile changes immediately without requiring a full re-login.
class UserStore {
  UserStore._();

  static const String _sessionKey = 'current_user_session';

  static final ValueNotifier<Map<String, dynamic>?> currentUser =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Map<String, dynamic>? get value => currentUser.value;

  static void set(Map<String, dynamic>? user) {
    if (user == null) {
      currentUser.value = null;
      _persistSnapshot(null);
      return;
    }

    // Defensive copy to avoid accidental external mutation.
    currentUser.value = UnmodifiableMapView(Map<String, dynamic>.from(user));
    _persistSnapshot(currentUser.value);
  }

  static Future<void> setAndPersist(Map<String, dynamic>? user) async {
    set(user);
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_sessionKey);
      return;
    }
    await prefs.setString(_sessionKey, jsonEncode(user));
  }

  static void patch(Map<String, dynamic> fields) {
    final existing = currentUser.value;
    if (existing == null) {
      set(fields);
      return;
    }

    final merged = Map<String, dynamic>.from(existing)..addAll(fields);
    currentUser.value = UnmodifiableMapView(merged);
    _persistSnapshot(currentUser.value);
  }

  static void clear() => set(null);

  static Future<void> clearPersisted() async {
    clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<Map<String, dynamic>?> restorePersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      clear();
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        set(decoded);
        return value;
      }
    } catch (_) {
      // Fall through and clear the corrupted session value.
    }

    await prefs.remove(_sessionKey);
    clear();
    return null;
  }

  static Future<void> _persistSnapshot(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_sessionKey);
      return;
    }
    await prefs.setString(_sessionKey, jsonEncode(user));
  }
}
