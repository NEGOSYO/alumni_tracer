import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/linkedin_auth_service.dart';
import '../../state/user_store.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingsPage({super.key, required this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _emailAnnouncements = true;
  bool _emailReminders = true;
  bool _eventInvitations = false;
  bool _isLinkingLinkedIn = false;

  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _emailAnnouncements =
        _boolFromUser(
          'emailAnnouncements',
          fallbackKey: 'email_announcements',
        ) ??
        true;
    _emailReminders =
        _boolFromUser('emailReminders', fallbackKey: 'email_reminders') ?? true;
    _eventInvitations =
        _boolFromUser('eventInvitations', fallbackKey: 'event_invitations') ??
        false;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _lastLoginText() {
    final currentUser = UserStore.value ?? widget.user;
    final rawValue =
        currentUser['last_login'] ??
        currentUser['lastLogin'] ??
        currentUser['last_login_at'] ??
        currentUser['lastLoginAt'];

    final formatted = _formatLastLogin(rawValue);
    if (formatted != null) {
      return "Your account is active and secure. Last login: $formatted";
    }

    return "Your account is active and secure. Last login will appear here once the backend provides it.";
  }

  String? _formatLastLogin(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    final months = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
  }

  Future<void> _updateSettings() async {
    try {
      final response = await http.post(
        ApiService.uri('update_settings.php'),
        headers: ApiService.jsonHeaders(),
        body: jsonEncode({
          'userId': widget.user['id'],
          'emailAnnouncements': _emailAnnouncements,
          'emailReminders': _emailReminders,
          'eventInvitations': _eventInvitations,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (data['settings'] is Map<String, dynamic>) {
            final settings = Map<String, dynamic>.from(data['settings']);
            UserStore.patch({
              ...settings,
              'email_announcements': settings['emailAnnouncements'],
              'email_reminders': settings['emailReminders'],
              'event_invitations': settings['eventInvitations'],
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Settings updated successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update settings.")),
          );
        }
      } else {
        throw Exception('Failed to save settings');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error saving settings. Please try again."),
        ),
      );
      debugPrint("Error updating settings: $e");
    }
  }

  Future<void> _updatePassword() async {
    try {
      final response = await http.post(
        ApiService.uri('change_password.php'),
        headers: ApiService.jsonHeaders(),
        body: jsonEncode({
          'userId': widget.user['id'],
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? "Password successfully updated!",
            ),
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? "Failed to update password.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error updating password. Please try again."),
        ),
      );
      debugPrint("Error updating password: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(constraints.maxWidth < 760),
                const SizedBox(height: 32),
                _buildSectionCard(
                  title: "Change Password",
                  icon: Icons.lock_outline,
                  child: Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPasswordField(
                          "Current Password",
                          _currentPasswordController,
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          "New Password",
                          _newPasswordController,
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          "Confirm New Password",
                          _confirmPasswordController,
                          isConfirm: true,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _handlePasswordUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text("Update Password"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: "Notification Preferences",
                  icon: Icons.notifications_none_outlined,
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        "Email Announcements",
                        "Receive emails about new announcements",
                        _emailAnnouncements,
                        (v) => setState(() => _emailAnnouncements = v),
                      ),
                      const SizedBox(height: 16),
                      _buildSwitchRow(
                        "Email Reminders",
                        "Receive reminders about tracer form and updates",
                        _emailReminders,
                        (v) => setState(() => _emailReminders = v),
                      ),
                      const SizedBox(height: 16),
                      _buildSwitchRow(
                        "Event Invitations",
                        "Receive invitations to alumni events",
                        _eventInvitations,
                        (v) => setState(() => _eventInvitations = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: "Connected Accounts",
                  icon: Icons.link_outlined,
                  child: _buildLinkedInSection(),
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: "Privacy & Security",
                  icon: Icons.verified_user_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Account Status",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastLoginText(),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Data Privacy",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: [
                          const Text(
                            "Your personal information is protected and only used for alumni engagement purposes. Review our ",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          InkWell(
                            onTap: () {},
                            child: const Text(
                              "Privacy Policy.",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Request Account Deletion"),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "This will permanently delete your account and all associated data.",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: isCompact ? double.infinity : null,
                  child: ElevatedButton(
                    onPressed: _updateSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Save Settings"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(bool isStacked) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryMaroon, primaryMaroon.withValues(alpha: 0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Flex(
        direction: isStacked ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.tune_rounded, color: accentGold, size: 34),
          ),
          SizedBox(width: isStacked ? 0 : 18, height: isStacked ? 16 : 0),
          if (isStacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Manage your account preferences, security, and notifications in the same polished style as the upgraded alumni pages.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage your account preferences, security, and notifications in the same polished style as the upgraded alumni pages.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller, {
    bool isConfirm = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F3F4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "This field is required";
            }
            if (isConfirm && value != _newPasswordController.text) {
              return "Passwords do not match";
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSwitchRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: primaryMaroon,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: primaryMaroon,
            ),
          ],
        );
      },
    );
  }

  void _handlePasswordUpdate() {
    if (!_passwordFormKey.currentState!.validate()) return;
    _updatePassword();
  }

  bool? _boolFromUser(String primaryKey, {String? fallbackKey}) {
    final value =
        widget.user[primaryKey] ??
        (fallbackKey == null ? null : widget.user[fallbackKey]);
    if (value is bool) return value;
    if (value is num) return value == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    return text == '1' || text == 'true' || text == 'yes';
  }

  Widget _buildLinkedInSection() {
    final linkedInSub =
        (widget.user['linkedin_sub'] ?? UserStore.value?['linkedin_sub'] ?? '')
            .toString()
            .trim();
    final linkedInEmail =
        (widget.user['linkedin_email'] ??
                UserStore.value?['linkedin_email'] ??
                widget.user['email'])
            .toString()
            .trim();
    final isLinked = linkedInSub.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A66C2),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LinkedIn',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLinked
                          ? 'Your alumni account is linked and can use Continue with LinkedIn for future sign-in.'
                          : 'Link your LinkedIn account once so you can use Continue with LinkedIn to sign in next time.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isLinked ? Icons.verified_outlined : Icons.info_outline,
                  color: isLinked ? Colors.green : primaryMaroon,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLinked
                        ? 'Linked to ${linkedInEmail.isNotEmpty ? linkedInEmail : 'your LinkedIn account'}'
                        : 'Not linked yet',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isLinked)
            const Text(
              'No further action is needed. Continue with LinkedIn will automatically recognize this account after approval.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          else
            ElevatedButton(
              onPressed: _isLinkingLinkedIn ? null : _startLinkedInLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A66C2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLinkingLinkedIn)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.link, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _isLinkingLinkedIn
                        ? 'Starting LinkedIn...'
                        : 'Link LinkedIn Account',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startLinkedInLink() async {
    final userId = int.tryParse('${widget.user['id']}') ?? 0;
    if (userId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine the current user.')),
      );
      return;
    }

    setState(() => _isLinkingLinkedIn = true);
    try {
      final launched = await LinkedInAuthService.startAccountLink(
        userId: userId,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'LinkedIn linking could not be started. Please verify the backend endpoint.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'LinkedIn linking is not ready yet. Please verify the backend configuration.',
          ),
        ),
      );
      debugPrint('LinkedIn link error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLinkingLinkedIn = false);
      }
    }
  }
}
