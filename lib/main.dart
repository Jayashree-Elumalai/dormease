import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


import 'screens/login_pg.dart';
import 'screens/student/register_pg.dart';
import 'screens/verify_email_pg.dart';
import 'screens/student/home_pg.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dormease App',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.dangrekTextTheme(), // Dangrek
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1800AD), // navy as base
          primary: const Color(0xFF1800AD), // navy
          secondary: const Color(0xFF38B6FF), // bright blue
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
    );
  }
}


