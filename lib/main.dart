import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'state/user_store.dart';
import 'services/linkedin_auth_service.dart';
import 'screens/landing_page.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final linkedInResult = LinkedInAuthService.currentResult();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alumni Tracer System',
      theme: ThemeData(
        primaryColor: const Color(0xFF4A152C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A152C),
          primary: const Color(0xFF4A152C),
          secondary: const Color(0xFFC5A046),
        ),
        useMaterial3: true,
      ),
      home: linkedInResult?.isLoginSuccess == true
          ? _LinkedInLoginBootstrap(user: linkedInResult!.user!)
          : linkedInResult?.isRegistrationPrefill == true
          ? RegisterPage(linkedInPrefill: linkedInResult!.prefill)
          : linkedInResult?.shouldOpenLoginPage == true
          ? LoginPage(linkedInResult: linkedInResult)
          : FutureBuilder<Map<String, dynamic>?>(
              future: AuthService.restoreSession(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final user = snapshot.data;
                if (user == null) {
                  return const LandingPage();
                }

                return AuthService.homeForUser(user);
              },
            ),
    );
  }
}

class _LinkedInLoginBootstrap extends StatefulWidget {
  const _LinkedInLoginBootstrap({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_LinkedInLoginBootstrap> createState() =>
      _LinkedInLoginBootstrapState();
}

class _LinkedInLoginBootstrapState extends State<_LinkedInLoginBootstrap> {
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await UserStore.clearPersisted();
    await AuthService.storeSession(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AuthService.homeForUser(widget.user);
      },
    );
  }
}
