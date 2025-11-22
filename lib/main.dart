import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

import 'screens/login_pg.dart';
import 'screens/admin/admin_sos_detail_pg.dart'; // notification navigation

import 'package:google_fonts/google_fonts.dart';

//Global navigator key (for notification navigation)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

//Background message handler (MUST be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Missing options
  );

  debugPrint('Background message received: ${message.messageId}');

  // Check if SOS alert
  if (message.data['type'] == 'sos_alert') {
    await NotificationService.showSosNotification(
      alertId: message.data['alertId'] ?? '',
      studentName: message.data['studentName'] ?? 'Unknown',
      studentId: message.data['studentId'] ?? 'N/A',
      location: message.data['location'] ?? 'Unknown location',
      category: message.data['category'] ?? 'emergency',
    );
  }
}

// Main function
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Missing options
  );

  // Initialize notifications
  await NotificationService.initialize();

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages (when app is open)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');

    if (message.data['type'] == 'sos_alert') {
      await NotificationService.showSosNotification(
        alertId: message.data['alertId'] ?? '',
        studentName: message.data['studentName'] ?? 'Unknown',
        studentId: message.data['studentId'] ?? 'N/A',
        location: message.data['location'] ?? 'Unknown location',
        category: message.data['category'] ?? 'emergency',
      );
    }
  });

  runApp(const MyApp());
}

// MyApp widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dormease App',
      navigatorKey: navigatorKey, // Enables notification navigation
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.dangrekTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1800AD),
          primary: const Color(0xFF1800AD),
          secondary: const Color(0xFF38B6FF),
          background: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: GoogleFonts.dangrek(
            color: const Color(0xFF1800AD),
          ),
          prefixIconColor: const Color(0xFF1800AD),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Color(0xFF1800AD),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Color(0xFF1800AD),
              width: 2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1800AD),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: GoogleFonts.dangrek(fontSize: 18),
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
          ),
        ),
      ),
      home: const LoginScreen(),
      // Route for notification navigation
      routes: {
        '/admin_sos_detail': (context) {
          final alertId = ModalRoute.of(context)!.settings.arguments as String;
          return AdminSosDetailPage(alertId: alertId);
        },
      },
    );
  }
}