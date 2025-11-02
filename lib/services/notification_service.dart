import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data'; // ✅ ADDED: For Int64List

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  /// Initialize local notifications
  static Future<void> initialize() async {
    // ✅ Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // ✅ iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ✅ Create notification channel for SOS (high priority)
    if (Platform.isAndroid) {
      // ✅ FIXED: Create vibration pattern using Int64List
      final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'sos_alerts', // id
        'SOS Alerts', // title
        description: 'Emergency SOS notifications from students',
        importance: Importance.max, // ✅ Highest priority
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFFF0000), // ✅ Red LED
        vibrationPattern: vibrationPattern, // ✅ Use variable
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Notification channel created: sos_alerts');
    }

    // ✅ Request permissions (Android 13+)
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Handle notification tap (when admin clicks notification)
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // ✅ Payload contains alertId - navigate to SOS detail page
    if (response.payload != null) {
      // We'll handle navigation in main.dart using a global navigator key
      navigatorKey.currentState?.pushNamed(
        '/admin_sos_detail',
        arguments: response.payload, // alertId
      );
    }
  }

  /// Show SOS notification (called by FCM handler)
  static Future<void> showSosNotification({
    required String alertId,
    required String studentName,
    required String studentId,
    required String location,
    required String category,
  }) async {
    debugPrint('📢 Showing SOS notification for alert: $alertId');

    // ✅ Format category emoji
    String categoryEmoji = _getCategoryEmoji(category);

    // ✅ Create big text style for longer content
    final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      '$studentName ($studentId) needs immediate help at $location',
      htmlFormatBigText: true,
      contentTitle: '🚨 SOS EMERGENCY - $categoryEmoji $category',
      htmlFormatContentTitle: true,
      summaryText: 'Tap to respond',
      htmlFormatSummaryText: true,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sos_alerts', // channel id (must match above)
      'SOS Alerts',
      channelDescription: 'Emergency SOS notifications from students',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'SOS Emergency Alert',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: const Color(0xFFFF0000), // Red
      colorized: true,
      fullScreenIntent: true, // ✅ CRITICAL: Shows full-screen even when locked
      category: AndroidNotificationCategory.alarm, // ✅ Bypass Do Not Disturb
      visibility: NotificationVisibility.public,
      autoCancel: false, // ✅ Don't auto-dismiss
      ongoing: true, // ✅ Can't be swiped away
      styleInformation: bigTextStyle, // ✅ ADDED: Prominent notification style
      // sound: RawResourceAndroidNotificationSound('sos_alert'), // ✅ Uncomment when you add custom sound
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // sound: 'sos_alert.wav', // ✅ Uncomment when you add custom sound
      interruptionLevel: InterruptionLevel.critical, // ✅ Bypass silent mode
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alertId.hashCode, // unique ID based on alert
      '🚨 SOS EMERGENCY - $categoryEmoji $category',
      '$studentName ($studentId) at $location',
      platformDetails,
      payload: alertId, // ✅ Pass alertId for navigation
    );

    debugPrint('✅ Notification shown successfully');
  }

  /// Cancel notification (when alert is resolved)
  static Future<void> cancelNotification(String alertId) async {
    await _notifications.cancel(alertId.hashCode);
    debugPrint('✅ Notification cancelled: $alertId');
  }

  /// Get category emoji
  static String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'safety':
        return '⚠️';
      default:
        return '❓';
    }
  }
}

// ✅ Global navigator key (defined here, used in main.dart)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();