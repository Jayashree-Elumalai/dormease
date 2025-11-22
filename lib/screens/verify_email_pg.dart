import 'dart:async';//for timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'student/home_pg.dart';
import 'admin/admin_home_pg.dart';
import 'waiting_approval_pg.dart'; //
import '../services/fcm_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user; // firebase user obj from register/login
  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false; //checking if resending email
  bool _checking = false;//checking if verifying email status in progress
  String _status = '';//display status message
  Timer? _resendCooldownTimer;// timer of 60 secs
  int _resendCooldown = 0;// can resend if only 0

  @override
  void dispose() {
    _resendCooldownTimer?.cancel(); //cancel cooldown timer
    super.dispose();
  }

  //resend verification email
  Future<void> _resend() async {
    if (_resendCooldown > 0) return;//cant resend if countdown active
    try {
      setState(() { //update ui, clear previous status
        _sending = true;
        _status = '';
      });
      //firebase send verification email to user
      await widget.user.sendEmailVerification();
      setState(() {//update ui-show success message
        _status = 'Verification email resent. Please check your inbox';
        _resendCooldown = 60; //start at 60 secs
      });
      //timer countdown
      _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown <= 0) {
          timer.cancel();//countdown stop when reach 0
        } else {
          setState(() => _resendCooldown--);//decrease by 1 sec
        }
      });
    } on FirebaseAuthException catch (e) {
      //handling firebase errors
      if (e.code == 'too-many-requests') {
        setState(() => _status =
        'Too many requests. Please wait a while before trying again');
      } else {
        setState(() => _status = 'Failed to resend: ${e.message}');
      }
    } finally {
      //Hide loading if cooldown 0
      if (mounted && _resendCooldown == 0) setState(() => _sending = false);
    }
  }

  //check email verification
  Future<void> _check() async {
    setState(() {//update ui
      _checking = true;
      _status = '';
    });
    try {
      // Firebase: Reload user to get latest verification status
      await widget.user.reload();
      final fresh = FirebaseAuth.instance.currentUser; // Get updated user
      //Check if email is now verified
      if (fresh != null && fresh.emailVerified) {
        // Update isProfileVerified to true
        final userDoc = FirebaseFirestore.instance.collection('users').doc(fresh.uid);
        await userDoc.update({'isProfileVerified': true});

        // Fetch role and approval status
        final snap = await userDoc.get();
        final role = snap['role'] ?? 'student'; //approval status only for students

        if (!mounted) return;

        //ADMIN FLOW
        if (role == 'admin') {
          // Initialize FCM for push notifications
          await FCMService.initializeFCM();

          if (!mounted) return;
          // Admin goes directly to admin home (no approval needed)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                (r) => false, //remove all previous routes
          );
        } else {
          //STUDENT FLOW- check approval status
          final approvalStatus = snap['approvalStatus'] ?? 'approved';
          // Student - check approval status
          if (approvalStatus == 'pending' || approvalStatus == 'rejected') {
            // Send to waiting screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
                  (r) => false,
            );
            //student approved
          } else if (approvalStatus == 'approved') {
            await FCMService.initializeFCM();//initialize FCM

            if (!mounted) return;
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
    } catch (e) {//handle errors
      setState(() => _status = 'Error checking verification: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _checking = false);//hide loading
    }
  }

  @override
  //VERIFY PG UI
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
            Text(widget.user.email ?? '',//shows users email
                style:
                GoogleFonts.dangrek(fontSize: 20, color: Colors.blue)),
            const SizedBox(height: 20),
            Text(
              "Please open the email and click the verification link. After verifying, tap 'I've verified'.",
              style: GoogleFonts.dangrek(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            //resend button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              //disable resend button if sending/cooldown active . prevent spamming
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
            //verify email button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              onPressed: _checking ? null : _check,//disable while checking
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
            //show status message- success/error
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


