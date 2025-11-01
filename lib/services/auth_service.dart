import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'fcm_service.dart';
import '../screens/login_pg.dart';

class AuthService {
  /// Centralized logout - call this from any logout button
  static Future<void> logout(BuildContext context) async {
    try {
      // ✅ Step 1: Remove FCM token from Firestore
      await FCMService.removeFCMToken();

      // ✅ Step 2: Delete FCM token from device
      await FCMService.deleteToken();

      // ✅ Step 3: Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // ✅ Step 4: Navigate to login screen
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      // Still try to navigate even if token removal fails
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }
}