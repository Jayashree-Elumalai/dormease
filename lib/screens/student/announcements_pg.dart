import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'connect_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int _selectedIndex = 2; // pretend "Home" is selected, but force grey color

  void _onItemTapped(int index) {
    if (index == _selectedIndex && index != 2) return;

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
          'Announcements',
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

      // 🔹 REPLACED body with Firestore announcements list
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No announcements for now",
                style: TextStyle(color: Colors.grey),));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final title = data['title'] ?? '';
              final announcement = data['announcement'] ?? '';
              final timestamp = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1800AD),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement,
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(timestamp),
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1800AD),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
            _buildNavItem(Icons.home, 'Home', 2, forceGrey: true),
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
