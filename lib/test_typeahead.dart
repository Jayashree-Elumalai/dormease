/* WITH ERROR ADMIN VERIFY
✅REGISTER PAGE:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../verify_email_pg.dart';
import '../login_pg.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _error = '';

  bool _nameError = false;
  bool _emailError = false;
  bool _emailTakenError = false;
  bool _studentIdError = false;
  bool _studentIdTakenError = false;
  bool _passwordError = false;
  bool _confirmError = false;
  bool _emergencyError = false;
  bool _blockError = false;
  bool _roomError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _studentIdCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emergencyCtrl.dispose();
    _blockCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      _nameError = _nameCtrl.text
          .trim()
          .isEmpty ||
          !RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(_nameCtrl.text.trim());
      _emailError =
          !_emailCtrl.text.contains('@') || !_emailCtrl.text.contains('.');
      _studentIdError = _studentIdCtrl.text
          .trim()
          .isEmpty;
      _passwordError = _passwordCtrl.text.length < 8;
      _confirmError = _confirmCtrl.text != _passwordCtrl.text;
      _emergencyError =
      !RegExp(r'^\d{8,15}$').hasMatch(_emergencyCtrl.text.trim());
      _roomError = _roomCtrl.text
          .trim()
          .isEmpty;
      _blockError = _blockCtrl.text
          .trim()
          .isEmpty ||
          !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(_blockCtrl.text.trim());
    });
  }

  Future<void> _register() async {
    _validateFields();

    setState(() {
      _emailTakenError = false;
      _studentIdTakenError = false;
    });

    if (_nameError ||
        _emailError ||
        _studentIdError ||
        _passwordError ||
        _confirmError ||
        _emergencyError ||
        _blockError ||
        _roomError) return;

    setState(() {
      _error = '';
      _loading = true;
    });

    try {
      // 🔹 Check if studentId is already taken
      final existing = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: _studentIdCtrl.text.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _studentIdTakenError = true;
          _loading = false;
        });
        return; // stop registration
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw FirebaseAuthException(
          code: 'no-uid', message: 'Failed to get uid');

      final block = _blockCtrl.text.trim().toUpperCase(); // normalize

      final userDoc = {
        'uid': uid,
        'role': 'student',
        'name': _nameCtrl.text.trim(),
        'nameLower': _nameCtrl.text.trim().toLowerCase(),
        'email': _emailCtrl.text.trim(),
        'studentId': _studentIdCtrl.text.trim(),
        'block': block,
        'room': _roomCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isProfileVerified': false,// student verify themselves
        'approvalStatus': 'pending', //admin approve
        'rejectReason': null,//rejection reason
        'status': 'active',
      };

      await _firestore.collection('users').doc(uid).set(userDoc);
      await cred.user!.sendEmailVerification();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: cred.user!)),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          _emailTakenError = true;
        });
      } else if (e.code == 'weak-password') {
        setState(() {
          _error = 'Password too weak (min 8 characters).';
        });
      } else {
        setState(() {
          _error = e.message ?? 'Registration failed.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString(); // unexpected errors
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

    Widget _buildTextField({
      required TextEditingController controller,
      required String hint,
      Widget? prefixIcon,
      Widget? suffixIcon,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters,
      bool obscure = false,
    }) {
      return TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dangrek(color: const Color(0xFF1800AD)),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 20),
        ),
        style: GoogleFonts.dangrek(color: const Color(0xFF1800AD)),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/dormease_logo.png', height: 140),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: 'DORM',
                        style: GoogleFonts.dangrek(
                            fontSize: 36, color: const Color(0xFF1800AD))),
                    TextSpan(text: 'EASE',
                        style: GoogleFonts.dangrek(
                            fontSize: 36, color: const Color(0xFF38B6FF))),
                  ]),
                ),
                const SizedBox(height: 2),
                Text('Create an Account', style: GoogleFonts.dangrek(
                    fontSize: 22, color: const Color(0xFF000000))),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _nameCtrl,
                  hint: 'Full name',
                  prefixIcon: const Icon(
                      Icons.person, color: Color(0xFF1800AD)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                  ],
                ),
                if (_nameError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Enter a valid name',
                      style: GoogleFonts.dangrek(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),

                _buildTextField(
                    controller: _emailCtrl,
                    hint: 'Email (Use your college email)',
                    prefixIcon: const Icon(
                        Icons.email_outlined, color: Color(0xFF1800AD)),
                    keyboardType: TextInputType.emailAddress),
                if (_emailError || _emailTakenError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _emailTakenError
                          ? 'This email is already registered.'
                          : 'Enter a valid email',
                      style: GoogleFonts.dangrek(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),

                _buildTextField(controller: _studentIdCtrl,
                    hint: 'Student ID',
                    prefixIcon: const Icon(
                        Icons.badge_outlined, color: Color(0xFF1800AD))),
                if (_studentIdError || _studentIdTakenError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _studentIdTakenError
                          ? 'This Student ID is already registered.'
                          : 'Enter a valid student ID',
                      style: GoogleFonts.dangrek(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  prefixIcon: const Icon(
                      Icons.lock_outline, color: Color(0xFF1800AD)),
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons
                        .visibility, color: const Color(0xFF1800AD)),
                  ),
                ),
                if (_passwordError) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Password must be at least 8 characters',
                        style: GoogleFonts.dangrek(color: Colors.red))),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _confirmCtrl,
                  hint: 'Confirm password',
                  prefixIcon: const Icon(
                      Icons.lock_outline, color: Color(0xFF1800AD)),
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons
                        .visibility, color: const Color(0xFF1800AD)),
                  ),
                ),
                if (_confirmError) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Passwords do not match',
                        style: GoogleFonts.dangrek(color: Colors.red))),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _emergencyCtrl,
                  hint: 'Emergency contact',
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF1800AD)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (_emergencyError) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Enter a valid phone number',
                        style: GoogleFonts.dangrek(color: Colors.red))),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _blockCtrl,
                  hint: 'Block',
                  prefixIcon: const Icon(
                      Icons.home_outlined, color: Color(0xFF1800AD)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                ),
                if (_blockError) Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('Enter your block',
                      style: GoogleFonts.dangrek(color: Colors.red)),),
                const SizedBox(height: 12),

                _buildTextField(controller: _roomCtrl,
                    hint: 'Room',
                    prefixIcon: const Icon(
                        Icons.meeting_room_outlined, color: Color(0xFF1800AD))),
                if (_roomError) Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('Enter your room number',
                        style: GoogleFonts.dangrek(color: Colors.red))),
                const SizedBox(height: 18),

                // 🔹 Register Button (smaller width, adjusted padding so text isn't cut)
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1800AD),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8), // reduce vertical padding
                    ),
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      'Register',
                      style: GoogleFonts.dangrek(
                          color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),


                if (_error.isNotEmpty) Text(_error, style: GoogleFonts.dangrek(
                    color: Colors.red, fontSize: 16)),
                const SizedBox(height: 16),

                // 🔹 Already have an account? Login (bigger, same size)
                SizedBox(
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ",
                          style: GoogleFonts.dangrek(color: const Color(
                              0xFF000000), fontSize: 18)),
                      SizedBox(
                        height: 50,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushReplacement(context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen())),
                          child: Text('Login', style: GoogleFonts.dangrek(
                              color: const Color(0xFF38B6FF), fontSize: 18)),
                        ),
                      )
                    ],
                  ),
                ),


              ],
            ),
          ),
        ),
      );
    }
  }
 */

/*
✅LOGIN PG:
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'student/home_pg.dart';
import 'admin/admin_home_pg.dart';
import 'student/register_pg.dart';
import 'verify_email_pg.dart';

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

  // 🔹 Login function
  Future<void> login() async {
    setState(() => error = '');

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => error = 'Please enter both email and password');
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        setState(() => error = 'User not found.');
        return;
      }

      // ✅ STEP 1: Check email verification
      if (!user.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
        );
        return;
      }

      // ✅ STEP 2: Fetch Firestore user document
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!docSnapshot.exists) {
        setState(() => error = "User profile not found in Firestore.");
        return;
      }

      final data = docSnapshot.data()!;
      final role = data['role'] ?? 'student';
      final approvalStatus = data['approvalStatus'] ?? 'pending';

      if (role == 'student') {
        if (approvalStatus == 'pending') {
          await FirebaseAuth.instance.signOut();
          setState(() => error = "Your account is pending admin approval.");
          return;
        } else if (approvalStatus == 'rejected') {
          await FirebaseAuth.instance.signOut();
          setState(() => error = "Your registration has been rejected. Please contact the dorm admin.");
          return;
        }
      }


      // ✅ STEP 4: Route based on role
      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
      setState(() => error = msg);
    } catch (e) {
      setState(() => error = 'An unexpected error occurred. Please try again.');
    }
  }


  // 🔹 Reset password
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = 'Failed to send reset email. ${e.message}';
      });
    }
  }

  // 🔹 Responsive helpers
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
              // LOGO & TITLE
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

              // EMAIL
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

              // PASSWORD
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

              // LOGIN BUTTON
              ElevatedButton(
                onPressed: login,
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
                child: Text(
                  'Login',
                  style: GoogleFonts.dangrek(
                    fontSize: scaleFont(18),
                    color: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: scaleHeight(14)),
              if (error.isNotEmpty)
                Text(
                  error,
                  style: GoogleFonts.dangrek(
                    color: Colors.red,
                    fontSize: scaleFont(16), // bigger error font
                  ),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: scaleHeight(20)),

              // REGISTER LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don’t have an account yet? ",
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
 */

/*
✅VERIFY EMAIL PG:

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'student/home_pg.dart';
import 'admin/admin_home_pg.dart';
import 'student/register_pg.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user; // ✅ pass the actual User object
  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;
  String _status = '';
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  // 🔹 Resend verification email
  Future<void> _resend() async {
    if (_resendCooldown > 0) return;

    try {
      setState(() {
        _sending = true;
        _status = '';
      });

      await widget.user.sendEmailVerification();

      setState(() {
        _status = 'Verification email resent. Please check your inbox';
        _resendCooldown = 60;
      });

      _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown <= 0) {
          timer.cancel();
        } else {
          setState(() => _resendCooldown--);
        }
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        setState(() => _status = 'Too many requests. Please wait a while before trying again');
      } else {
        setState(() => _status = 'Failed to resend: ${e.message}');
      }
    } finally {
      if (mounted && _resendCooldown == 0) setState(() => _sending = false);
    }
  }

  // 🔹 Check verification status
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = '';
    });

    try {
      await widget.user.reload();
      final fresh = FirebaseAuth.instance.currentUser;

      if (fresh != null && fresh.emailVerified) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(fresh.uid);
        final snap = await userDoc.get();

        if (!snap.exists) {
          setState(() => _status = 'User record not found in database.');
          return;
        }

        final data = snap.data()!;
        final role = data['role'] ?? 'student';
        final approvalStatus = data['approvalStatus'] ?? 'pending';

        if (approvalStatus == 'approved') {
          await userDoc.update({'isProfileVerified': true});

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => role == 'admin'
                  ? const AdminHomeScreen()
                  : const HomeScreen(),
            ),
                (r) => false,
          );
        } else if (approvalStatus == 'pending') {
          setState(() => _status =
          'Email verified, but waiting for admin approval. You will be able to log in once verified.');
        } else if (approvalStatus == 'rejected') {
          final reason = data['rejectReason'] ?? 'No reason provided.';
          setState(() => _status =
          'Your registration has been rejected.  Reason: $reason\nPlease contact the dorm admin.');
        } else {
          setState(() => _status = 'Unknown status. Please contact support.');
        }
      } else {
        setState(() => _status = 'Email not verified yet. Please check your inbox.');
      }
    } catch (e) {
      setState(() => _status = 'Error checking verification: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text("A verification email was sent to:",
                style: GoogleFonts.dangrek(fontSize: 20)),
            Text(widget.user.email ?? '',
                style: GoogleFonts.dangrek(fontSize: 20, color: Colors.blue)),
            const SizedBox(height: 20),
            Text(
              "Please open the email and click the verification link. After verifying, tap 'I've verified'.",
              style: GoogleFonts.dangrek(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 🔹 Resend Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              onPressed: (_sending || _resendCooldown > 0) ? null : _resend,
              child: _sending
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : Text(
                _resendCooldown > 0
                    ? 'Resend ($_resendCooldown s)'
                    : 'Resend verification email',
                style: GoogleFonts.dangrek(fontSize: 20),
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Check Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              onPressed: _checking ? null : _check,
              child: _checking
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : Text("I've verified",
                  style: GoogleFonts.dangrek(fontSize: 20)),
            ),
            const SizedBox(height: 24),

            Text(
              "Please verify your email to continue using the app",
              style: GoogleFonts.dangrek(color: Colors.red, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            if (_status.isNotEmpty)
              Text(
                _status,
                style: GoogleFonts.dangrek(
                  color: _status.contains('Failed') ||
                      _status.contains('not verified')
                      ? Colors.red
                      : Colors.green,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

 */

/*
✅ADMIN VERIFY PG:

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminVerificationPage extends StatelessWidget {
  const AdminVerificationPage({super.key});

  Stream<QuerySnapshot> getPendingUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('approvalStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _updateStatus(BuildContext context, String uid, String newStatus, String name) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'approvalStatus': newStatus});

    // ✅ Optional improvement #3: Show snackbar after updating
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("User $name has been $newStatus."),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 🔹 3. Confirmation dialog (optional improvement #1)
  Future<bool> _confirmAction(BuildContext context, String action, String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm $action"),
        content: Text("Are you sure you want to $action $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action,
              style: TextStyle(
                color: action == "Reject" ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Verification")),
      body: StreamBuilder<QuerySnapshot>(
        stream: getPendingUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No pending verifications",
                style: GoogleFonts.dangrek(fontSize: 18),
              ),
            );
          }

          final students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final user = students[index];
              final name = user['name'] ?? 'Unnamed';
              final email = user['email'] ?? '';
              final block = user['block'] ?? 'N/A';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(name, style: GoogleFonts.dangrek(fontSize: 20)),
                  subtitle: Text("Email: $email\nBlock: $block"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: "Approve",
                        onPressed: () async {
                          final confirm = await _confirmAction(context, "Approve", name);
                          if (confirm) {
                            await _updateStatus(context, user.id, 'approved', name);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: "Reject",
                        onPressed: () async {
                          final confirm = await _confirmAction(context, "Reject", name);
                          if (confirm) {
                            await _updateStatus(context, user.id, 'rejected', name);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

 */

/*
✅ADMIN HOME:
import 'package:dormease_app/screens/admin/admin_annnouncements_pg.dart';
import 'package:dormease_app/screens/admin/admin_lostnfound_pg.dart';
import 'package:dormease_app/screens/admin/admin_parcel_pg.dart';
import 'package:dormease_app/screens/admin/admin_report_pg.dart';
import 'package:dormease_app/screens/admin/admin_sos_pg.dart';
import 'package:dormease_app/screens/admin/admin_verification_pg.dart';
import 'package:dormease_app/widgets/student_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_pg.dart';


class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<String> getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User";

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    return doc.data()?['name'] ?? "User";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Top row with username + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<String>(
                    future: getUserName(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          "Hi...",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return Text(
                        "Hi, ${snapshot.data}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()), // ✅ correct
                            (route) => false,
                      );
                    },
                    child: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),


              // 🔹 Grid (Report Issue, Parcel, Lost & Found, Connect)
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: [
                    _buildFeatureItem(
                      context,
                      "assets/images/report_issue.png",
                      "REPORTS",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminReportPg ()),
                        );
                      },
                    ),
                    _buildFeatureItem(
                      context,
                      "assets/images/parcel.png",
                      "PARCEL",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminParcelPg ()),
                        );
                      },
                    ),
                    _buildFeatureItem(
                      context,
                      "assets/images/lost_found.png",
                      "LOST & FOUND",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminLostnfoundPg()),
                        );
                      },
                    ),
                    _buildFeatureItem(
                      context,
                      "assets/images/announcement.png",
                      "ANNOUNCEMENT",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminAnnouncementsPg()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Verify Students button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // you can choose any color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminVerificationPage()),
                    );
                  },
                  child: const Text(
                    "VERIFY STUDENTS",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 SOS button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSosPg()),
                    );
                  },
                  child: const Text(
                    "SOS ALERTS",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Feature card with navy border + bigger text
  Widget _buildFeatureItem(
      BuildContext context, String imagePath, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1800AD).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20, // bigger text
                color: Color(0xFF1800AD),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 */


/* ADMIN VERIFY FUNC WORKING BUT ISSUE WITH REREGISTER AFTER REJECTED
ADMIN VERIFY PG:
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminVerifyStudentsPg extends StatefulWidget {
  const AdminVerifyStudentsPg({super.key});

  @override
  State<AdminVerifyStudentsPg> createState() => _AdminVerifyStudentsPgState();
}

class _AdminVerifyStudentsPgState extends State<AdminVerifyStudentsPg> {
  String _selectedFilter = 'pending'; // all, pending, approved, rejected
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Verify Students',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ✅ Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, email or ID',
                hintStyle: GoogleFonts.dangrek(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF1800AD)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              style: GoogleFonts.dangrek(color: const Color(0xFF1800AD)),
            ),
          ),
          // ✅ Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Approved', 'approved'),
                  const SizedBox(width: 6),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),
          // ✅ Student list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStudentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.dangrek(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No students found',
                          style: GoogleFonts.dangrek(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter by search query
                final students = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['nameLower'] ?? '').toString();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final studentId = (data['studentId'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      studentId.contains(_searchQuery);
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: GoogleFonts.dangrek(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final doc = students[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildStudentCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    // determine selected color based on label
    Color selectedColor;
    switch (label.toLowerCase()) {
      case 'pending':
        selectedColor = Colors.orange;
        break;
      case 'approved':
        selectedColor = Colors.green;
        break;
      case 'rejected':
        selectedColor = Colors.red;
        break;
      default:
        selectedColor = const Color(0xFF1800AD); // blue for "All"
    }


    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.dangrek(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      selectedColor: selectedColor,
      backgroundColor: Colors.grey,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 👈 more circular
      ),
    );
  }

  Stream<QuerySnapshot> _getStudentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student');

    // Filter by approval status
    if (_selectedFilter != 'all') {
      query = query.where('approvalStatus', isEqualTo: _selectedFilter);
    }

    // Sort by creation date (newest first)
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  Widget _buildStudentCard(String uid, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final studentId = data['studentId'] ?? 'No ID';
    final block = data['block'] ?? 'N/A';
    final room = data['room'] ?? 'N/A';
    final emergencyContact = data['emergencyContact'] ?? 'N/A';
    final status = data['approvalStatus'] ?? 'pending';
    final rejectionReason = data['rejectionReason'];
    final createdAt = data['createdAt'] as Timestamp?;
    final approvedAt = data['approvedAt'] as Timestamp?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.firaSans(//name
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1800AD),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.dangrek(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.badge, 'Student ID', studentId),
            _buildInfoRow(Icons.email, 'Email', email),
            _buildInfoRow(Icons.home, 'Block', block),
            _buildInfoRow(Icons.meeting_room, 'Room', room),
            _buildInfoRow(Icons.phone, 'Emergency', emergencyContact),
            if (createdAt != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Registered',
                DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate()),
              ),
            if (approvedAt != null)
              _buildInfoRow(
                Icons.check,
                'Approved',
                DateFormat('MMM dd, yyyy HH:mm').format(approvedAt.toDate()),
              ),

            if (status == 'rejected' && rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: $rejectionReason',
                        style: GoogleFonts.dangrek(
                          fontSize: 14,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ✅ Action buttons
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveStudent(uid, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: Text(
                        'Approve',
                        style: GoogleFonts.dangrek(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectStudent(uid, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.dangrek(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1800AD)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.firaSans(//info variable font(card)
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.firaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveStudent(String uid, String name) async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 🔹 Add spacing around title and content for better balance

        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),

        // 🔹 Centered, green title text
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                "Approve Student",
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        content: Text(
          'Are you sure you want to approve $name?',
          style: GoogleFonts.firaSans(
              color: const Color(0xFF1800AD),
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.firaSans(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Approve",
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminUid,
        'rejectionReason': null, // Clear any previous rejection reason
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been approved!', style: GoogleFonts.dangrek()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: GoogleFonts.dangrek()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectStudent(String uid, String name) async {
    final reasonController = TextEditingController();

    // Show dialog to enter rejection reason
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 🔹 Add consistent padding like your Delete dialog
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),

        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                "Reject Student",
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject $name?',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection',
                hintStyle: GoogleFonts.firaSans(fontWeight: FontWeight.bold,color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                ),

              ),
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold,fontSize: 14,),
            ),
          ],
        ),

          actionsPadding: const EdgeInsets.symmetric(horizontal: 12),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a reason for rejection',
                      style: GoogleFonts.firaSans(color: Colors.white,fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text('Reject',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'approvalStatus': 'rejected',
        'rejectionReason': reasonController.text.trim(),
        'approvedAt': null,
        'approvedBy': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been rejected', style: GoogleFonts.dangrek()),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: GoogleFonts.dangrek()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
 */

/* WAITING APPROVAL
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_pg.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  bool _checking = false;

  Future<Map<String, dynamic>?> _getApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);

    try {
      final data = await _getApprovalStatus();
      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to fetch status')),
        );
        setState(() => _checking = false);
        return;
      }

      final status = data['approvalStatus'] ?? 'pending';

      if (status == 'approved') {
        // ✅ Approved - should not be on this screen, but handle it
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been approved!')),
        );
        // They can now login normally
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      } else {
        // Still pending or rejected - just refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Account Approval',
          style: GoogleFonts.dangrek(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getApprovalStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Unable to load account status',
                    style: GoogleFonts.dangrek(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _logout,
                    child: Text('Back to Login',
                        style: GoogleFonts.dangrek(fontSize: 18)),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final status = data['approvalStatus'] ?? 'pending';
          final rejectionReason = data['rejectionReason'];

          if (status == 'pending') {
            return _buildPendingUI();
          } else if (status == 'rejected') {
            return _buildRejectedUI(rejectionReason);
          } else {
            // Should not happen, but handle approved case
            return _buildApprovedUI();
          }
        },
      ),
    );
  }

  Widget _buildPendingUI() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_empty,
            size: 100,
            color: Color(0xFF1800AD),
          ),
          const SizedBox(height: 30),
          Text(
            'Waiting for Admin Approval',
            style: GoogleFonts.dangrek(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1800AD),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Your account has been successfully created and email verified!',
            style: GoogleFonts.dangrek(fontSize: 18, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while an administrator reviews and approves your account.',
            style: GoogleFonts.dangrek(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _checking ? null : _checkStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1800AD),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: _checking
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.refresh, color: Colors.white),
            label: Text(
              _checking ? 'Checking...' : 'Check Status',
              style: GoogleFonts.dangrek(fontSize: 18, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _logout,
            child: Text(
              'Logout',
              style: GoogleFonts.dangrek(
                fontSize: 20,
                color: const Color(0xFF38B6FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedUI(String? reason) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cancel,
            size: 100,
            color: Colors.red,
          ),
          const SizedBox(height: 30),
          Text(
            'Account Rejected',
            style: GoogleFonts.dangrek(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Unfortunately, your account registration was not approved by the administrator.',
            style: GoogleFonts.dangrek(fontSize: 16, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason:',
                    style: GoogleFonts.dangrek(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: GoogleFonts.dangrek(
                      fontSize: 16,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          Text(
            'You can register again with correct information.',
            style: GoogleFonts.dangrek(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1800AD),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Back to Login',
              style: GoogleFonts.dangrek(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedUI() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 30),
          Text(
            'Account Approved!',
            style: GoogleFonts.dangrek(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Your account has been approved. You can now login and access all features.',
            style: GoogleFonts.dangrek(fontSize: 18, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1800AD),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Go to Login',
              style: GoogleFonts.dangrek(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
 */

/*OLD STUDENT PARCEL PAGE (NO FUNCTION ONYL TITLE AND NAVBAR)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'connect_pg.dart';
import 'lost_found_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';

class ParcelPage extends StatefulWidget {
  const ParcelPage({super.key});

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> {
  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = const ReportIssuePage();
        break;
      case 1:
        targetPage = const ParcelPage();
        break;
      case 2:
        targetPage = const HomeScreen();
        break;
      case 3:
        targetPage = const ConnectPage();
        break;
      case 4:
      default:
        targetPage = const SosPage();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: const Text(
          'Parcel',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
      ),

      // keep student nav bar
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.report, 'Report', 0),
            _buildNavItem(Icons.inventory, 'Parcel', 1),
            _buildNavItem(Icons.home, 'Home', 2),
            _buildNavItem(Icons.chat, 'Connect', 3),
            _buildNavItem(Icons.warning, 'SOS', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,
      {bool forceGrey = false}) {
    bool isSelected = _selectedIndex == index;
    Color color =
    (isSelected && !forceGrey) ? const Color(0xFF1800AD) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
 */


/* OLD ADMIN PARCEL PG (SEARCH NOT WORKING. ONLY ADMIN CLAIMS)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// flutter_typeahead v5
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:dormease_app/screens/login_pg.dart';
import 'package:dormease_app/screens/admin/admin_annnouncements_pg.dart';
import 'package:dormease_app/screens/admin/admin_lostnfound_pg.dart';
import 'package:dormease_app/screens/admin/admin_report_pg.dart';
import 'package:dormease_app/screens/admin/admin_sos_pg.dart';

class AdminParcelPg extends StatefulWidget {
  const AdminParcelPg({super.key});

  @override
  State<AdminParcelPg> createState() => _AdminParcelPgState();
}

class _AdminParcelPgState extends State<AdminParcelPg> {
  int _selectedIndex = 1;
  String? selectedStudent;
  String? selectedStudentId; // Firestore doc.id
  String? selectedStudentName; // display name

  // Controller provided by TypeAheadField (assigned inside builder)
  TextEditingController? _studentFieldController;

  // Simple one-time cache of students to avoid repeated full-collection reads.
  List<Map<String, dynamic>> _studentsCache = [];
  bool _studentsLoaded = false;

  bool showClaimed = false;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = const AdminReportPg();
        break;
      case 1:
        targetPage = const AdminParcelPg();
        break;
      case 2:
        targetPage = const AdminSosPg();
        break;
      case 3:
        targetPage = const AdminLostnfoundPg();
        break;
      case 4:
      default:
        targetPage = const AdminAnnouncementsPg();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  Future<void> _ensureStudentsLoaded() async {
    if (_studentsLoaded) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      _studentsCache = snap.docs
          .map((d) => {
        'id': d.id,
        'name': (d.data() as Map<String, dynamic>)['name'] ?? ''
      })
          .toList();
      _studentsLoaded = true;
    } catch (e) {
      // ignore errors here; suggestionsCallback will handle empty list
      _studentsCache = [];
      _studentsLoaded = true;
    }
  }

  Future<void> _sendParcelNotification() async {
    if (selectedStudentId == null || selectedStudentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a student"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('parcels').add({
        'studentId': selectedStudentId,
        'studentName': selectedStudentName,
        'sentAt': FieldValue.serverTimestamp(),
        'claimed': false,
        'claimedAt': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Parcel notification sent!"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedStudent = null;
        selectedStudentId = null;
        selectedStudentName = null;
        // clear the text field shown to admin
        _studentFieldController?.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsClaimed(String parcelId) async {
    await FirebaseFirestore.instance.collection('parcels').doc(parcelId).update({
      'claimed': true,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return "N/A";
    return DateFormat('dd MMM, h:mm a').format(ts.toDate());
  }

  @override
  void dispose() {
    // NOTE: _studentFieldController is created/owned by TypeAheadField,
    // so do NOT dispose it here. If you create your own controller, dispose it.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: const Text(
          'Parcel',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Searchable student field (TypeAheadField v5) =====
            TypeAheadField<Map<String, dynamic>>(
              suggestionsCallback: (pattern) async {
                final q = pattern.toLowerCase().trim();
                if (q.isEmpty) return <Map<String, dynamic>>[];

                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'student')
                    .where('nameLower', isGreaterThanOrEqualTo: q) // 👈 index field
                    .where('nameLower', isLessThanOrEqualTo: '$q\uf8ff')
                    .limit(20)
                    .get();

                return snap.docs.map((d) {
                  final data = d.data();
                  return {
                    'id': d.id,
                    'name': data['name'] ?? '',
                  };
                }).toList();
              },

              builder: (context, controller, focusNode) {
                _studentFieldController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "Search and select student",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                );
              },

              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['name'] as String),
                  subtitle: Text(suggestion['id'] as String,
                      style: const TextStyle(fontSize: 12)),
                );
              },

              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("No students found"),
              ),

              onSelected: (suggestion) {
                setState(() {
                  selectedStudentId = suggestion['id'] as String;
                  selectedStudentName = suggestion['name'] as String;
                  _studentFieldController?.text = selectedStudentName ?? '';
                });
              },

              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),

              decorationBuilder: (context, child) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
            ),


            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1800AD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _sendParcelNotification,
              child: const Text(
                "Send Notification",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // toggle row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      !showClaimed ? const Color(0xFF1800AD) : Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () {
                      setState(() => showClaimed = false);
                    },
                    child: const Text("Unclaimed"),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      showClaimed ? const Color(0xFF1800AD) : Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () {
                      setState(() => showClaimed = true);
                    },
                    child: const Text("Claimed"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // parcel list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                key: ValueKey(showClaimed),
                stream: FirebaseFirestore.instance
                    .collection('parcels')
                    .where('claimed', isEqualTo: showClaimed)
                    .orderBy(showClaimed ? 'claimedAt' : 'sentAt',
                    descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final parcels = snapshot.data!.docs;

                  if (parcels.isEmpty) {
                    return Center(
                      child: Text(
                        showClaimed ? "No claimed parcels" : "No unclaimed parcels",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: parcels.length,
                    itemBuilder: (context, index) {
                      final doc = parcels[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final studentName = data['studentName'] ?? 'Unknown';
                      final timestamp =
                      (data[showClaimed ? 'claimedAt' : 'sentAt'] as Timestamp?)
                          ?.toDate();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            studentName,
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            timestamp != null
                                ? "${timestamp.day}/${timestamp.month}/${timestamp.year}, ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}"
                                : 'N/A',
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          trailing: !showClaimed
                              ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _markAsClaimed(doc.id),
                            child: const Text("Claimed",
                                style: TextStyle(color: Colors.white)),
                          )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF1800AD),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Parcel'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Lost/Found'),
          BottomNavigationBarItem(icon: Icon(Icons.announcement), label: 'Announce'),
        ],
      ),
    );
  }
}
 */

/* CONNECT PG (NO IMAGES). dont have leave group function yet
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final int _selectedIndex = 3;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = const ReportIssuePage();
        break;
      case 1:
        targetPage = const ParcelPage();
        break;
      case 2:
        targetPage = const HomeScreen();
        break;
      case 3:
        targetPage = const ConnectPage();
        break;
      case 4:
      default:
        targetPage = const SosPage();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  // Get unread message count for badge
  Stream<int> _getUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastMessageBy = data['lastMessageBy'] as String?;

        // ✅ NEW: Check if blocked
        final status = Map<String, dynamic>.from(data['status'] ?? {});
        final myStatus = status[currentUser.uid];
        if (myStatus == 'blocked') continue; // Skip blocked conversations

        // Don't count if I sent the last message
        if (lastMessageBy == currentUser.uid) continue;

        // Count unread messages in this conversation
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .where('sentBy', isNotEqualTo: currentUser.uid)
            .get();

        for (var msgDoc in messagesSnapshot.docs) {
          final msgData = msgDoc.data();
          final readBy = List<String>.from(msgData['readBy'] ?? []);
          if (!readBy.contains(currentUser.uid)) {
            totalUnread++;
          }
        }
      }
      return totalUnread;
    });
  }

  //CONNECT PG UI
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: Text(
          'Connect',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // New chat button
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Colors.white),
            onSelected: (value) {
              if (value == 'direct') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatPage(isGroup: false)),
                );
              } else if (value == 'group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatPage(isGroup: true)),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'direct',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF1800AD)),
                    const SizedBox(width: 12),
                    Text('New Chat', style: GoogleFonts.firaSans(fontSize: 15)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Color(0xFF1800AD)),
                    const SizedBox(width: 12),
                    Text('New Group', style: GoogleFonts.firaSans(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Please login'))
          : Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: GoogleFonts.firaSans(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Conversations list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final conversations = snapshot.data!.docs;
                final searchQuery = _searchController.text.trim().toLowerCase();

                // Filter by search ONLY if there's a search query
                final filtered = searchQuery.isEmpty
                    ? conversations
                    : conversations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'direct';

                  if (type == 'group') {
                    final groupName = (data['groupName'] ?? '').toLowerCase();
                    return groupName.contains(searchQuery);
                  } else {
                    // Search in participant names
                    final participants = data['participantDetails'] as Map<String, dynamic>?;
                    if (participants == null) return false;

                    for (var uid in participants.keys) {
                      if (uid == currentUser.uid) continue;
                      final name = (participants[uid]['name'] ?? '').toLowerCase();
                      if (name.contains(searchQuery)) return true;
                    }
                    return false;
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          searchQuery.isEmpty ? 'No conversations found' : 'No results for "$searchQuery"',
                          style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildConversationTile(doc.id, data, currentUser.uid);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _getUnreadCount(),
        builder: (context, snapshot) {
          final badgeCount = snapshot.data ?? 0;
          return Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.report, 'Report', 0),
                _buildNavItem(Icons.inventory, 'Parcel', 1),
                _buildNavItem(Icons.home, 'Home', 2),
                _buildNavItem(Icons.chat, 'Connect', 3, badgeCount: badgeCount),
                _buildNavItem(Icons.warning, 'SOS', 4),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Conversations Yet',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start a new chat',
            style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(String conversationId, Map<String, dynamic> data, String currentUid) {
    final type = data['type'] ?? 'direct';
    final participants = data['participantDetails'] as Map<String, dynamic>?;
    final lastMessage = data['lastMessage'] ?? '';
    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
    final lastMessageBy = data['lastMessageBy'] as String?;

    String displayName = '';
    String displayInitials = '';
    Color avatarColor = Colors.blue;

    if (type == 'group') {
      displayName = data['groupName'] ?? 'Group Chat';
      displayInitials = displayName.substring(0, 1).toUpperCase();
      avatarColor = Colors.purple;
    } else {
      // Get other participant's details
      if (participants != null) {
        for (var uid in participants.keys) {
          if (uid != currentUid) {
            displayName = participants[uid]['name'] ?? 'Unknown';
            displayInitials = _getInitials(displayName);
            avatarColor = _getColorFromString(uid);
            break;
          }
        }
      }
    }

    return FutureBuilder<int>(
      future: _getUnreadCountForConversation(conversationId, currentUid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avatarColor,
            child: type == 'group'
                ? const Icon(Icons.group, color: Colors.white)
                : Text(
              displayInitials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.firaSans(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1800AD),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Builder( // 🆕 WRAPPED: Use Builder to handle null safety
            builder: (context) {
              // 🆕 ADDED: Get lastMessageType from data, default to 'text' if not set
              final messageType = data['lastMessageType'] as String?;
              final isDeleted = messageType == 'deleted'; // 🆕 ADDED: Check if deleted

              return Row(
                children: [
                  // 🆕 ADDED: Show block icon ONLY if lastMessageType is 'deleted'
                  if (isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.block, // 🎯 Same icon as in chat bubbles
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  Expanded(
                    child: Text(
                      lastMessage,
                      style: GoogleFonts.firaSans(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontStyle: isDeleted // 🆕 ADDED: Italic ONLY if deleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
          onTap: () async { // ✅ CHANGED: Made async
            await Navigator.push( // ✅ CHANGED: Added await
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: conversationId,
                  chatName: displayName,
                  isGroup: type == 'group',
                ),
              ),
            );
            // 🆕 ADDED: Force rebuild to update timestamps
            if (mounted) {
              setState(() {}); // This triggers rebuild and fetches fresh data
            }
          },
        );
      },
    );
  }

  Future<int> _getUnreadCountForConversation(String conversationId, String currentUid) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('sentBy', isNotEqualTo: currentUid)
        .get();

    int unread = 0;
    for (var doc in messagesSnapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(currentUid)) unread++;
    }
    return unread;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(date);
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    bool isSelected = _selectedIndex == index;
    Color color = isSelected ? const Color(0xFF1800AD) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 70,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: 12,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1800AD),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== NEW CHAT PAGE (Search Students) =====
class NewChatPage extends StatefulWidget {
  final bool isGroup;

  const NewChatPage({super.key, this.isGroup = false});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _searchController = TextEditingController();
  final _selectedUsers = <String, Map<String, dynamic>>{};
  late bool _isCreatingGroup;
  final _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isCreatingGroup = widget.isGroup;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  //NEW CHAT/NEW GROUP PG UI
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          _isCreatingGroup ? 'New Group' : 'New Chat',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedUsers.isNotEmpty && !_isCreatingGroup)
            TextButton(
              onPressed: () {
                setState(() => _isCreatingGroup = true);
              },
              child: Text(
                'Group',
                style: GoogleFonts.dangrek(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search dormmates...',
                hintStyle: GoogleFonts.firaSans(color: Colors.grey,fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD), size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                isDense: true,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Group name input (if creating group)
          if (_isCreatingGroup)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.group, color: Color(0xFF1800AD), size: 20),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // ✅ CHANGED: 12→8
                  isDense: true,
                ),
              ),
            ),
          if (_isCreatingGroup)
          // Selected users chips
          if (_selectedUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUsers.entries.map((entry) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _getColorFromString(entry.key),
                      child: Text(
                        _getInitials(entry.value['name']),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    label: Text(entry.value['name']),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedUsers.remove(entry.key);
                        if (_selectedUsers.length < 2 && !widget.isGroup) {
                          _isCreatingGroup = false;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          // Instruction text
          if (_isCreatingGroup && _selectedUsers.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select at least 2 members to create a group',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Students list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .where('approvalStatus', isEqualTo: 'approved')
                  .orderBy('nameLower')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found',
                      style: GoogleFonts.firaSans(fontSize: 16),
                    ),
                  );
                }

                final students = snapshot.data!.docs.where((doc) {
                  // Exclude current user
                  if (doc.id == currentUser?.uid) return false;

                  // Filter by search
                  final searchQuery = _searchController.text.trim().toLowerCase();
                  if (searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['nameLower'] ?? '').toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No students found'
                          : 'No results for "${_searchController.text.trim()}"',
                      style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final doc = students[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final uid = doc.id;
                    final isSelected = _selectedUsers.containsKey(uid);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorFromString(uid),
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.firaSans(fontSize: 16),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF1800AD))
                          : null,
                      onTap: () {
                        if (_isCreatingGroup) {
                          setState(() {
                            if (isSelected) {
                              _selectedUsers.remove(uid);
                            } else {
                              _selectedUsers[uid] = {'name': name, 'nameLower': data['nameLower']};
                            }
                          });
                        } else {
                          if (_selectedUsers.isEmpty) {
                            // Start 1-on-1 chat immediately
                            _startDirectChat(uid, name, data['nameLower']);
                          } else {
                            setState(() {
                              if (isSelected) {
                                _selectedUsers.remove(uid);
                              } else {
                                _selectedUsers[uid] = {'name': name, 'nameLower': data['nameLower']};
                              }
                            });
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 🆕 ADDED: FAB (Floating Action Button) for creating group
      floatingActionButton: _isCreatingGroup && _selectedUsers.length >= 2
          ? FloatingActionButton.extended(
        onPressed: _createGroupChat,
        backgroundColor: Colors.green,
        //icon: const Icon(Icons.check, color: Colors.white),
        label: Text(
          'Create Group',
          style: GoogleFonts.dangrek(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _startDirectChat(String otherUid, String otherName, String otherNameLower) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check if conversation already exists
      final existingConv = await FirebaseFirestore.instance
          .collection('conversations')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? conversationId;

      for (var doc in existingConv.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUid)) {
          conversationId = doc.id;
          break;
        }
      }

      // Get current user details
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';
      final currentUserNameLower = currentUserDoc.data()?['nameLower'] ?? '';

      // Create new conversation if doesn't exist
      if (conversationId == null) {
        final newConv = await FirebaseFirestore.instance.collection('conversations').add({
          'type': 'direct',
          'participants': [currentUser.uid, otherUid],
          'participantDetails': {
            currentUser.uid: {
              'name': currentUserName,
              'nameLower': currentUserNameLower,
            },
            otherUid: {
              'name': otherName,
              'nameLower': otherNameLower,
            },
          },
          // 🆕 ADDED: Blocking system fields
          'status': {
            currentUser.uid: 'accepted',
            otherUid: 'pending',
          },
          'blockedBy': {
            currentUser.uid: null,
            otherUid: null,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageBy': null,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.uid,
        });
        conversationId = newConv.id;
      }

      if (!mounted) return;

      // Navigate to chat screen
      Navigator.push( // ✅ CHANGED: pushReplacement → push
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId!,
            chatName: otherName,
            isGroup: false,
          ),
        ),
      ).then((_) {
        // 🆕 ADDED: After chat closes, go back to Connect page
        if (mounted) {
          Navigator.pop(context); // Go back to Connect page
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _createGroupChat() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedUsers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 members')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user details
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';
      final currentUserNameLower = currentUserDoc.data()?['nameLower'] ?? '';

      final participants = [currentUser.uid, ..._selectedUsers.keys];
      final participantDetails = {
        currentUser.uid: {
          'name': currentUserName,
          'nameLower': currentUserNameLower,
        },
        ..._selectedUsers,
      };

      final newGroup = await FirebaseFirestore.instance.collection('conversations').add({
        'type': 'group',
        'groupName': _groupNameController.text.trim(),
        'participants': participants,
        'participantDetails': participantDetails,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
      });

      if (!mounted) return;

      Navigator.push( // ✅ CHANGED: pushReplacement → push
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: newGroup.id,
            chatName: _groupNameController.text.trim(),
            isGroup: true,
          ),
        ),
      ).then((_) {
        // 🆕 ADDED: After chat closes, go back to Connect page
        if (mounted) {
          Navigator.pop(context); // Go back to Connect page
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }
}

// ===== CHAT SCREEN =====
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String chatName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .where('sentBy', isNotEqualTo: currentUser.uid)
        .get();

    for (var doc in messagesSnapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(currentUser.uid)) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }
    }
  }

  // 🆕 ADDED: Accept chat request
  Future<void> _acceptChatRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'accepted',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chat request accepted',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // 🆕 ADDED: Block user
  Future<void> _blockUser(String otherUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 🆕 ADDED: Better padding
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12),

        // 🔄 CHANGED: Better styled title with icon
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 50, color: Colors.red), // 🆕 ADDED: Block icon
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Block ${widget.chatName}?',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold, // 🆕 ADDED: Bold
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        content: Text(
          "You won't see their messages and they can't send you new messages",
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600, // 🆕 ADDED: Semi-bold
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
                'Cancel',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold, // 🆕 ADDED: Bold
                  color: Colors.grey[700],
                )
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                'Block',
                style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red
                )
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'blocked',
        'blockedBy.${currentUser.uid}': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User blocked',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // 🆕 ADDED: Unblock user
  Future<void> _unblockUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'accepted',
        'blockedBy.${currentUser.uid}': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User unblocked',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';

      final messageText = _messageController.text.trim();
      _messageController.clear();

      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'text': messageText,
        'sentBy': currentUser.uid,
        'sentByName': currentUserName,
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid],
        'editedAt': null,
        'deletedAt': null,
        'deletedBy': null,
      });

      // Update conversation's last message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageBy': currentUser.uid,
        'lastMessageType': 'text',
      });

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get message being deleted
      final msgDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .get();

      final msgData = msgDoc.data();
      final isLastMessage = msgData?['sentAt'] != null;

      // Mark message as deleted
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // ✅ NEW: Update conversation's lastMessage if this was the last message
      if (isLastMessage) {
        // Check if this is actually the most recent message
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get();

        final convData = conversationDoc.data();
        final lastMessageBy = convData?['lastMessageBy'];

        // Only update if this message was from the current user (likely the last one)
        if (lastMessageBy == currentUser.uid) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({
            'lastMessage': 'Message deleted', // ✅ CHANGED: Show deletion indicator
            'lastMessageType': 'deleted', // 🆕 ADDED: Track message type
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  Future<void> _editMessage(String messageId, String currentText) async {
    final controller = TextEditingController(text: currentText);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // 🆕 ADDED: Better padding
        titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        // ✅ IMPROVED: Styled title
        title: Text(
          'Edit Message',
          style: GoogleFonts.firaSans(
            fontSize: 20, // 🆕 ADDED
            fontWeight: FontWeight.bold, // 🆕 ADDED
            color: const Color(0xFF1800AD), // 🆕 ADDED
          ),
          textAlign: TextAlign.center, // 🆕 ADDED
        ),

        // ✅ IMPROVED: Styled text field
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true, // 🆕 ADDED: Auto-focus for convenience
          style: GoogleFonts.firaSans( // 🆕 ADDED: Match chat style
            fontSize: 15,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: GoogleFonts.firaSans( // ✅ CHANGED: Now using firaSans
              color: Colors.grey,
              fontSize: 15,
            ),
            filled: true, // 🆕 ADDED
            fillColor: Colors.grey[100], // 🆕 ADDED
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // ✅ CHANGED: 8→12
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2), // 🆕 ADDED
            ),
            enabledBorder: OutlineInputBorder( // 🆕 ADDED
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
            ),
            focusedBorder: OutlineInputBorder( // 🆕 ADDED
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12), // 🆕 ADDED
          ),
        ),

        // ✅ IMPROVED: Styled buttons
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom( // 🆕 ADDED: Button styling
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontSize: 15, // 🆕 ADDED
                fontWeight: FontWeight.bold, // ✅ CHANGED: Made bold
                color: Colors.grey[700], // ✅ CHANGED: Grey color
              ),
            ),
          ),

          // Save button
          TextButton( // ✅ CHANGED: TextButton → ElevatedButton
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: TextButton.styleFrom( // 🆕 ADDED: Green button
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.firaSans(
                fontSize: 15, // 🆕 ADDED
                fontWeight: FontWeight.bold, // ✅ CHANGED: Made bold
                color: Colors.green, // 🆕 ADDED
              ),
            ),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Update message
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .doc(messageId)
            .update({
          'text': newText,
          'editedAt': FieldValue.serverTimestamp(),
        });

        // ✅ NEW: Update conversation's lastMessage if this was the last message
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get();

        final convData = conversationDoc.data();
        final lastMessageBy = convData?['lastMessageBy'];

        // Only update if this message was from the current user (likely the last one)
        if (lastMessageBy == currentUser.uid) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({
            'lastMessage': newText, // ✅ CHANGED: Update with edited text
            'lastMessageType': 'text', // 🆕 ADDED: Track message type
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing message: $e')),
        );
      }
    }
  }

  void _showMessageOptions(String messageId, String text, Timestamp? sentAt, String sentBy) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || sentBy != currentUser.uid) return;

    final now = DateTime.now();
    final messageTime = sentAt?.toDate() ?? now;
    final diff = now.difference(messageTime);
    final canEdit = diff.inMinutes <= 5;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text('Edit', style: GoogleFonts.firaSans()),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(messageId, text);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: GoogleFonts.firaSans(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text('Cancel', style: GoogleFonts.firaSans()),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chatName,
              style: GoogleFonts.dangrek(color: Colors.white, fontSize: 18),
            ),
            if (widget.isGroup)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final participants = List<String>.from(
                      snapshot.data?.get('participants') ?? []);
                  return Text(
                    '${participants.length} members',
                    style: GoogleFonts.firaSans(color: Colors.white70, fontSize: 12),
                  );
                },
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showGroupInfo,
            )
          // 🆕 ADDED: Block/Unblock menu for direct chats only
          else
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final data = snapshot.data?.data() as Map<String, dynamic>?;

                // 🆕 ADDED: Check if status and participants exist
                if (data == null) return const SizedBox.shrink();

                final status = Map<String, dynamic>.from(data['status'] ?? {});
                final myStatus = status[currentUser?.uid];
                final participants = List<String>.from(data['participants'] ?? []);
                final otherUid = participants.firstWhere(
                        (uid) => uid != currentUser?.uid,
                    orElse: () => ''
                );

                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'block') {
                      _blockUser(otherUid);
                    } else if (value == 'unblock') {
                      _unblockUser();
                    }
                  },
                  itemBuilder: (context) => [
                    if (myStatus != 'blocked')
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('Block User', style: GoogleFonts.firaSans(color: Colors.red)),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'unblock',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 12),
                            Text('Unblock User', style: GoogleFonts.firaSans(color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .snapshots(),
          builder: (context, convSnapshot) {
    if (!convSnapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    final convData = convSnapshot.data?.data() as Map<String, dynamic>?;

    // 🆕 ADDED: Safe null handling
    final status = convData != null
    ? Map<String, dynamic>.from(convData['status'] ?? {})
        : <String, dynamic>{};
    final participants = convData != null
    ? List<String>.from(convData['participants'] ?? [])
        : <String>[];

    final myStatus = status[currentUser?.uid];
    final otherUid = participants.firstWhere(
    (uid) => uid != currentUser?.uid,
    orElse: () => ''
    );
    final otherStatus = status[otherUid];

    // 🆕 ADDED: Check blocking status
    final iBlockedThem = myStatus == 'blocked';
    final theyBlockedMe = otherStatus == 'blocked';
    final isPending = myStatus == 'pending' && !widget.isGroup;

    return Column(
      children: [
        // 🆕 ADDED: Accept/Block banner for pending requests
        if (isPending && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  Text(
                    'Accept chat request from ${widget.chatName}?',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // 🔄 CHANGED: TextButton → Outlined button for better visibility
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _blockUser(otherUid),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Block',
                          style: GoogleFonts.firaSans(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // 🆕 ADDED: Space between buttons
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _acceptChatRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Accept',
                          style: GoogleFonts.firaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // 🆕 ADDED: Blocker banner
        if (iBlockedThem && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You blocked this user. Unblock to continue chatting.',
                    style: GoogleFonts.firaSans(fontSize: 14, color: Colors.red.shade900),
                  ),
                ),
                TextButton(
                  onPressed: _unblockUser,
                  child: Text('Unblock', style: GoogleFonts.firaSans(color: Colors.red)),
                ),
              ],
            ),
          ),
        // 🆕 ADDED: Blocked banner
        if (theyBlockedMe && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This user is unavailable',
                    style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        // Messages list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .orderBy('sentAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send a message to start the conversation',
                        style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final doc = messages[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedAt = data['deletedAt'] as Timestamp?;

                  if (deletedAt != null) {
                    return _buildDeletedMessage(data['sentBy'] == currentUser?.uid);
                  }

                  return _buildMessageBubble(
                    doc.id,
                    data,
                    currentUser?.uid ?? '',
                  );
                },
              );
            },
          ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  // 🆕 ADDED: Disable if blocked
                  enabled: !iBlockedThem && !theyBlockedMe && (myStatus == 'accepted' || widget.isGroup),
                  decoration: InputDecoration(
                    hintText: iBlockedThem || theyBlockedMe
                        ? 'Cannot send messages'
                        : isPending
                        ? 'Accept request to send messages'
                        : 'Type a message...',
                    hintStyle: GoogleFonts.firaSans(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: (iBlockedThem || theyBlockedMe || isPending)
                    ? Colors.grey
                    : const Color(0xFF1800AD),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: (iBlockedThem || theyBlockedMe || isPending)
                      ? null
                      : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
          },
      ),
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data, String currentUid) {
    final text = data['text'] ?? '';
    final sentBy = data['sentBy'] ?? '';
    final sentByName = data['sentByName'] ?? 'Unknown';
    final sentAt = data['sentAt'] as Timestamp?;
    final editedAt = data['editedAt'] as Timestamp?;
    final readBy = List<String>.from(data['readBy'] ?? []);

    final isMe = sentBy == currentUid;
    final allRead = readBy.length > 1; // More than just sender

    return GestureDetector(
      onLongPress: isMe ? () => _showMessageOptions(messageId, text, sentAt, sentBy) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && widget.isGroup)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: _getColorFromString(sentBy),
                  child: Text(
                    _getInitials(sentByName),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1800AD) : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && widget.isGroup)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          sentByName,
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: GoogleFonts.firaSans(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(sentAt),
                          style: GoogleFonts.firaSans(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (editedAt != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: GoogleFonts.firaSans(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            allRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: allRead ? Colors.blue[200] : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedMessage(bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'This message was deleted',
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final participantDetails = data?['participantDetails'] as Map<String, dynamic>? ?? {};

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Group Members (${participantDetails.length})',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...participantDetails.entries.map((entry) {
                  final name = entry.value['name'] ?? 'Unknown';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getColorFromString(entry.key),
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name, style: GoogleFonts.firaSans()),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    return DateFormat('h:mm a').format(date);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }
}

 */