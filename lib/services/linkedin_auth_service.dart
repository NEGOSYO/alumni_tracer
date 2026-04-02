import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'linkedin_popup_stub.dart'
    if (dart.library.html) 'linkedin_popup_web.dart';

class LinkedInRegistrationPrefill {
  const LinkedInRegistrationPrefill({
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.linkedInSub,
    this.source = 'linkedin',
  });

  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String linkedInSub;
  final String source;

  bool get hasImportedName =>
      fullName.trim().isNotEmpty ||
      firstName.trim().isNotEmpty ||
      lastName.trim().isNotEmpty;
}

class LinkedInAuthResult {
  const LinkedInAuthResult({
    required this.authFlow,
    required this.provider,
    required this.message,
    required this.error,
    required this.email,
    required this.prefill,
    required this.user,
  });

  final String authFlow;
  final String provider;
  final String message;
  final String error;
  final String email;
  final LinkedInRegistrationPrefill? prefill;
  final Map<String, dynamic>? user;

  bool get isLinkedInFlow =>
      provider == 'linkedin' || authFlow.startsWith('linkedin_');
  bool get isRegistrationPrefill =>
      authFlow == 'linkedin_register' && prefill != null;
  bool get isLoginSuccess =>
      authFlow == 'linkedin_login_success' && user != null;
  bool get shouldOpenLoginPage =>
      isLinkedInFlow && !isRegistrationPrefill && !isLoginSuccess;

  static LinkedInAuthResult? fromUri(Uri uri) {
    final query = uri.queryParameters;
    final authFlow = (query['auth_flow'] ?? '').trim();
    final provider = (query['provider'] ?? '').trim();
    final hasLinkedInSignal =
        authFlow.startsWith('linkedin_') ||
        provider == 'linkedin' ||
        query.containsKey('li_name') ||
        query.containsKey('li_first_name') ||
        query.containsKey('li_last_name') ||
        query.containsKey('li_sub') ||
        query.containsKey('li_error');

    if (!hasLinkedInSignal) return null;

    var fullName = (query['li_name'] ?? query['name'] ?? '').trim();
    var firstName = (query['li_first_name'] ?? query['first_name'] ?? '')
        .trim();
    var lastName = (query['li_last_name'] ?? query['last_name'] ?? '').trim();
    final email = (query['li_email'] ?? query['email'] ?? '').trim();
    final linkedInSub = (query['li_sub'] ?? query['sub'] ?? '').trim();

    if (fullName.isEmpty) {
      fullName = [
        firstName,
        lastName,
      ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    }

    if (firstName.isEmpty && lastName.isEmpty && fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    final prefill = authFlow == 'linkedin_register'
        ? LinkedInRegistrationPrefill(
            fullName: fullName,
            firstName: firstName,
            lastName: lastName,
            email: email,
            linkedInSub: linkedInSub,
          )
        : null;

    final user = authFlow == 'linkedin_login_success'
        ? _buildUserSession(query)
        : null;

    return LinkedInAuthResult(
      authFlow: authFlow,
      provider: provider,
      message: (query['li_message'] ?? '').trim(),
      error: (query['li_error'] ?? '').trim(),
      email: email,
      prefill: prefill,
      user: user,
    );
  }

  static Map<String, dynamic>? _buildUserSession(Map<String, String> query) {
    final id = int.tryParse((query['li_user_id'] ?? '').trim());
    final role = (query['li_role'] ?? '').trim();
    final name = (query['li_user_name'] ?? query['li_name'] ?? '').trim();
    final email = (query['li_user_email'] ?? query['li_email'] ?? '').trim();

    if (id == null || role.isEmpty || name.isEmpty || email.isEmpty) {
      return null;
    }

    bool parseBool(String key, {bool fallback = false}) {
      final value = (query[key] ?? '').trim().toLowerCase();
      if (value == '1' || value == 'true') return true;
      if (value == '0' || value == 'false') return false;
      return fallback;
    }

    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'accountStatus': (query['li_status'] ?? '').trim(),
      'program': (query['li_program'] ?? '').trim(),
      'year_graduated': (query['li_year_graduated'] ?? '').trim(),
      'graduation_year': (query['li_year_graduated'] ?? '').trim(),
      'gradYear': (query['li_year_graduated'] ?? '').trim(),
      'firstName': (query['li_first_name'] ?? '').trim(),
      'first_name': (query['li_first_name'] ?? '').trim(),
      'lastName': (query['li_last_name'] ?? '').trim(),
      'last_name': (query['li_last_name'] ?? '').trim(),
      'phone': (query['li_phone'] ?? '').trim(),
      'address': (query['li_address'] ?? '').trim(),
      'civilStatus': (query['li_civil_status'] ?? '').trim(),
      'civil_status': (query['li_civil_status'] ?? '').trim(),
      'alumniNumber': (query['li_alumni_number'] ?? '').trim(),
      'alumni_number': (query['li_alumni_number'] ?? '').trim(),
      'studentNumber': (query['li_student_number'] ?? '').trim(),
      'student_number': (query['li_student_number'] ?? '').trim(),
      'degree': (query['li_degree'] ?? '').trim(),
      'major': (query['li_major'] ?? '').trim(),
      'emailAnnouncements': parseBool('li_email_announcements', fallback: true),
      'email_announcements': parseBool(
        'li_email_announcements',
        fallback: true,
      ),
      'emailReminders': parseBool('li_email_reminders', fallback: true),
      'email_reminders': parseBool('li_email_reminders', fallback: true),
      'eventInvitations': parseBool('li_event_invitations'),
      'event_invitations': parseBool('li_event_invitations'),
      'linkedin_sub': (query['li_sub'] ?? '').trim(),
      'auth_provider': 'linkedin',
    };
  }
}

class LinkedInAuthService {
  static LinkedInAuthResult? currentResult() {
    return LinkedInAuthResult.fromUri(Uri.base);
  }

  static LinkedInRegistrationPrefill? currentRegistrationPrefill() {
    return currentResult()?.prefill;
  }

  static String appRedirectBase() {
    return Uri.base.origin.endsWith('/')
        ? Uri.base.origin
        : '${Uri.base.origin}/';
  }

  static Uri registrationStartUri() {
    return ApiService.uri(
      'linkedin_start.php',
      queryParameters: {
        'flow': 'register',
        'provider': 'linkedin',
        'app_redirect': appRedirectBase(),
        if (kIsWeb) 'popup': '1',
      },
    );
  }

  static Uri linkAccountStartUri({required int userId}) {
    return ApiService.uri(
      'linkedin_start.php',
      queryParameters: {
        'flow': 'link',
        'provider': 'linkedin',
        'user_id': '$userId',
        'app_redirect': appRedirectBase(),
        if (kIsWeb) 'popup': '1',
      },
    );
  }

  static Future<bool> startRegistration() {
    return _launchLinkedInUri(registrationStartUri());
  }

  static Future<bool> startAccountLink({required int userId}) {
    return _launchLinkedInUri(linkAccountStartUri(userId: userId));
  }

  static Future<bool> _launchLinkedInUri(Uri uri) async {
    if (kIsWeb) {
      final opened = await openLinkedInPopup(uri.toString());
      if (opened) return true;
    }
    return launchUrl(uri);
  }
}
