import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'connect_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';

class ParcelPage extends StatefulWidget {
  const ParcelPage({super.key});

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> {
  int _selectedIndex = 1;
  String parcelFilter = 'unclaimed'; // 'unclaimed', 'waiting', 'confirmed'

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

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

  // 🆕 NEW: Student claims parcel
  Future<void> _claimParcel(String parcelId) async {
    try {
      await FirebaseFirestore.instance.collection('parcels').doc(parcelId).update({
        'claimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Parcel claimed! Waiting for admin confirmation."),
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

  // 🆕 NEW: Get stream based on filter and current student
  Stream<QuerySnapshot> _getParcelStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('parcels')
        .where('studentUid', isEqualTo: currentUser.uid);

    switch (parcelFilter) {
      case 'unclaimed':
      // Show parcels student hasn't claimed yet
        query = query
            .where('claimed', isEqualTo: false)
            .orderBy('sentAt', descending: true);
        break;

      case 'waiting':
      // Show parcels student claimed but admin hasn't confirmed
        query = query
            .where('claimed', isEqualTo: true)
            .where('confirmed', isEqualTo: false)
            .orderBy('claimedAt', descending: true);
        break;

      case 'confirmed':
      // Show parcels admin confirmed
        query = query
            .where('confirmed', isEqualTo: true)
            .orderBy('confirmedAt', descending: true);
        break;
    }

    return query.snapshots();
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

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🆕 NEW: 3 toggle buttons
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

                // Waiting button
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
            const SizedBox(height: 16),

            // 🆕 NEW: Parcel list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                key: ValueKey(parcelFilter),
                stream: _getParcelStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading parcels',
                        style: GoogleFonts.firaSans(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    String emptyMessage;
                    switch (parcelFilter) {
                      case 'unclaimed':
                        emptyMessage = "No unclaimed parcels";
                        break;
                      case 'waiting':
                        emptyMessage = "No parcels waiting confirmation";
                        break;
                      case 'confirmed':
                        emptyMessage = "No confirmed parcels";
                        break;
                      default:
                        emptyMessage = "No parcels";
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            emptyMessage,
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final parcels = snapshot.data!.docs;

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
            _buildNavItem(Icons.home, 'Home', 2),
            _buildNavItem(Icons.chat, 'Connect', 3),
            _buildNavItem(Icons.warning, 'SOS', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    Color color = isSelected ? const Color(0xFF1800AD) : Colors.grey;

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

  // 🆕 NEW: Build parcel card based on filter
  Widget _buildParcelCard(String parcelId, Map<String, dynamic> data) {
    final sentAt = data['sentAt'] as Timestamp?;
    final claimedAt = data['claimedAt'] as Timestamp?;
    final confirmedAt = data['confirmedAt'] as Timestamp?;

    // Status badge color
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (parcelFilter) {
    case 'unclaimed':
    statusColor = Colors.orange;
    statusText = 'UNCLAIMED';
    statusIcon = Icons.mail_outline;
    break;
    case 'waiting':
    statusColor = Colors.blue;
    statusText = 'TO CONFIRM';
    statusIcon = Icons.hourglass_empty;
    break;
    case 'confirmed':
    statusColor = Colors.green;
    statusText = 'COLLECTED';
    statusIcon = Icons.check_circle;
    break;
    default:
    statusColor = Colors.grey;
    statusText = 'UNKNOWN';
    statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parcel Notification',
                  style: GoogleFonts.firaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1800AD),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: GoogleFonts.firaSans(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Show different info based on filter
            if (parcelFilter == 'unclaimed') ...[
              _buildInfoRow(Icons.access_time, 'Sent', _formatTime(sentAt)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _claimParcel(parcelId),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    "Claim Parcel",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ] else if (parcelFilter == 'waiting') ...[
              _buildInfoRow(Icons.send, 'Sent', _formatTime(sentAt)),
              _buildInfoRow(Icons.check, 'Claimed', _formatTime(claimedAt)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for admin to confirm your collection',
                        style: GoogleFonts.firaSans(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (parcelFilter == 'confirmed') ...[
              _buildInfoRow(Icons.send, 'Sent', _formatTime(sentAt)),
              _buildInfoRow(Icons.check, 'Claimed', _formatTime(claimedAt)),
              _buildInfoRow(Icons.check_circle, 'Confirmed', _formatTime(confirmedAt)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Parcel collection confirmed by admin',
                        style: GoogleFonts.firaSans(
                          fontSize: 13,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper to build info rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
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
      ),
    );
  }
}