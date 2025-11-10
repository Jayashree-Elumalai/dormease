import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// flutter_typeahead v5
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:dormease_app/screens/login_pg.dart';
import 'package:dormease_app/screens/admin/admin_annnouncements_pg.dart';
import 'package:dormease_app/screens/admin/admin_lostnfound_pg.dart';
import 'package:dormease_app/screens/admin/admin_report_pg.dart';
import 'package:dormease_app/screens/admin/admin_sos_pg.dart';
import '/services/auth_service.dart';


class AdminParcelPg extends StatefulWidget {
  const AdminParcelPg({super.key});

  @override
  State<AdminParcelPg> createState() => _AdminParcelPgState();
}

class _AdminParcelPgState extends State<AdminParcelPg> {
  int _selectedIndex = 1;
  String? selectedStudent;
  String? selectedStudentId; // Firestore doc.id
  String? selectedStudentName; // display name
  String? selectedStudentRegId;//actual student id

  // Controller provided by TypeAheadField (assigned inside builder)
  TextEditingController? _studentFieldController;

  // 🔄 CHANGED: Changed from showClaimed to parcelFilter with 3 options
  String parcelFilter = 'unclaimed'; // 'unclaimed', 'waiting', 'confirmed'

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

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

  Future<void> _sendParcelNotification() async {
    if (selectedStudentId == null || selectedStudentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a student"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {

      await FirebaseFirestore.instance.collection('parcels').add({
        'studentUid': selectedStudentId,   // Firebase UID
        'studentId': selectedStudentRegId, //Student ID
        'studentName': selectedStudentName,
        'sentAt': FieldValue.serverTimestamp(),
        'claimed': false,
        'claimedAt': null,
        'confirmed': false,
        'confirmedAt': null,
        'confirmedBy': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Parcel notification sent!"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedStudent = null;
        selectedStudentId = null;
        selectedStudentName = null;
        selectedStudentRegId = null;
        // clear the text field shown to admin
        _studentFieldController?.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // admin only confirms (student claims first)
  Future<void> _confirmParcel(String parcelId) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('parcels').doc(parcelId).update({
        'confirmed': true,
        'confirmedAt': FieldValue.serverTimestamp(),
        'confirmedBy': adminUid, // Track which admin confirmed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Parcel confirmed!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return "N/A";
    return DateFormat('dd MMM, h:mm a').format(ts.toDate());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: const Text(
          'Parcel',
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
              onPressed:  () => AuthService.logout(context),
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Searchable student field (TypeAheadField v5) =====
            // 🔄 CHANGED: Now filters by approvalStatus = 'approved'
            TypeAheadField<Map<String, dynamic>>(
              suggestionsCallback: (pattern) async {
                final q = pattern.toLowerCase().trim();
                if (q.isEmpty) return <Map<String, dynamic>>[];

                // 🆕 NEW: Filter to show only approved students
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'student')
                    .where('approvalStatus', isEqualTo: 'approved') // 🆕 NEW
                    .where('nameLower', isGreaterThanOrEqualTo: q)
                    .where('nameLower', isLessThanOrEqualTo: '$q\uf8ff')
                    .limit(20)
                    .get();

                return snap.docs.map((d) {
                  final data = d.data();
                  return {
                    'uid': d.id,
                    'studentId': data['studentId'] ?? '',
                    'name': data['name'] ?? '',
                  };
                }).toList();
              },

              builder: (context, controller, focusNode) {
                _studentFieldController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: "Search and select student",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                );
              },

              itemBuilder: (context, suggestion) {
                return ListTile(
                  title: Text(suggestion['name'] as String),
                  subtitle: Text(
                      'Student ID: ${suggestion['studentId'] as String}',
                      style: const TextStyle(fontSize: 12)),
                );
              },

              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("No students found"),
              ),

              onSelected: (suggestion) {
                setState(() {
                  selectedStudentId = suggestion['uid'] as String;
                  selectedStudentName = suggestion['name'] as String;
                  selectedStudentRegId = suggestion['studentId'] as String;
                  _studentFieldController?.text = selectedStudentName ?? '';
                });
              },

              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),

              decorationBuilder: (context, child) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1800AD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _sendParcelNotification,
              child: const Text(
                "Send Notification",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // 🔄 CHANGED: 3 toggle buttons instead of 2
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Unclaimed button
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: parcelFilter == 'unclaimed'
                            ? const Color(0xFF1800AD)
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () {
                        setState(() => parcelFilter = 'unclaimed');
                      },
                      child: const Text(
                        "Unclaimed",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Waiting Confirmation button
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: parcelFilter == 'waiting'
                            ? const Color(0xFF1800AD)
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () {
                        setState(() => parcelFilter = 'waiting');
                      },
                      child: const Text(
                        "Waiting",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Confirmed button
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: parcelFilter == 'confirmed'
                            ? const Color(0xFF1800AD)
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () {
                        setState(() => parcelFilter = 'confirmed');
                      },
                      child: const Text(
                        "Confirmed",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 🔄 CHANGED: Different queries based on filter
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                key: ValueKey(parcelFilter),
                stream: _getParcelStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final parcels = snapshot.data!.docs;

                  if (parcels.isEmpty) {
                    String emptyMessage;
                    switch (parcelFilter) {
                      case 'unclaimed':
                        emptyMessage = "No unclaimed parcels";
                        break;
                      case 'waiting':
                        emptyMessage = "No parcels waiting for confirmation";
                        break;
                      case 'confirmed':
                        emptyMessage = "No confirmed parcels";
                        break;
                      default:
                        emptyMessage = "No parcels";
                    }
                    return Center(
                      child: Text(
                        emptyMessage,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: parcels.length,
                    itemBuilder: (context, index) {
                      final doc = parcels[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildParcelCard(doc.id, data);
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

  // 🆕 NEW: Get stream based on current filter
  Stream<QuerySnapshot> _getParcelStream() {
    Query query = FirebaseFirestore.instance.collection('parcels');

    switch (parcelFilter) {
      case 'unclaimed':
      // Show parcels that haven't been claimed by student yet
        query = query
            .where('claimed', isEqualTo: false)
            .orderBy('sentAt', descending: true);
        break;

      case 'waiting':
      // Show parcels claimed by student but not confirmed by admin
        query = query
            .where('claimed', isEqualTo: true)
            .where('confirmed', isEqualTo: false)
            .orderBy('claimedAt', descending: true);
        break;

      case 'confirmed':
      // Show parcels confirmed by admin
        query = query
            .where('confirmed', isEqualTo: true)
            .orderBy('confirmedAt', descending: true);
        break;
    }

    return query.snapshots();
  }

  // 🔄 CHANGED: Build different card layouts based on filter
  Widget _buildParcelCard(String parcelId, Map<String, dynamic> data) {
    final studentName = data['studentName'] ?? 'Unknown';
    final studentId = data['studentId'] ?? 'N/A';
    final sentAt = data['sentAt'] as Timestamp?;
    final claimedAt = data['claimedAt'] as Timestamp?;
    final confirmedAt = data['confirmedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student name
            Text(
              studentName,
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),

            // 🆕 NEW: Show Student ID
            Text(
              'Student ID: $studentId',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),

            // Show different info based on filter
            if (parcelFilter == 'unclaimed') ...[
              _buildInfoRow(Icons.access_time, 'Sent', _formatTime(sentAt)),
            ] else if (parcelFilter == 'waiting') ...[
              _buildInfoRow(Icons.access_time, 'Claimed', _formatTime(claimedAt)),
              const SizedBox(height: 8),
              // 🆕 NEW: Confirm button for waiting parcels
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _confirmParcel(parcelId),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    "Confirm Collection",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else if (parcelFilter == 'confirmed') ...[
              _buildInfoRow(Icons.access_time, 'Claimed', _formatTime(claimedAt)),
              _buildInfoRow(Icons.check_circle, 'Confirmed', _formatTime(confirmedAt)),
            ],
          ],
        ),
      ),
    );
  }

  // 🆕 NEW: Helper to build info rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.firaSans(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
