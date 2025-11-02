import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'student/home_pg.dart';
import 'admin/admin_home_pg.dart';
import 'student/register_pg.dart';
import 'verify_email_pg.dart';
import 'waiting_approval_pg.dart';
import '/services/fcm_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String error = '';
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> login() async {
    setState(() {
      error = '';
      _isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        error = 'Please enter both email and password';
        _isLoading = false;
      });
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        setState(() {
          error = 'Login failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // ✅ Fetch user document
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          error = "No user profile found.";
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      final role = data['role'] ?? 'student';

      if (!mounted) return;

      // ✅ ADMIN FLOW - No email verification or approval needed
      if (role == 'admin') {
        debugPrint('🔵 Admin login detected, initializing FCM...');
        // Update isProfileVerified to true on first login
        if (data['isProfileVerified'] != true) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'isProfileVerified': true});
        }

        // ✅ Initialize FCM for admins
        debugPrint('🔵 Calling FCMService.initializeFCM()...');
        await FCMService.initializeFCM();
        debugPrint('🔵 FCM initialization completed');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
        return;
      }

      // ✅ STUDENT FLOW - Check email verification first
      if (!user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
        );
        return;
      }

      // ✅ STUDENT FLOW - Check approval status
      final approvalStatus = data['approvalStatus'] ?? 'pending';

      if (approvalStatus == 'pending' || approvalStatus == 'rejected') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
        );
      } else if (approvalStatus == 'approved') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          error = "Unknown approval status. Contact admin.";
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No user found for that email';
          break;
        case 'wrong-password':
          msg = 'Wrong password. Please try again';
          break;
        case 'invalid-email':
          msg = 'Invalid email address';
          break;
        case 'invalid-credential':
          msg = 'Email or password is incorrect';
          break;
        default:
          msg = e.message ?? 'Login failed. Please check your credentials';
      }
      setState(() {
        error = msg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'An unexpected error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> resetPassword() async {
    try {
      if (emailController.text.trim().isEmpty) {
        setState(() {
          error = 'Please enter your email to reset password.';
        });
        return;
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Password reset email sent'),
          backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = 'Failed to send reset email ${e.message}';
      });
    }
  }

  double scaleHeight(double h) => MediaQuery.of(context).size.height * (h / 812);
  double scaleWidth(double w) => MediaQuery.of(context).size.width * (w / 375);
  double scaleFont(double f) => f * MediaQuery.of(context).textScaleFactor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: scaleWidth(24),
            vertical: scaleHeight(60),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/dormease_logo.png',
                height: scaleHeight(160),
              ),
              SizedBox(height: scaleHeight(5)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "DORM",
                      style: GoogleFonts.dangrek(
                        fontSize: scaleFont(36),
                        color: const Color(0xFF1800AD),
                      ),
                    ),
                    TextSpan(
                      text: "EASE",
                      style: GoogleFonts.dangrek(
                        fontSize: scaleFont(36),
                        color: const Color(0xFF38B6FF),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: scaleHeight(6)),
              Text(
                'Your Personalized Dorm Journey',
                style: GoogleFonts.dangrek(
                  fontSize: scaleFont(22),
                  color: const Color(0xFF000000),
                ),
              ),
              SizedBox(height: scaleHeight(32)),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: GoogleFonts.dangrek(
                    color: const Color(0xFF1800AD),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF1800AD),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(scaleHeight(30)),
                    borderSide: const BorderSide(
                      color: Color(0xFF1800AD),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(scaleHeight(30)),
                    borderSide: const BorderSide(
                      color: Color(0xFF1800AD),
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: scaleHeight(16),
                    horizontal: scaleWidth(20),
                  ),
                ),
                style: GoogleFonts.dangrek(
                  color: const Color(0xFF1800AD),
                ),
              ),
              SizedBox(height: scaleHeight(16)),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: GoogleFonts.dangrek(
                    color: const Color(0xFF1800AD),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF1800AD),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF1800AD),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(scaleHeight(30)),
                    borderSide: const BorderSide(
                      color: Color(0xFF1800AD),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(scaleHeight(30)),
                    borderSide: const BorderSide(
                      color: Color(0xFF1800AD),
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: scaleHeight(16),
                    horizontal: scaleWidth(20),
                  ),
                ),
                style: GoogleFonts.dangrek(
                  color: const Color(0xFF1800AD),
                ),
              ),
              SizedBox(height: scaleHeight(12)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: resetPassword,
                  child: Text(
                    'Forgot your password?',
                    style: GoogleFonts.dangrek(
                      fontSize: scaleFont(18),
                      color: const Color(0xFF38B6FF),
                    ),
                  ),
                ),
              ),
              SizedBox(height: scaleHeight(16)),
              ElevatedButton(
                onPressed: _isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1800AD),
                  padding: EdgeInsets.symmetric(
                    horizontal: scaleWidth(45),
                    vertical: scaleHeight(8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(scaleHeight(30)),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Login',
                  style: GoogleFonts.dangrek(
                    fontSize: scaleFont(18),
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: scaleHeight(14)),
              if (error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: scaleWidth(16)),
                  child: Text(
                    error,
                    style: GoogleFonts.dangrek(
                      color: Colors.red,
                      fontSize: scaleFont(16),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: scaleHeight(20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account yet? ",
                    style: GoogleFonts.dangrek(
                      color: const Color(0xFF000000),
                      fontSize: scaleFont(18),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Register',
                      style: GoogleFonts.dangrek(
                        fontSize: scaleFont(18),
                        color: const Color(0xFF38B6FF),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}