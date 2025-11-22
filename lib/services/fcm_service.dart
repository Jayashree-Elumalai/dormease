import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and save token to Firestore
  static Future<void> initializeFCM() async {
    try {
      debugPrint('Starting FCM initialization...');
      // Request notification permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true, // Show notification alerts
        announcement: false,
        badge: true, // Show badge count on app icon
        carPlay: false,
        criticalAlert: false, // Critical alerts (special permission needed)
        provisional: false, // Provisional (silent) notifications
        sound: true, // Play notification sound
      );

      debugPrint(' FCM permission status: ${settings.authorizationStatus}');

      // Check permission status
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM: User granted provisional permission');
      } else {
        debugPrint('FCM: User declined permission');
        return;
      }

      // Get FCM token
      debugPrint(' Requesting FCM token...');
      String? token = await _messaging.getToken();

      if (token != null) {
        debugPrint('FCM Token received: $token');
        debugPrint(' Saving token to Firestore...');
        //Save token to Firestore (so Cloud Function can send notifications)
        await _saveFCMToken(token);
        debugPrint('Token save operation completed');
      } else {
        debugPrint('FCM: Failed to get token');

        // RETRY: Try again after 2 seconds
        debugPrint('Retrying FCM token request in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
        token = await _messaging.getToken();

        if (token != null) {
          debugPrint('FCM Token received on retry: $token');
          await _saveFCMToken(token);
        } else {
          debugPrint(' FCM: Token still null after retry');
        }
      }

      // Listen for token refresh-FCM tokens can expire or change
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveFCMToken(newToken);// Update Firestore with new token
      });
      debugPrint('FCM initialization complete');
    } catch (e) {
      debugPrint('FCM initialization error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveFCMToken(String token) async {
    try {
      debugPrint('Attempting to save FCM token...');

      // Get current logged-in user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('FCM: No user logged in');
        return;
      }

      debugPrint(' Current user UID: ${user.uid}'); // ADDED
      // Reference to user doc in Firestore
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // SIMPLIFIED: Add token. Just set/update the array
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true)); // merge: true preserves other fields

      debugPrint('FCM: Token saved to Firestore');

      // VERIFY: Read back to confirm
      final doc = await userRef.get();
      final tokens = doc.data()?['fcmTokens'] as List?;
      debugPrint('Verification: fcmTokens in Firestore: $tokens');

    } catch (e) {
      debugPrint(' FCM: Error saving token: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  /// Remove FCM token from Firestore (call on logout)
  static Future<void> removeFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      // Get current device's token
      String? token = await _messaging.getToken();
      if (token == null) return;
      // Remove token from Firestore array
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

      debugPrint('FCM: Token removed from Firestore');
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  /// Delete FCM token from device (call on logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FCM: Token deleted from device');
    } catch (e) {
      debugPrint('FCM: Error deleting token: $e');
    }
  }
}