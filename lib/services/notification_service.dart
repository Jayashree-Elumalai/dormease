import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data'; //  For Int64List (vibration pattern)

class NotificationService {
  // Flutter Local Notifications plugin instance
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  /// Initialize local notifications
  static Future<void> initialize() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin with callback for when user taps notification
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for SOS (high priority)
    //Android 8.0+ requires channels to categorize notifications
    if (Platform.isAndroid) {
      //  Create vibration pattern using Int64List
      // Continuous vibration pattern (vibrates for 1 second, pauses 1 second, repeats)
      final Int64List vibrationPattern = Int64List.fromList([0, 1000, 1000, 1000, 1000, 1000]);

      // CHANNEL: High-priority SOS notifications
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'sos_alerts', // id
        'SOS Alerts', // title
        description: 'Emergency SOS notifications from students',
        importance: Importance.max, // Highest priority
        playSound: true, // Play notification sound
        enableVibration: true, // Vibrate device
        enableLights: true,//flash LED (if available)
        ledColor: const Color(0xFFFF0000), // Red LED (if available)
        vibrationPattern: vibrationPattern, //Custom vibration
      );

      // Register channel with Android system
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('Notification channel created: sos_alerts');
    }

    // Request permissions (Android 13+)-introduced runtime notification permission
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Handle notification tap (when admin clicks notification)
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Payload contains alertId - navigate to SOS detail page
    if (response.payload != null) {
      // handle navigation in main.dart using a global navigator key
      navigatorKey.currentState?.pushNamed(
        '/admin_sos_detail',// Route name
        arguments: response.payload, // Pass alertId as argument
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
    debugPrint('Showing SOS notification for alert: $alertId');

    // Format category emoji
    String categoryEmoji = _getCategoryEmoji(category);

    // big text style for longer content
    final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      '$studentName ($studentId) needs immediate help at $location',
      htmlFormatBigText: true,
      contentTitle: '🚨 SOS EMERGENCY - $categoryEmoji $category',
      htmlFormatContentTitle: true,
      summaryText: 'Tap to respond',
      htmlFormatSummaryText: true,
    );

    // ANDROID: Notification settings
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sos_alerts', // channel id (must match above)
      'SOS Alerts',
      channelDescription: 'Emergency SOS notifications from students',
      importance: Importance.max, // Maximum importance
      priority: Priority.max,  // Maximum priority
      ticker: 'SOS Emergency Alert', // Accessibility text
      playSound: true, // Play sound
      enableVibration: true, // Vibrate
      enableLights: true, // LED (if available)
      color: const Color(0xFFFF0000), // Red if available
      colorized: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm, // Bypass Do Not Disturb
      visibility: NotificationVisibility.public, // Show on lock screen
      autoCancel: false, // Don't auto-dismiss
      ongoing: true, // Can't be swiped away
      styleInformation: bigTextStyle, // Prominent notification style
    );

    // iOS: Notification settings
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical, // Bypass silent mode
    );
    // Combine platform-specific details
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    // SHOW NOTIFICATION
    await _notifications.show(
      alertId.hashCode, // unique ID based on alert
      '🚨 SOS EMERGENCY - $categoryEmoji $category',
      '$studentName ($studentId) at $location',
      platformDetails,// Platform-specific settings
      payload: alertId, // Pass alertId for navigation
    );

    debugPrint('Notification shown successfully');
  }

  /// Cancel notification (when alert is resolved)
  static Future<void> cancelNotification(String alertId) async {
    await _notifications.cancel(alertId.hashCode);
    debugPrint('Notification cancelled: $alertId');
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

// Global navigator key (defined here, used in main.dart)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();