import 'package:flutter/material.dart';
import '../screens/landing_page.dart';
import '../screens/ADMIN/admin_main_layout.dart';
import '../screens/ALUMNI/alumni_main_layout.dart';
import '../screens/DEAN/dean_main_layout.dart';
import 'activity_service.dart';
import '../state/user_store.dart';

class AuthService {
  static Future<Map<String, dynamic>?> restoreSession() {
    return UserStore.restorePersisted();
  }

  static Future<void> storeSession(Map<String, dynamic> user) {
    return UserStore.setAndPersist(user);
  }

  static Widget homeForUser(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'alumni').toString().toLowerCase();
    if (role == 'admin') {
      return AdminMainLayout(user: user);
    }
    if (role == 'dean') {
      return DeanMainLayout(user: user);
    }
    return AlumniMainLayout(user: user);
  }

  /// Centralized logout function that all user roles use
  static Future<void> logout(BuildContext context) async {
    if (!context.mounted) return;

    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (confirmLogout ?? false) {
      final currentUser = UserStore.value;
      await ActivityService.logImportantFlow(
        action: 'logout',
        title: '${currentUser?['name'] ?? 'A user'} logged out of the portal',
        type: 'Authentication',
        userId: int.tryParse(
          (currentUser?['id'] ?? currentUser?['user_id'] ?? '').toString(),
        ),
        userName: currentUser?['name']?.toString(),
        userEmail: currentUser?['email']?.toString(),
        role: currentUser?['role']?.toString(),
      );
      if (!context.mounted) return;
      await UserStore.clearPersisted();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
    }
  }
}
