import 'package:dormease_app/screens/student/announcements_pg.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Your actual pages
import 'connect_pg.dart';
import 'lost_found_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';
import '../login_pg.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

              // 🔹 Announcements section (clickable)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnnouncementsPage()), // ✅ correct
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 170, // ✅ fixed height to make the box taller
                  padding: const EdgeInsets.only(
                    left: 12,   // same as horizontal
                    right: 12,  // same as horizontal
                    top: 8,     // smaller top padding
                    bottom: 4, // bigger bottom padding
                  ),

                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(
                      color: const Color(0xFF1800AD), // ✅ navy border
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('announcements')
                        .orderBy('timestamp', descending: true)
                        .limit(1) // ✅ only latest
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text(
                            "No announcements for now",
                            style: TextStyle(color: Colors.grey),));
                      }

                      final doc = snapshot.data!.docs.first;
                      final title = doc['title'] ?? '';
                      final announcement = doc['announcement'] ?? '';
                      final timestamp = doc['timestamp'] != null
                          ? (doc['timestamp'] as Timestamp).toDate()
                          : DateTime.now();

                      final formattedTimestamp =
                      DateFormat('dd MMM yyyy, HH:mm').format(timestamp);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔹 Title row (megaphone + actual title)
                          Center(
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.campaign,
                                  color: Color(0xFF1800AD), size: 28),
                              const SizedBox(width: 8),
                              Text(
                                  title, // ✅ actual title from Firestore
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1800AD),
                                  ),
                                ),
                            ],
                          ),
                          ),

                          const SizedBox(height: 6),

                          // 🔹 Preview
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                announcement,
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // 🔹 Timestamp bottom-right
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              formattedTimestamp,
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                color: const Color(0xFF1800AD),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                      "REPORT ISSUE",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReportIssuePage()),
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
                              builder: (_) => const ParcelPage()),
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
                              builder: (_) => const LostFoundPage()),
                        );
                      },
                    ),
                    _buildFeatureItem(
                      context,
                      "assets/images/connect.png",
                      "CONNECT",
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ConnectPage()),
                        );
                      },
                    ),
                  ],
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
                      MaterialPageRoute(builder: (_) => const SosPage()),
                    );
                  },
                  child: const Text(
                    "SOS",
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

