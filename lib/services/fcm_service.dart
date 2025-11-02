import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and save token to Firestore
  static Future<void> initializeFCM() async {
    try {
      debugPrint('🔵 Starting FCM initialization...');
      // Request permission (iOS/Web)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔵 FCM permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCM: User granted provisional permission');
      } else {
        debugPrint('❌ FCM: User declined permission');
        return;
      }

      // Get FCM token
      debugPrint('🔵 Requesting FCM token...');
      String? token = await _messaging.getToken();

      if (token != null) {
        debugPrint('✅ FCM Token received: $token');
        debugPrint('🔵 Saving token to Firestore...');
        await _saveFCMToken(token);
        debugPrint('✅ Token save operation completed');
      } else {
        debugPrint('❌ FCM: Failed to get token');

        // ✅ RETRY: Try again after 2 seconds
        debugPrint('🔄 Retrying FCM token request in 2 seconds...'); // ✅ ADDED
        await Future.delayed(const Duration(seconds: 2));
        token = await _messaging.getToken();

        if (token != null) {
          debugPrint('✅ FCM Token received on retry: $token');
          await _saveFCMToken(token);
        } else {
          debugPrint('❌ FCM: Token still null after retry');
        }
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _saveFCMToken(newToken);
      });
      debugPrint('✅ FCM initialization complete');
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveFCMToken(String token) async {
    try {
      debugPrint('🔵 Attempting to save FCM token...'); // ✅ ADDED

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ FCM: No user logged in');
        return;
      }

      debugPrint('🔵 Current user UID: ${user.uid}'); // ✅ ADDED

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // ✅ SIMPLIFIED: Just set/update the array, don't check first
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true)); // ✅ merge: true preserves other fields

      debugPrint('✅ FCM: Token saved to Firestore');

      // ✅ VERIFY: Read back to confirm
      final doc = await userRef.get();
      final tokens = doc.data()?['fcmTokens'] as List?;
      debugPrint('🔍 Verification: fcmTokens in Firestore: $tokens'); // ✅ ADDED

    } catch (e) {
      debugPrint('❌ FCM: Error saving token: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}'); // ✅ ADDED
    }
  }

  /// Remove FCM token from Firestore (call on logout)
  static Future<void> removeFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

      debugPrint('✅ FCM: Token removed from Firestore');
    } catch (e) {
      debugPrint('❌ FCM: Error removing token: $e');
    }
  }

  /// Delete FCM token from device (call on logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('✅ FCM: Token deleted from device');
    } catch (e) {
      debugPrint('❌ FCM: Error deleting token: $e');
    }
  }
}