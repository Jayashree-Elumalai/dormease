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
      _nameError = _nameCtrl.text.trim().isEmpty ||
          !RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(_nameCtrl.text.trim());
      _emailError =
          !_emailCtrl.text.contains('@') || !_emailCtrl.text.contains('.');
      _studentIdError = _studentIdCtrl.text.trim().isEmpty ||
          !RegExp(r'^[A-Za-z0-9\-\(\)]{3,20}$').hasMatch(_studentIdCtrl.text.trim());
      _passwordError = _passwordCtrl.text.length < 8;
      _confirmError = _confirmCtrl.text != _passwordCtrl.text;
      _emergencyError =
      !RegExp(r'^\d{8,15}$').hasMatch(_emergencyCtrl.text.trim());
      _roomError = _roomCtrl.text.trim().isEmpty||
          !RegExp(r'^[A-Za-z0-9\-\s]{3,20}$').hasMatch(_roomCtrl.text.trim());
      _blockError = _blockCtrl.text.trim().isEmpty ||
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
        return;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
            code: 'no-uid', message: 'Failed to get uid');
      }

      final block = _blockCtrl.text.trim().toUpperCase();

      // ✅ Add approvalStatus field
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
        'isProfileVerified': false,
        'status': 'active',
        'approvalStatus': 'pending', // ✅ NEW: Default to pending
        'rejectionReason': null, // ✅ NEW: For admin rejection
        'approvedAt': null, // ✅ NEW: Timestamp when approved
        'approvedBy': null, // ✅ NEW: Admin UID who approved
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
        _error = e.toString();
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
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                  TextSpan(
                      text: 'DORM',
                      style: GoogleFonts.dangrek(
                          fontSize: 36, color: const Color(0xFF1800AD))),
                  TextSpan(
                      text: 'EASE',
                      style: GoogleFonts.dangrek(
                          fontSize: 36, color: const Color(0xFF38B6FF))),
                ]),
              ),
              const SizedBox(height: 2),
              Text('Create an Account',
                  style: GoogleFonts.dangrek(
                      fontSize: 22, color: const Color(0xFF000000))),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameCtrl,
                hint: 'Full name',
                prefixIcon:
                const Icon(Icons.person, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                  LengthLimitingTextInputFormatter(50),
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
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Color(0xFF1800AD)),
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
              _buildTextField(
                  controller: _studentIdCtrl,
                  hint: 'Student ID',
                  prefixIcon:
                  const Icon(Icons.badge_outlined, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\(\)]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
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
                prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFF1800AD)),
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF1800AD)),
                ),
              ),
              if (_passwordError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Password must be at least 8 characters',
                        style: GoogleFonts.dangrek(color: Colors.red))),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _confirmCtrl,
                hint: 'Confirm password',
                prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFF1800AD)),
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF1800AD)),
                ),
              ),
              if (_confirmError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Passwords do not match',
                        style: GoogleFonts.dangrek(color: Colors.red))),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emergencyCtrl,
                hint: 'Emergency contact',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF1800AD)),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
              ),
              if (_emergencyError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Enter a valid phone number',
                        style: GoogleFonts.dangrek(color: Colors.red))),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _blockCtrl,
                hint: 'Block',
                prefixIcon:
                const Icon(Icons.home_outlined, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              if (_blockError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Enter your block',
                      style: GoogleFonts.dangrek(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              _buildTextField(
                  controller: _roomCtrl,
                  hint: 'Room',
                  prefixIcon: const Icon(Icons.meeting_room_outlined, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\s]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              if (_roomError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Enter your room number',
                        style: GoogleFonts.dangrek(color: Colors.red))),
              const SizedBox(height: 18),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
              if (_error.isNotEmpty)
                Text(_error,
                    style:
                    GoogleFonts.dangrek(color: Colors.red, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account? ",
                        style: GoogleFonts.dangrek(
                            color: const Color(0xFF000000), fontSize: 18)),
                    SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: Text('Login',
                            style: GoogleFonts.dangrek(
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
