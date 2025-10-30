import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';


import 'package:dormease_app/screens/login_pg.dart';
import 'package:dormease_app/screens/admin/admin_lostnfound_pg.dart';
import 'package:dormease_app/screens/admin/admin_parcel_pg.dart';
import 'package:dormease_app/screens/admin/admin_report_pg.dart';
import 'package:dormease_app/screens/admin/admin_sos_pg.dart';



class AdminAnnouncementsPg extends StatefulWidget {
  const AdminAnnouncementsPg({super.key});

  @override
  State<AdminAnnouncementsPg> createState() => _AdminAnnouncementsPgState();
}

class _AdminAnnouncementsPgState extends State<AdminAnnouncementsPg> {
  int _selectedIndex = 4; // default: announcements tab selected

  // 🔹 ADDED: controllers to get text input
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _announcementController = TextEditingController();

  @override
  void dispose() {
    // 🔹 ADDED: dispose controllers to avoid memory leaks
    _titleController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

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
        title: const Text(
          'Announcements',
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
      // 🔹 CHANGED: replaced the placeholder Center(Text(...)) with Column + announcement section
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 Announcements section (inserted here)
            GestureDetector(
              onTap: () {
              },
              child: Container(
                width: double.infinity,
                height: 275, // fixed height
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(
                    color: const Color(0xFF1800AD),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // 🔹 Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.campaign,
                            color: Color(0xFF1800AD), size: 28),
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: const InputDecorationTheme(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                            ),

                            child: TextField(
                              controller: _titleController,
                              maxLines: 1, // 🔹 only one line
                              textAlign: TextAlign.center, // keeps it centered like before
                              decoration: const InputDecoration(
                                hintText: "Title...",
                                counterText: "",
                                isDense: true, // ✅ reduces padding
                                contentPadding: EdgeInsets.only(bottom: 0), // ✅ remove extra padding
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1800AD),
                              ),
                              maxLength: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 🔹 Latest announcement input
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                        child: TextField(
                          controller: _announcementController,
                          maxLines: null, // allows multiple lines
                          expands: true,  // fills the available space
                          maxLength: 300,
                          decoration: const InputDecoration(
                            hintText: "Enter announcement here...",
                          ),
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // 🔹 Post button
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () async {
                          final title = _titleController.text.trim();
                          final announcement = _announcementController.text.trim();

                          if (title.isEmpty || announcement.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Title and announcement cannot be empty."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // 🔹 Save to Firestore
                          await FirebaseFirestore.instance.collection('announcements').add({
                            'title': title,
                            'announcement': announcement,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          // Clear inputs after posting
                          _titleController.clear();
                          _announcementController.clear();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Announcement posted successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },

                        child: const Text(
                          "Post",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height:10),

      // 🔹 NEW: Announcement list from Firestore
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
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
                    padding:EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🔹 Title row with delete button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1800AD),
                                    height: 1.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),

                        SizedBox(
                            width: 28, // small tap target width
                            height: 28, // small tap target height
                            child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            iconSize: 20,              // smaller icon
                            padding: EdgeInsets.zero,  // removes default internal padding
                            constraints: const BoxConstraints(), // removes minWidth/minHeight
                            splashRadius: 18,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(

                                  titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom:5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  title: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [

                                      Center(
                                        child: Text(
                                          "Delete Announcement",
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

                                  content: Text(
                                    "Are you sure you want to delete this announcement?",
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14, // 🔹 Larger font
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1800AD), // 🔹 Navy blue
                                    ),
                                  ),
                                  actionsPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(
                                        "Cancel",
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14, // 🔹 Bigger font
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(
                                        "Delete",
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14, // 🔹 Bigger font
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('announcements')
                                      .doc(data.id)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Announcement deleted"),
                                      backgroundColor: Colors.red,
                                    )
                                  );
                                }
                              },
                            ),
                        ),
                        ],
                        ),

                        Text(
                          announcement,
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.20,//space between announcment words
                          ),
                        ),

                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(timestamp),
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1800AD),
                              height: 1.0,
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