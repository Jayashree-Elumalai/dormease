import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_pg.dart';
import 'student/register_pg.dart'; // 🆕 ADDED: Import register page
import 'update_registration_pg.dart'; // 🆕 ADDED: Import update page

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

  // 🆕 ADDED: Delete account function
  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Delete Account?",
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'This will permanently delete your account. You\'ll need to register again from scratch.',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1800AD),
              ),

            ),
            const SizedBox(height: 16),
            Text(
              'To confirm, please enter your password:',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),

            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: GoogleFonts.firaSans(fontWeight: FontWeight.bold, color: Colors.grey),
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1800AD)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter your password',
                      style: GoogleFonts.firaSans(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text(
              'Delete & Re-register',
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

    if (confirm != true || passwordController.text.trim().isEmpty) return;

    // 🆕 ADDED: Execute account deletion
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Deleting account...',
                    style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Re-authenticate user
      final email = user.email!;
      final password = passwordController.text.trim();
      final credential = EmailAuthProvider.credential(email: email, password: password);

      await user.reauthenticateWithCredential(credential);

      // Delete Firestore document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth account
      await user.delete();

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Navigate to Register page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
            (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deleted. You can now register with correct information',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      String errorMessage;
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log out and log in again before deleting your account.';
      } else {
        errorMessage = 'Error: ${e.message}';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 ADDED: Navigate to update info page
  Future<void> _navigateToUpdateInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateRegistrationPage(
          uid: user.uid,
          currentData: doc.data()!,
        ),
      ),
    ).then((_) {
      // Refresh the screen after returning
      setState(() {});
    });
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
          TextButton(
            onPressed: _logout,
            child: Text(
              'Logout',
              style: GoogleFonts.dangrek(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
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
  //PENDING APPROVAL UI
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
            style: GoogleFonts.dangrek(fontSize: 20, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while administrator reviews and approves your account',
            style: GoogleFonts.dangrek(fontSize: 20, color: Colors.black54),
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
          const SizedBox(height: 30),

        ],
      ),
    );
  }

  // REJECTED UI
  Widget _buildRejectedUI(String? reason) {
    return SingleChildScrollView( // 🆕 ADDED: Make scrollable for smaller screens
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cancel,
            size: 80,
            color: Colors.red,
          ),

          Text(
            'Account Rejected',
            style: GoogleFonts.dangrek(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          Text(
            'Your registration was not approved by the administrator',
            style: GoogleFonts.dangrek(fontSize: 20, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 20),
          Text(
            'What would you like to do?',
            style: GoogleFonts.dangrek(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // 🆕 ADDED: Update Information Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade300, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Fix incorrect room, block or contact details',
                  style: GoogleFonts.dangrek(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 220, // ✂️ NEW: Fixed width instead of double.infinity
                    child: ElevatedButton.icon(
                      onPressed: _navigateToUpdateInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1800AD),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),

                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      label: Text(
                        'Update Information',
                        style: GoogleFonts.dangrek(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),


          // “OR” divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                const Expanded(
                  child: Divider(
                    color: Colors.black26,
                    thickness: 1.2,
                    endIndent: 10,
                  ),
                ),
                Text(
                  'OR',
                  style: GoogleFonts.dangrek(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Expanded(
                  child: Divider(
                    color: Colors.black26,
                    thickness: 1.2,
                    indent: 10,
                  ),
                ),
              ],
            ),
          ),



          // 🆕 ADDED: Delete Account Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Choose this if email or Student ID incorrect',
                  style: GoogleFonts.dangrek(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 220, // ✂️ NEW: Fixed width instead of double.infinity
                    child: ElevatedButton.icon(
                      onPressed: _confirmDeleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10), // 📏 CHANGED: 12→10
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                      label: Text(
                        'Delete Account',
                        style: GoogleFonts.dangrek(fontSize: 16, color: Colors.white), // 📏 CHANGED: 16→15
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

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
            'Your account has been approved. You can now login',
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