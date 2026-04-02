import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import '../services/activity_service.dart';
import '../services/api_service.dart';
import '../services/linkedin_auth_service.dart';
import '../utils/email_validator.dart';
import '../utils/password_policy.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.linkedInPrefill});

  final LinkedInRegistrationPrefill? linkedInPrefill;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);

  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String? selectedProgram;
  String? selectedYear;
  bool isLoading = false;

  final List<String> programs = ['BSIT', 'BSSW'];
  final List<String> years = List.generate(
    10,
    (index) => (2026 - index).toString(),
  );

  bool get _hasLinkedInPrefill =>
      widget.linkedInPrefill != null && widget.linkedInPrefill!.hasImportedName;

  @override
  void initState() {
    super.initState();
    final prefill = widget.linkedInPrefill;
    if (prefill != null) {
      firstNameController.text = prefill.firstName;
      lastNameController.text = prefill.lastName;
      if (prefill.email.isNotEmpty) {
        emailController.text = prefill.email;
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        _showError("Passwords do not match.");
        return;
      }

      setState(() => isLoading = true);

      final url = ApiService.uri('register.php');

      try {
        final firstName = firstNameController.text.trim();
        final lastName = lastNameController.text.trim();
        final fullName = [
          firstName,
          lastName,
        ].where((part) => part.isNotEmpty).join(' ');

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "name": fullName,
            "first_name": firstName,
            "last_name": lastName,
            "email": emailController.text,
            "password": passwordController.text,
            "program": selectedProgram,
            "year_graduated": selectedYear,
            if (widget.linkedInPrefill != null) ...{
              "linkedin_sub": widget.linkedInPrefill!.linkedInSub,
              "linkedin_email": widget.linkedInPrefill!.email,
              "auth_provider": widget.linkedInPrefill!.source,
            },
          }),
        );

        Map<String, dynamic> data = <String, dynamic>{};
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          _showError(
            "Server returned an invalid response (${response.statusCode}).",
          );
          return;
        }

        if (response.statusCode == 200 && data['status'] == 'success') {
          await ActivityService.logImportantFlow(
            action: 'register',
            title: '$fullName submitted a registration request',
            type: 'Registration',
            userName: fullName,
            userEmail: emailController.text.trim(),
            role: 'alumni',
            description: 'New alumni registration awaiting admin approval.',
            metadata: {
              'program': selectedProgram,
              'year_graduated': selectedYear,
            },
          );
          _showSuccess();
        } else {
          _showError(
            data['message']?.toString() ??
                (response.statusCode == 200
                    ? "Registration failed"
                    : "Server Error: ${response.statusCode}"),
          );
        }
      } catch (e) {
        _showError("Check your internet or server connection.");
      }

      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Success"),
        content: const Text(
          "Account created. Wait for admin approval. Your alumni number will be assigned automatically.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 560 ? screenWidth - 32 : 500.0;
    final stackPasswords = screenWidth < 560;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/download.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/jmclogo.png',
                          height: 72,
                          width: 72,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Alumni Registration",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Enter your details to join the Tracer System",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (_hasLinkedInPrefill) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accentGold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                color: accentGold,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Your name was imported from LinkedIn. Complete the remaining fields below to finish your alumni registration.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _buildLabel("Account Information"),
                      Flex(
                        direction: stackPasswords
                            ? Axis.vertical
                            : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: stackPasswords ? 0 : 1,
                            child: _buildTextField(
                              firstNameController,
                              "First Name",
                              Icons.person_outline,
                              readOnly: _hasLinkedInPrefill,
                            ),
                          ),
                          SizedBox(
                            width: stackPasswords ? 0 : 10,
                            height: stackPasswords ? 15 : 0,
                          ),
                          Expanded(
                            flex: stackPasswords ? 0 : 1,
                            child: _buildTextField(
                              lastNameController,
                              "Last Name",
                              Icons.badge_outlined,
                              readOnly: _hasLinkedInPrefill,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(emailController, "Email", Icons.email),
                      const SizedBox(height: 15),
                      Flex(
                        direction: stackPasswords
                            ? Axis.vertical
                            : Axis.horizontal,
                        children: [
                          Expanded(
                            flex: stackPasswords ? 0 : 1,
                            child: _buildTextField(
                              passwordController,
                              "Password",
                              Icons.lock,
                              isPass: true,
                            ),
                          ),
                          SizedBox(
                            width: stackPasswords ? 0 : 10,
                            height: stackPasswords ? 15 : 0,
                          ),
                          Expanded(
                            flex: stackPasswords ? 0 : 1,
                            child: _buildTextField(
                              confirmPasswordController,
                              "Confirm",
                              Icons.lock_clock,
                              isPass: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildLabel("Academic Background"),
                      _buildDropdown(
                        "Select Program",
                        programs,
                        (val) => setState(() => selectedProgram = val),
                      ),
                      const SizedBox(height: 15),
                      _buildDropdown(
                        "Year Graduated",
                        years,
                        (val) => setState(() => selectedYear = val),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGold,
                            foregroundColor: primaryMaroon,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                  _hasLinkedInPrefill
                                      ? "COMPLETE REGISTRATION"
                                      : "REGISTER",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Already have an account? Login",
                          style: TextStyle(color: accentGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: accentGold,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPass = false,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPass,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline, color: accentGold.withValues(alpha: 0.9))
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentGold),
        ),
        filled: true,
        fillColor: readOnly ? Colors.white12 : Colors.white10,
      ),
      validator: (val) {
        final value = val ?? '';
        if (label == "Email") {
          return EmailValidator.validate(value);
        }
        if (label == "Password") {
          return PasswordPolicy.validate(value);
        }
        if (label == "Confirm") {
          if (value.trim().isEmpty) {
            return "Confirm password is required.";
          }
          if (value != passwordController.text) {
            return "Passwords do not match.";
          }
          return null;
        }
        if (value.trim().isEmpty) {
          return "$label is required.";
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      dropdownColor: primaryMaroon,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        filled: true,
        fillColor: Colors.white10,
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? "$hint is required." : null,
    );
  }
}
