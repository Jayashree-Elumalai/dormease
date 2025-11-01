import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and save token to Firestore
  static Future<void> initializeFCM() async {
    try {
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

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCM: User granted provisional permission');
      } else {
        debugPrint('❌ FCM: User declined permission');
        return;
      }

      // Get FCM token
      String? token = await _messaging.getToken();

      if (token != null) {
        debugPrint('✅ FCM Token: $token');
        await _saveFCMToken(token);
      } else {
        debugPrint('❌ FCM: Failed to get token');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _saveFCMToken(newToken);
      });
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
    }
  }

  /// Save FCM token to Firestore user document
  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ FCM: No user logged in');
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Check if fcmTokens field exists
      final doc = await userRef.get();

      if (!doc.exists) {
        debugPrint('❌ FCM: User document does not exist');
        return;
      }

      final data = doc.data();

      // If fcmTokens doesn't exist, create it
      if (data == null || !data.containsKey('fcmTokens')) {
        await userRef.update({
          'fcmTokens': [token],
        });
        debugPrint('✅ FCM: Created fcmTokens array with token');
      } else {
        // Add token to array (arrayUnion prevents duplicates)
        await userRef.update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
        debugPrint('✅ FCM: Token added to fcmTokens array');
      }
    } catch (e) {
      debugPrint('❌ FCM: Error saving token: $e');
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