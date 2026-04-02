import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/activity_service.dart';
import '../../services/api_service.dart';
import '../../state/user_store.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _provisionFormKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _newUserFirstNameController;
  late final TextEditingController _newUserLastNameController;
  late final TextEditingController _newUserEmailController;
  late final TextEditingController _newUserPasswordController;

  bool _emailAnnouncements = true;
  bool _emailReminders = true;
  bool _eventInvitations = false;
  bool _isSavingProfile = false;
  bool _isSavingSettings = false;
  bool _isSavingPassword = false;
  bool _isCreatingUser = false;
  String _provisionRole = 'dean';
  String _provisionProgram = 'BSIT';

  final Color bgLight = const Color(0xFFF8F9FA);
  final Color borderColor = const Color(0xFFE5E7EB);
  final Color fieldFillColor = const Color(0xFFF1F3F4);
  final Color darkButtonColor = const Color(0xFF0D0D1D);
  final Color accentGold = const Color(0xFFC5A046);

  Map<String, dynamic> get _user =>
      UserStore.value ?? const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: _readValue(['firstName', 'first_name']),
    );
    _lastNameController = TextEditingController(
      text: _readValue(['lastName', 'last_name']),
    );
    _emailController = TextEditingController(text: _readValue(['email']));
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _newUserFirstNameController = TextEditingController();
    _newUserLastNameController = TextEditingController();
    _newUserEmailController = TextEditingController();
    _newUserPasswordController = TextEditingController();

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newUserFirstNameController.dispose();
    _newUserLastNameController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    super.dispose();
  }

  String _readValue(List<String> keys) {
    for (final key in keys) {
      final value = _user[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  bool? _boolFromUser(String primaryKey, {String? fallbackKey}) {
    final value =
        _user[primaryKey] ?? (fallbackKey == null ? null : _user[fallbackKey]);
    if (value is bool) return value;
    if (value is num) return value == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    return text == '1' || text == 'true' || text == 'yes';
  }

  int get _userId => int.tryParse((_user['id'] ?? '').toString()) ?? 0;

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    if (_userId <= 0 || _isSavingProfile) return;

    setState(() => _isSavingProfile = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ');
    final email = _emailController.text.trim();

    try {
      final response = await http.post(
        ApiService.uri('update_profile.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'firstName': firstName,
          'lastName': lastName,
          'name': fullName,
          'email': email,
          'phone': _readValue(['phone']),
          'address': _readValue(['address']),
          'status': _readValue(['civilStatus', 'civil_status']),
          'gradYear': _readValue([
            'gradYear',
            'year_graduated',
            'graduation_year',
          ]),
          'degree': _readValue(['degree', 'program']),
          'major': _readValue(['major', 'program']),
          'program': _readValue(['program', 'degree']),
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == 'success') {
        final updatedUser = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : <String, dynamic>{};
        UserStore.patch({
          'name': fullName,
          'firstName': firstName,
          'first_name': firstName,
          'lastName': lastName,
          'last_name': lastName,
          'email': email,
          ...updatedUser,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin profile updated successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Failed to update admin profile.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating admin profile.')),
      );
      debugPrint('Admin profile update error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    if (_userId <= 0 || _isSavingSettings) return;
    setState(() => _isSavingSettings = true);

    try {
      final response = await http.post(
        ApiService.uri('update_settings.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'emailAnnouncements': _emailAnnouncements,
          'emailReminders': _emailReminders,
          'eventInvitations': _eventInvitations,
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == 'success') {
        final settings = data['settings'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['settings'])
            : <String, dynamic>{};
        UserStore.patch({
          ...settings,
          'email_announcements': settings['emailAnnouncements'],
          'email_reminders': settings['emailReminders'],
          'event_invitations': settings['eventInvitations'],
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings updated.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Failed to update settings.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating notification settings.')),
      );
      debugPrint('Admin settings update error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingSettings = false);
      }
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_userId <= 0 || _isSavingPassword) return;

    setState(() => _isSavingPassword = true);

    try {
      final response = await http.post(
        ApiService.uri('change_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
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
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Password updated successfully.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Failed to update password.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error updating password.')));
      debugPrint('Admin password update error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingPassword = false);
      }
    }
  }

  Future<void> _createPrivilegedUser() async {
    if (!_provisionFormKey.currentState!.validate()) return;
    if (_isCreatingUser) return;

    setState(() => _isCreatingUser = true);

    final firstName = _newUserFirstNameController.text.trim();
    final lastName = _newUserLastNameController.text.trim();
    final fullName = [firstName, lastName]
        .where((value) => value.isNotEmpty)
        .join(' ');
    final role = _provisionRole;
    final program = role == 'dean' ? _provisionProgram : '';

    try {
      final response = await http.post(
        ApiService.uri('admin_create_user.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'name': fullName,
          'email': _newUserEmailController.text.trim(),
          'password': _newUserPasswordController.text,
          'role': role,
          'program': program,
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == 'success') {
        await ActivityService.logImportantFlow(
          action: 'create_user',
          title:
              'Admin created a ${role == 'dean' ? 'Dean' : 'Admin'} account for $fullName',
          type: 'User Management',
          targetId: (data['user'] as Map?)?['id']?.toString() ?? '',
          targetType: role,
          description: role == 'dean'
              ? 'Assigned program: $program'
              : 'Privileged account created by admin.',
          metadata: {
            'program': program,
            'created_role': role,
            'email': _newUserEmailController.text.trim(),
            'target_user_name': fullName,
          },
        );

        if (!mounted) return;

        _newUserFirstNameController.clear();
        _newUserLastNameController.clear();
        _newUserEmailController.clear();
        _newUserPasswordController.clear();
        setState(() {
          _provisionRole = 'dean';
          _provisionProgram = 'BSIT';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Privileged account created.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Failed to create user.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error creating privileged account.')),
      );
      debugPrint('Admin create user error: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreatingUser = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = (_user['role'] ?? 'admin').toString();
    final isCompact = MediaQuery.of(context).size.width < 720;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F8FA), Color(0xFFF4F1F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 32,
          isCompact ? 16 : 24,
          isCompact ? 16 : 32,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 32),
            _buildSectionCard(
              title: 'Profile Information',
              icon: Icons.person_outline,
              child: Form(
                key: _profileFormKey,
                child: Column(
                  children: [
                    isCompact
                        ? Column(
                            children: [
                              _buildTextField(
                                'First Name',
                                controller: _firstNameController,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                'Last Name',
                                controller: _lastNameController,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'First Name',
                                  controller: _firstNameController,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildTextField(
                                  'Last Name',
                                  controller: _lastNameController,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Role', initialValue: role, enabled: false),
                    const SizedBox(height: 24),
                    _buildSolidButton(
                      _isSavingProfile ? 'Saving...' : 'Save Profile',
                      Icons.save_outlined,
                      _isSavingProfile ? null : _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Security',
              icon: Icons.lock_outline,
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      'Current Password',
                      controller: _currentPasswordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    isCompact
                        ? Column(
                            children: [
                              _buildTextField(
                                'New Password',
                                controller: _newPasswordController,
                                isPassword: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                'Confirm New Password',
                                controller: _confirmPasswordController,
                                isPassword: true,
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Required';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'New Password',
                                  controller: _newPasswordController,
                                  isPassword: true,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildTextField(
                                  'Confirm New Password',
                                  controller: _confirmPasswordController,
                                  isPassword: true,
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Required';
                                    }
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 8),
                    const Text(
                      'Password must be at least 6 characters long.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    _buildSolidButton(
                      _isSavingPassword ? 'Updating...' : 'Update Password',
                      Icons.key_outlined,
                      _isSavingPassword ? null : _updatePassword,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Notification Preferences',
              icon: Icons.notifications_outlined,
              child: Column(
                children: [
                  _buildSwitchRow(
                    'Email Announcements',
                    'Receive system and alumni announcement updates by email.',
                    _emailAnnouncements,
                    (value) => setState(() => _emailAnnouncements = value),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchRow(
                    'Email Reminders',
                    'Receive reminders about pending reviews and follow-ups.',
                    _emailReminders,
                    (value) => setState(() => _emailReminders = value),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchRow(
                    'Event Invitations',
                    'Receive invitation alerts for alumni and campus events.',
                    _eventInvitations,
                    (value) => setState(() => _eventInvitations = value),
                  ),
                  const SizedBox(height: 24),
                  _buildSolidButton(
                    _isSavingSettings ? 'Saving...' : 'Save Preferences',
                    Icons.notifications_active_outlined,
                    _isSavingSettings ? null : _saveNotificationSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'User Provisioning',
              icon: Icons.admin_panel_settings_outlined,
              child: Form(
                key: _provisionFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create admin or dean accounts without affecting alumni registration. Dean accounts must be assigned to one program.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    isCompact
                        ? Column(
                            children: [
                              _buildTextField(
                                'First Name',
                                controller: _newUserFirstNameController,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                'Last Name',
                                controller: _newUserLastNameController,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'First Name',
                                  controller: _newUserFirstNameController,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildTextField(
                                  'Last Name',
                                  controller: _newUserLastNameController,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Email Address',
                      controller: _newUserEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Required';
                        final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!pattern.hasMatch(email)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Temporary Password',
                      controller: _newUserPasswordController,
                      isPassword: true,
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Required';
                        if ((value ?? '').length < 8) {
                          return 'Minimum 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    isCompact
                        ? Column(
                            children: [
                              _buildDropdownField(
                                label: 'Role',
                                value: _provisionRole,
                                items: const ['dean', 'admin'],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _provisionRole = value);
                                },
                              ),
                              if (_provisionRole == 'dean') ...[
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  label: 'Assigned Program',
                                  value: _provisionProgram,
                                  items: const ['BSIT', 'BSSW'],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _provisionProgram = value);
                                  },
                                ),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Role',
                                  value: _provisionRole,
                                  items: const ['dean', 'admin'],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _provisionRole = value);
                                  },
                                ),
                              ),
                              if (_provisionRole == 'dean') ...[
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildDropdownField(
                                    label: 'Assigned Program',
                                    value: _provisionProgram,
                                    items: const ['BSIT', 'BSSW'],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _provisionProgram = value);
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                    const SizedBox(height: 24),
                    _buildSolidButton(
                      _isCreatingUser ? 'Creating...' : 'Create Account',
                      Icons.person_add_alt_1_outlined,
                      _isCreatingUser ? null : _createPrivilegedUser,
                    ),
                  ],
                ),
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
          colors: [darkButtonColor, darkButtonColor.withValues(alpha: 0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: darkButtonColor.withValues(alpha: 0.18),
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
                    Icons.shield_outlined,
                    color: accentGold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your administrator account, password, and notification preferences in a cleaner and more presentable settings layout.',
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
                    Icons.shield_outlined,
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
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your administrator account, password, and notification preferences in a cleaner and more presentable settings layout.',
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
        border: Border.all(color: borderColor),
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
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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

  Widget _buildTextField(
    String label, {
    TextEditingController? controller,
    String? initialValue,
    bool enabled = true,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final effectiveValidator =
        validator ??
        (enabled
            ? (String? value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Required';
                }
                return null;
              }
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled,
          obscureText: isPassword,
          keyboardType: keyboardType,
          validator: effectiveValidator,
          style: TextStyle(color: enabled ? Colors.black87 : Colors.grey),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (selected) {
            if ((selected ?? '').trim().isEmpty) {
              return 'Required';
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
    ValueChanged<bool> onChanged,
  ) {
    final isCompact = MediaQuery.of(context).size.width < 380;
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
              onChanged: onChanged,
              activeThumbColor: Colors.black,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(height: 4),
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
            onChanged: onChanged,
            activeThumbColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSolidButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: onPressed == null ? Colors.grey.shade500 : darkButtonColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
