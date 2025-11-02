import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../login_pg.dart';
import 'admin_annnouncements_pg.dart';
import 'admin_lostnfound_pg.dart';
import 'admin_parcel_pg.dart';
import 'admin_report_pg.dart';
import 'admin_sos_pg.dart';
import 'admin_verification_pg.dart'; // ✅ NEW import
import '../../services/auth_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<String> getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "User";
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['name'] ?? "User";
  }

  @override
  Widget build(BuildContext context) {
    // ✅ TEMPORARY: Debug FCM tokens
    FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get()
        .then((doc) {
      final tokens = doc.data()?['fcmTokens'] as List?;
      debugPrint('🔍 Admin FCM Tokens: $tokens');
      if (tokens == null || tokens.isEmpty) {
        debugPrint('⚠️ WARNING: Admin has NO FCM tokens!');

        // ✅ Show on-screen warning
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ WARNING: FCM tokens not found. Notifications may not work!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        debugPrint('✅ Admin has ${tokens.length} FCM token(s)');
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    onPressed:  () => AuthService.logout(context),

                    child: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                              builder: (_) => const AdminReportPg()),
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
                              builder: (_) => const AdminParcelPg()),
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
              const SizedBox(height: 16),
              // ✅ NEW: Verify Students Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminVerifyStudentsPg()),
                    );
                  },
                  icon: const Icon(Icons.verified_user,
                      size: 28, color: Colors.white),
                  label: const Text(
                    "VERIFY STUDENTS",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                fontSize: 20,
                color: Color(0xFF1800AD),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

