import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'student/home_pg.dart';
import 'admin/admin_home_pg.dart';
import 'waiting_approval_pg.dart'; // ✅ NEW import
import '../services/fcm_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user;
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
        setState(() => _status =
        'Too many requests. Please wait a while before trying again');
      } else {
        setState(() => _status = 'Failed to resend: ${e.message}');
      }
    } finally {
      if (mounted && _resendCooldown == 0) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = '';
    });
    try {
      await widget.user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        // Update Firestore flag
        final userDoc =
        FirebaseFirestore.instance.collection('users').doc(fresh.uid);
        await userDoc.update({'isProfileVerified': true});

        // Fetch role and approval status
        final snap = await userDoc.get();
        final role = snap['role'] ?? 'student';
        final approvalStatus = snap['approvalStatus'] ?? 'approved'; // ✅ NEW

        if (!mounted) return;

        if (role == 'admin') {
          await FCMService.initializeFCM();

          if (!mounted) return;
          // 🚀 Admin goes directly to admin home (no approval needed)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                (r) => false,
          );
        } else {
          // 🚀 Student - check approval status
          if (approvalStatus == 'pending' || approvalStatus == 'rejected') {
            // Send to waiting screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
                  (r) => false,
            );
          } else if (approvalStatus == 'approved') {
            await FCMService.initializeFCM();

            if (!mounted) return;
            // Already approved (shouldn't happen for new registrations, but handle it)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (r) => false,
            );
          } else {
            setState(() => _status = 'Unknown approval status. Contact admin.');
          }
        }
      } else {
        setState(() =>
        _status = 'Email not verified yet. Please check your inbox.');
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
                style:
                GoogleFonts.dangrek(fontSize: 20, color: Colors.blue)),
            const SizedBox(height: 20),
            Text(
              "Please open the email and click the verification link. After verifying, tap 'I've verified'.",
              style: GoogleFonts.dangrek(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
              style:
              GoogleFonts.dangrek(color: Colors.red, fontSize: 18),
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


