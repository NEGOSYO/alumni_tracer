import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
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

  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
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

  Future<void> _updateToggle(String key, bool value) async {
    try {
      final response = await http.post(
        ApiService.uri('update_settings.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.user['id'],
          "setting": key,
          "value": value ? 1 : 0,
        }),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (data['settings'] is Map<String, dynamic>) {
          final settings = Map<String, dynamic>.from(data['settings']);
          UserStore.patch({
            ...settings,
            'email_announcements': settings['emailAnnouncements'],
            'email_reminders': settings['emailReminders'],
            'event_invitations': settings['eventInvitations'],
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Settings updated!")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Error')));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Settings update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update settings")),
      );
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    try {
      final response = await http.post(
        ApiService.uri('change_password.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.user['id'],
          "currentPassword": _currentPasswordController.text,
          "newPassword": _newPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200 && data['status'] == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Password updated!")));
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to update password"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Password update error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error updating password")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 720;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(),
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
                    _buildPasswordField("New Password", _newPasswordController),
                    const SizedBox(height: 20),
                    _buildPasswordField(
                      "Confirm New Password",
                      _confirmPasswordController,
                      isConfirm: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updatePassword,
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
                    "emailAnnouncements",
                    "Receive emails about new announcements",
                    _emailAnnouncements,
                    (v) => setState(() => _emailAnnouncements = v),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchRow(
                    "Email Reminders",
                    "emailReminders",
                    "Receive reminders about tracer form and updates",
                    _emailReminders,
                    (v) => setState(() => _emailReminders = v),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchRow(
                    "Event Invitations",
                    "eventInvitations",
                    "Receive invitations to alumni events",
                    _eventInvitations,
                    (v) => setState(() => _eventInvitations = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final isCompact = MediaQuery.of(context).size.width < 760;
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
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
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
                  "Manage your dean account security and alerts with the same polished presentation as the analytics modules.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 18),
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
                        "Manage your dean account security and alerts with the same polished presentation as the analytics modules.",
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
            if (value == null || value.isEmpty) return "This field is required";
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
    String label,
    String settingKey,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    final isCompact = MediaQuery.of(context).size.width < 380;
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: value,
              onChanged: (v) {
                onChanged(v);
                _updateToggle(settingKey, v);
              },
              activeThumbColor: primaryMaroon,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
        Align(
          alignment: Alignment.centerRight,
          child: Switch(
            value: value,
            onChanged: (v) {
              onChanged(v);
              _updateToggle(settingKey, v);
            },
            activeThumbColor: primaryMaroon,
          ),
        ),
      ],
    );
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
}
