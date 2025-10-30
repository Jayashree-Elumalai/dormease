/*
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

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int _selectedIndex = 2; //

  void _onItemTapped(int index) {
    if (index == _selectedIndex && index != 2) return; // 👈added && index != 2 to show current pg not in navbar

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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      body: const Center(
        child: Text(
          "This is the Announcements Page",
          style: TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar:Container(
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
            _buildNavItem(Icons.home, 'Home', 2, forceGrey: true), // 👈 Home forced grey
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

/* database rules (ori)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // for testing only
    }
  }
}
 */

/* SPECIFIC DB & STORAGE RULES FOR PARCEL,ANNOUNCMENT, REPORT ISSUE(STUDENT)

 Secure Rules (For Final Submission).✅ Better security
✅ Shows you understand database security
✅ Can explain in FYP report: "Implemented role-based access control"
DB:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }

    // Users collection
    match /users/{uid} {
      allow read: if isAuthenticated();
      allow write: if request.auth.uid == uid || isAdmin();
    }

    // Reports collection
    match /reports/{reportId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
                       request.resource.data.studentUid == request.auth.uid;
      allow update, delete: if isAuthenticated() &&
                               (resource.data.studentUid == request.auth.uid || isAdmin());
    }

    // 🆕 Parcels collection (ADDED)
    match /parcels/{parcelId} {
      allow read: if isAuthenticated();
      allow create: if isAdmin();
      allow update: if isAuthenticated() &&
                       (resource.data.studentUid == request.auth.uid || isAdmin());
      allow delete: if isAdmin();
    }

    // 🆕 Announcements collection (ADDED)
    match /announcements/{announcementId} {
      allow read: if isAuthenticated();
      allow create, update, delete: if isAdmin();
    }

    // 🆕 Add any other collections you have (Lost & Found, SOS, etc.)
    match /lostAndFound/{itemId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAuthenticated() &&
                               (resource.data.reportedBy == request.auth.uid || isAdmin());
    }

    match /sos/{sosId} {
      allow read, write: if isAuthenticated();
    }

    // 🆕 Add rules for any other collections you might have
    // If you're not sure, you can temporarily use this catch-all (NOT recommended for production):
    // match /{document=**} {
    //   allow read, write: if isAuthenticated();
    // }
  }
}


STORAGE RULES:
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Reports images
    match /reports/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // If you have other storage paths (announcements images, profile pics, etc.)
    match /announcements/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Catch-all (for testing - remove in production)
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
 */