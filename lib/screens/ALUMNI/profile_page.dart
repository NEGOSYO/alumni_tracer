import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/activity_service.dart';
import '../../state/user_store.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  static const Color primaryMaroon = Color(0xFF4A152C);
  static const Color accentGold = Color(0xFFC5A046);
  static const Color lightBackground = Color(0xFFF7F8FA);

  static const List<String> _civilStatuses = [
    'Single',
    'Married',
    'Widowed',
    'Separated',
    'Prefer not to say',
  ];

  static const List<String> _degrees = ['BSIT', 'BSSW'];

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _alumniNumController;
  late final TextEditingController _majorController;
  late final TextEditingController _certificationsController;
  late final TextEditingController _linkedinUrlController;
  late final TextEditingController _facebookUrlController;
  late final TextEditingController _portfolioUrlController;

  late String _selectedCivilStatus;
  late String _selectedGradYear;
  late String _selectedDegree;
  String _currentResumeFileName = '';
  String _currentResumePath = '';
  String? _selectedResumeFileName;
  Uint8List? _selectedResumeBytes;

  List<String> get _yearOptions =>
      List.generate(35, (index) => (DateTime.now().year - index).toString());

  Map<String, dynamic> get _sourceUser => UserStore.value ?? widget.user;

  @override
  void initState() {
    super.initState();

    final user = _sourceUser;

    _firstNameController = TextEditingController(
      text: _readValue(user, ['firstName', 'first_name']).trim(),
    );
    _lastNameController = TextEditingController(
      text: _readValue(user, ['lastName', 'last_name']).trim(),
    );
    _emailController = TextEditingController(
      text: _readValue(user, ['email']).trim(),
    );
    _phoneController = TextEditingController(
      text: _readValue(user, ['phone']).trim(),
    );
    _addressController = TextEditingController(
      text: _readValue(user, ['address']).trim(),
    );
    _alumniNumController = TextEditingController(
      text: _readValue(user, [
        'alumniNumber',
        'alumni_number',
        'studentNumber',
        'student_number',
      ]).trim(),
    );

    final degree = _normalizeDegree(
      _readValue(user, ['degree', 'program', 'major']),
    );
    _selectedDegree = degree.isNotEmpty ? degree : _degrees.first;
    _majorController = TextEditingController(
      text: _readValue(user, ['major', 'program']).trim().isNotEmpty
          ? _readValue(user, ['major', 'program']).trim()
          : _selectedDegree,
    );
    _certificationsController = TextEditingController(
      text: _readValue(user, ['certifications']).trim(),
    );
    _linkedinUrlController = TextEditingController(
      text: _readValue(user, ['linkedinUrl', 'linkedin_url']).trim(),
    );
    _facebookUrlController = TextEditingController(
      text: _readValue(user, ['facebookUrl', 'facebook_url']).trim(),
    );
    _portfolioUrlController = TextEditingController(
      text: _readValue(user, ['portfolioUrl', 'portfolio_url']).trim(),
    );
    _currentResumeFileName = _readValue(user, [
      'resumeFilename',
      'resume_filename',
    ]).trim();
    _currentResumePath = _readValue(user, ['resumePath', 'resume_path']).trim();

    final civilStatus = _readCivilStatus(user);
    _selectedCivilStatus = _civilStatuses.contains(civilStatus)
        ? civilStatus
        : _civilStatuses.first;

    final gradYear = _readValue(user, [
      'gradYear',
      'year_graduated',
      'graduation_year',
    ]).trim();
    _selectedGradYear = _yearOptions.contains(gradYear)
        ? gradYear
        : (_yearOptions.isNotEmpty ? _yearOptions.first : '');
  }

  @override
  void dispose() {
    for (final controller in [
      _firstNameController,
      _lastNameController,
      _emailController,
      _phoneController,
      _addressController,
      _alumniNumController,
      _majorController,
      _certificationsController,
      _linkedinUrlController,
      _facebookUrlController,
      _portfolioUrlController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _readValue(Map<String, dynamic> user, List<String> keys) {
    for (final key in keys) {
      final value = user[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _readCivilStatus(Map<String, dynamic> user) {
    final candidates = [
      user['civilStatus'],
      user['civil_status'],
      // Only use `status` if it is not the account-approval status.
      (user['status']?.toString().toLowerCase() == 'approved' ||
              user['status']?.toString().toLowerCase() == 'pending')
          ? ''
          : user['status'],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return _civilStatuses.first;
  }

  String _normalizeDegree(String value) {
    final upper = value.trim().toUpperCase();
    if (upper.contains('BSIT')) return 'BSIT';
    if (upper.contains('BSSW')) return 'BSSW';
    return upper;
  }

  bool get _profileComplete {
    final requiredValues = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _selectedGradYear.trim(),
      _selectedDegree.trim(),
      _selectedCivilStatus.trim(),
    ];

    return requiredValues.every((value) => value.isNotEmpty);
  }

  Future<void> _pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    Uint8List? fileBytes = file.bytes;

    if ((fileBytes == null || fileBytes.isEmpty) && file.readStream != null) {
      final collected = <int>[];
      await for (final chunk in file.readStream!) {
        collected.addAll(chunk);
      }
      if (collected.isNotEmpty) {
        fileBytes = Uint8List.fromList(collected);
      }
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to read the selected resume/CV. Try another file or run flutter pub get first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedResumeBytes = fileBytes;
      _selectedResumeFileName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: lightBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final isNarrow = contentWidth < 800;
          final isStacked = contentWidth < 980;

          return SingleChildScrollView(
            padding: EdgeInsets.all(contentWidth < 600 ? 16 : 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(contentWidth < 600 ? 20 : 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryMaroon,
                          primaryMaroon.withValues(alpha: 0.88),
                        ],
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
                      crossAxisAlignment: isStacked
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: accentGold,
                            size: 34,
                          ),
                        ),
                        SizedBox(
                          width: isStacked ? 0 : 18,
                          height: isStacked ? 16 : 0,
                        ),
                        if (isStacked)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "My Profile",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isEditing
                                    ? "Update your personal and academic details"
                                    : "View and manage your personal information",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: _buildHeaderButton(),
                              ),
                            ],
                          )
                        else
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "My Profile",
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _isEditing
                                            ? "Update your personal and academic details"
                                            : "View and manage your personal information",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                _buildHeaderButton(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isEditing)
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _profileComplete
                              ? Colors.green.shade100
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            _profileComplete
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: _profileComplete
                                ? Colors.green
                                : Colors.orange,
                            size: 28,
                          ),
                          SizedBox(
                            width: isNarrow
                                ? double.infinity
                                : contentWidth - 180,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profileComplete
                                      ? "Profile Complete"
                                      : "Profile Incomplete",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _profileComplete
                                        ? Colors.green
                                        : Colors.orange.shade800,
                                  ),
                                ),
                                Text(
                                  _profileComplete
                                      ? "All required information has been provided"
                                      : "Please complete your profile so it reflects correctly on your dashboard",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _profileComplete
                                        ? Colors.green.shade700
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildProfileSection(
                    title: "Personal Information",
                    icon: Icons.person_outline,
                    children: [
                      if (isNarrow)
                        Column(
                          children: [
                            _buildField("First Name", _firstNameController),
                            const SizedBox(height: 20),
                            _buildField("Last Name", _lastNameController),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                "First Name",
                                _firstNameController,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildField(
                                "Last Name",
                                _lastNameController,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Email Address",
                        _emailController,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Contact Number",
                        _phoneController,
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Address",
                        _addressController,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownField(
                        label: "Civil Status",
                        value: _selectedCivilStatus,
                        items: _civilStatuses,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCivilStatus = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildProfileSection(
                    title: "Academic Information",
                    icon: Icons.school_outlined,
                    children: [
                      if (isNarrow)
                        Column(
                          children: [
                            _buildField(
                              "Alumni Number",
                              _alumniNumController,
                              helperText:
                                  "Assigned automatically by the system after registration approval.",
                              enabled: false,
                            ),
                            const SizedBox(height: 20),
                            _buildDropdownField(
                              label: "Graduation Year",
                              value: _selectedGradYear,
                              items: _yearOptions,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedGradYear = value);
                                }
                              },
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                "Alumni Number",
                                _alumniNumController,
                                helperText:
                                    "Assigned automatically by the system after registration approval.",
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildDropdownField(
                                label: "Graduation Year",
                                value: _selectedGradYear,
                                items: _yearOptions,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedGradYear = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Registered Degree / Program",
                        _majorController,
                        enabled: false,
                        helperText:
                            "This is assigned automatically from your approved registration and cannot be edited here.",
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildProfileSection(
                    title: "Career Documents",
                    icon: Icons.work_outline,
                    children: [
                      _buildResumeUploadCard(),
                      const SizedBox(height: 20),
                      _buildField(
                        "Certifications",
                        _certificationsController,
                        icon: Icons.workspace_premium_outlined,
                        helperText:
                            "List certifications, licenses, or short credentials separated by commas or new lines.",
                        maxLines: 4,
                        required: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildProfileSection(
                    title: "Professional Links",
                    icon: Icons.link_outlined,
                    children: [
                      _buildField(
                        "LinkedIn URL",
                        _linkedinUrlController,
                        icon: Icons.business_center_outlined,
                        required: false,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Facebook URL",
                        _facebookUrlController,
                        icon: Icons.facebook_outlined,
                        required: false,
                      ),
                      const SizedBox(height: 20),
                      _buildField(
                        "Portfolio / Website URL",
                        _portfolioUrlController,
                        icon: Icons.public_outlined,
                        required: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderButton() {
    if (_isEditing) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("Save Changes"),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () => setState(() => _isEditing = true),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text("Edit Profile"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryMaroon,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    String? feedbackMessage;
    bool saveSucceeded = true;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final civilStatus = _selectedCivilStatus.trim();
    final gradYear = _selectedGradYear.trim();
    final degree = _selectedDegree.trim();
    final major = _majorController.text.trim().isNotEmpty
        ? _majorController.text.trim()
        : degree;

    final localPatch = <String, dynamic>{
      'firstName': firstName,
      'first_name': firstName,
      'lastName': lastName,
      'last_name': lastName,
      'name': fullName.isEmpty ? (_sourceUser['name'] ?? '') : fullName,
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'civilStatus': civilStatus,
      'civil_status': civilStatus,
      'gradYear': gradYear,
      'year_graduated': gradYear,
      'graduation_year': gradYear,
      'degree': degree,
      'major': major,
      'program': degree,
      'certifications': _certificationsController.text.trim(),
      'linkedinUrl': _linkedinUrlController.text.trim(),
      'linkedin_url': _linkedinUrlController.text.trim(),
      'facebookUrl': _facebookUrlController.text.trim(),
      'facebook_url': _facebookUrlController.text.trim(),
      'portfolioUrl': _portfolioUrlController.text.trim(),
      'portfolio_url': _portfolioUrlController.text.trim(),
      'resumeFilename': _selectedResumeFileName ?? _currentResumeFileName,
      'resume_filename': _selectedResumeFileName ?? _currentResumeFileName,
      'resumePath': _currentResumePath,
      'resume_path': _currentResumePath,
    };

    UserStore.patch(localPatch);

    try {
      final rawUserId = UserStore.value?['id'] ?? widget.user['id'];
      final userId = int.tryParse('$rawUserId') ?? 0;

      if (userId > 0) {
        final response = await http.post(
          ApiService.uri('update_profile.php'),
          headers: ApiService.jsonHeaders(),
          body: jsonEncode({
            "userId": userId,
            ...localPatch,
            // Backend currently expects `status` for civil status.
            "status": civilStatus,
            if (_selectedResumeBytes != null &&
                (_selectedResumeFileName ?? '').isNotEmpty)
              "resume_base64": base64Encode(_selectedResumeBytes!),
            if (_selectedResumeBytes != null &&
                (_selectedResumeFileName ?? '').isNotEmpty)
              "resume_file_name": _selectedResumeFileName,
          }),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final status = decoded['status']?.toString().toLowerCase();
            if (status == 'success' && decoded['user'] is Map) {
              UserStore.patch(
                Map<String, dynamic>.from(decoded['user'] as Map),
              );
              final updatedUser = Map<String, dynamic>.from(
                decoded['user'] as Map,
              );
              _currentResumeFileName =
                  (updatedUser['resume_filename'] ??
                          updatedUser['resumeFilename'] ??
                          '')
                      .toString();
              _currentResumePath =
                  (updatedUser['resume_path'] ??
                          updatedUser['resumePath'] ??
                          '')
                      .toString();
              _selectedResumeBytes = null;
              _selectedResumeFileName = null;
              await ActivityService.logImportantFlow(
                action: 'profile_update',
                title:
                    '${UserStore.value?['name'] ?? fullName} updated their profile',
                type: 'Profile',
                userId: userId,
                userName: UserStore.value?['name']?.toString() ?? fullName,
                userEmail: UserStore.value?['email']?.toString(),
                role: UserStore.value?['role']?.toString(),
                metadata: {
                  'program': degree,
                  'graduation_year': gradYear,
                  'civil_status': civilStatus,
                  'resume_filename': _currentResumeFileName,
                },
              );
            } else if (status != null && status != 'success') {
              saveSucceeded = false;
              feedbackMessage =
                  decoded['message']?.toString().trim().isNotEmpty == true
                  ? decoded['message']?.toString().trim()
                  : "Failed to update profile.";
            }
          } else {
            saveSucceeded = false;
            feedbackMessage = "Unexpected response while updating profile.";
          }
        } else {
          saveSucceeded = false;
          feedbackMessage =
              "Failed to update profile (${response.statusCode}).";
        }
      }
    } catch (e) {
      saveSucceeded = false;
      feedbackMessage = "Error saving profile. Please try again.";
      debugPrint("Profile update error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = !saveSucceeded;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              feedbackMessage ??
                  (saveSucceeded
                      ? "Profile updated successfully"
                      : "Failed to update profile."),
            ),
          ),
        );
      }
    }
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryMaroon, size: 20),
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
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool enabled = true,
    String? helperText,
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 8),
        _isEditing && enabled
            ? TextFormField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (value) {
                  if (required && (value ?? '').trim().isEmpty) {
                    return "Required";
                  }
                  return null;
                },
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  controller.text.trim().isEmpty ? "N/A" : controller.text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 8),
        _isEditing
            ? DropdownButtonFormField<String>(
                initialValue: value.isNotEmpty ? value : null,
                items: items
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: onChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (selected) =>
                    (selected == null || selected.trim().isEmpty)
                    ? "Required"
                    : null,
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  value.trim().isEmpty ? "N/A" : value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
      ],
    );
  }

  Widget _buildResumeUploadCard() {
    final fileLabel =
        _selectedResumeFileName ??
        (_currentResumeFileName.isNotEmpty ? _currentResumeFileName : 'No resume/CV uploaded yet');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resume / CV',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload a PDF, DOC, or DOCX file so your profile is ready for future industry-sharing features.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            fileLabel,
            style: TextStyle(
              fontSize: 13,
              color: fileLabel == 'No resume/CV uploaded yet'
                  ? Colors.grey.shade700
                  : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickResumeFile,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(
                    _selectedResumeFileName == null
                        ? 'Upload Resume/CV'
                        : 'Replace Resume/CV',
                  ),
                ),
                if (_selectedResumeFileName != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedResumeFileName = null;
                        _selectedResumeBytes = null;
                      });
                    },
                    child: const Text('Clear Selection'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the file first, then click Save Changes to upload it.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
