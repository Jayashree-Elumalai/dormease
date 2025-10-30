import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dormease_app/screens/login_pg.dart';
import 'package:dormease_app/screens/admin/admin_annnouncements_pg.dart';
import 'package:dormease_app/screens/admin/admin_lostnfound_pg.dart';
import 'package:dormease_app/screens/admin/admin_parcel_pg.dart';
import 'package:dormease_app/screens/admin/admin_report_pg.dart';


class AdminSosPg extends StatefulWidget {
  const AdminSosPg({super.key});

  @override
  State<AdminSosPg> createState() => _AdminSosPgState();
}

class _AdminSosPgState extends State<AdminSosPg> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // stay on same page if already selected

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: const Text(
          'SOS',
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
      body: const Center(
        child: Text(
          "This is the SOS Page",
          style: TextStyle(fontSize: 18),
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
