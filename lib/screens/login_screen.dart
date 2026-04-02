import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart';
import '../services/activity_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/linkedin_auth_service.dart';
import '../utils/email_validator.dart';
import '../utils/password_policy.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.linkedInResult});

  final LinkedInAuthResult? linkedInResult;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Color primaryMaroon = const Color(0xFF4A152C);
  final Color accentGold = const Color(0xFFC5A046);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isLinkedInLoading = false;

  @override
  void initState() {
    super.initState();
    final linkedInEmail = widget.linkedInResult?.email.trim() ?? '';
    if (linkedInEmail.isNotEmpty) {
      _emailController.text = linkedInEmail;
    }
  }

  Future<void> _handleLogin() async {
    final emailError = EmailValidator.validate(_emailController.text);
    if (emailError != null) {
      _showError(emailError);
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError("Password is required.");
      return;
    }

    setState(() => _isLoading = true);
    final url = ApiService.uri('login.php');

    try {
      final response = await http.post(
        url,
        headers: ApiService.jsonHeaders(),
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(response.body);
        data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        final snippet = response.body.trim();
        _showError(
          "Server returned an invalid response (${response.statusCode})."
          "${snippet.isNotEmpty ? "\n\n$snippet" : ""}",
        );
        return;
      }

      if (response.statusCode == 200 &&
          data['status'] == 'success' &&
          data['user'] != null) {
        final user = Map<String, dynamic>.from(data['user']);
        final accessToken = (data['access_token'] ?? data['token'] ?? '')
            .toString()
            .trim();
        final expiresAt = (data['expires_at'] ?? '').toString().trim();
        if (accessToken.isNotEmpty) {
          user['access_token'] = accessToken;
        }
        if (expiresAt.isNotEmpty) {
          user['expires_at'] = expiresAt;
        }
        final role = (user['role'] ?? 'alumni').toString().toLowerCase();
        await AuthService.storeSession(user);
        await ActivityService.logImportantFlow(
          action: 'login',
          title: '${user['name'] ?? 'A user'} logged in',
          type: 'Authentication',
          userId: int.tryParse(
            (user['id'] ?? user['user_id'] ?? '').toString(),
          ),
          userName: user['name']?.toString(),
          userEmail: user['email']?.toString(),
          role: role,
        );
        _navigateTo(role, user);
      } else {
        _showError(
          data['message']?.toString() ??
              (response.statusCode == 200
                  ? "Unable to sign in with the provided credentials."
                  : "Server Error: ${response.statusCode}"),
        );
      }
    } catch (e) {
      _showError("Check your internet or server connection.");
      debugPrint("Login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateTo(String role, Map<String, dynamic> user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AuthService.homeForUser(user)),
    );
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

  Future<Map<String, dynamic>> _requestForgotPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        ApiService.uri('forgot_password.php'),
        headers: ApiService.jsonHeaders(),
        body: jsonEncode({
          "email": email.trim(),
          "newPassword": newPassword,
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      return {
        'ok': response.statusCode == 200,
        'message':
            data['message']?.toString() ??
            (response.statusCode == 200
                ? "Password reset successful."
                : "Unable to reset password."),
      };
    } catch (e) {
      debugPrint("Forgot password error: $e");
      return {
        'ok': false,
        'message': 'Unable to reset password right now.',
      };
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPasswordVisible = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogInnerContext, setDialogState) => AlertDialog(
          title: const Text("Forgot Password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (value) => EmailValidator.validate(value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(
                        () => isPasswordVisible = !isPasswordVisible,
                      ),
                    ),
                  ),
                  validator: (value) => PasswordPolicy.validate(
                    value ?? '',
                    fieldLabel: 'New password',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !isPasswordVisible,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Confirm password is required.';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      final result = await _requestForgotPassword(
                        email: emailController.text,
                        newPassword: newPasswordController.text,
                      );
                      if (!mounted) return;
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(
                            result['ok'] == true
                                ? "Password Reset"
                                : "Reset Failed",
                          ),
                          content: Text(
                            result['message']?.toString() ??
                                'Unable to reset password.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Reset Password"),
            ),
          ],
        ),
      ),
    ).then((_) {
      emailController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Future<void> _startLinkedInSignUp() async {
    setState(() => _isLinkedInLoading = true);
    try {
      final launched = await LinkedInAuthService.startRegistration();
      if (!launched && mounted) {
        _showError(
          "LinkedIn sign-up could not be started. Please verify your backend LinkedIn endpoint first.",
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(
          "LinkedIn sign-up is not ready yet. Please configure the LinkedIn developer app and backend callback first.",
        );
      }
      debugPrint("LinkedIn sign-up error: $e");
    } finally {
      if (mounted) setState(() => _isLinkedInLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 480 ? screenWidth - 32 : 400.0;
    final linkedInMessage = widget.linkedInResult?.message.trim() ?? '';
    final linkedInError = widget.linkedInResult?.error.trim() ?? '';
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
          Container(color: Colors.black.withValues(alpha: 0.3)),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(40),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryMaroon.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 16),
                    const Text(
                      "ALUMNI TRACER",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Graduate Outcomes Tracking System",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (linkedInMessage.isNotEmpty || linkedInError.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: linkedInError.isNotEmpty
                                ? Colors.orangeAccent.withValues(alpha: 0.45)
                                : accentGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          linkedInMessage.isNotEmpty
                              ? linkedInMessage
                              : 'LinkedIn sign-in could not be completed. Please try again.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _showForgotPasswordDialog,
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: accentGold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          foregroundColor: primaryMaroon,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "ALUMNI SIGN-UP",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentGold.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isLinkedInLoading
                                  ? null
                                  : _startLinkedInSignUp,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF0A66C2)),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLinkedInLoading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0A66C2),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A66C2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "in",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      _isLinkedInLoading
                                          ? "Starting LinkedIn..."
                                          : "Continue with LinkedIn",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              const Text(
                                "New Alumni User?",
                                style: TextStyle(color: Colors.white70),
                              ),
                              const Text(
                                "Register",
                                style: TextStyle(color: Colors.white70),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  "here",
                                  style: TextStyle(
                                    color: accentGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        prefixIcon: Icon(icon, color: accentGold, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentGold, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}
