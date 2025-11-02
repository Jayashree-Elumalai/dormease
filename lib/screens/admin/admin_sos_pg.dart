import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'admin_annnouncements_pg.dart';
import 'admin_lostnfound_pg.dart';
import 'admin_parcel_pg.dart';
import 'admin_report_pg.dart';
import 'admin_sos_detail_pg.dart'; // ✅ NEW - we'll create this
import '../../services/auth_service.dart';

class AdminSosPg extends StatefulWidget {
  const AdminSosPg({super.key});

  @override
  State<AdminSosPg> createState() => _AdminSosPgState();
}

class _AdminSosPgState extends State<AdminSosPg> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // ✅ Active + Resolved tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  // ✅ Get count of active/acknowledged alerts for badge
  Stream<int> _getActiveAlertCount() {
    return FirebaseFirestore.instance
        .collection('sosAlerts')
        .where('status', whereIn: ['active', 'acknowledged'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ✅ Get active/acknowledged alerts stream
  Stream<QuerySnapshot> _getAlertsStream(String status) {
    if (status == 'active_acknowledged') {
      // ✅ Show both active and acknowledged
      return FirebaseFirestore.instance
          .collection('sosAlerts')
          .where('status', whereIn: ['active', 'acknowledged'])
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // ✅ Resolved only
      return FirebaseFirestore.instance
          .collection('sosAlerts')
          .where('status', isEqualTo: 'resolved')
          .orderBy('resolvedAt', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: Text(
          'SOS Alerts',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
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
              onPressed: () => AuthService.logout(context),
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.dangrek(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.dangrek(fontSize: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active'), // ✅ Active + Acknowledged
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertsList('active_acknowledged'), // ✅ Active/Acknowledged
          _buildAlertsList('resolved'), // ✅ Resolved
        ],
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _getActiveAlertCount(),
        builder: (context, snapshot) {
          final badgeCount = snapshot.data ?? 0;
          return Container(
            height: 60,
            decoration: const BoxDecoration(
              color:Colors.white,
              boxShadow:[
                BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, -2),
                ),
              ],
            ),
           // ✅ FIXED
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: const Color(0xFF1800AD),
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.transparent,  // ✅ Make transparent since Container has decoration
              elevation: 0,
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reports'),
                const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Parcel'),
                BottomNavigationBarItem(
                  icon: badgeCount > 0
                      ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.warning),
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                      : const Icon(Icons.warning),
                  label: 'SOS',
                ),
                const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Lost/Found'),
                const BottomNavigationBarItem(icon: Icon(Icons.announcement), label: 'Announce'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ Build alerts list (Active or Resolved)
  Widget _buildAlertsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAlertsStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.red));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(status);
        }

        final alerts = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final doc = alerts[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildAlertCard(doc.id, data);
            },
          ),
        );
      },
    );
  }

  // ✅ Build alert card
  Widget _buildAlertCard(String alertId, Map<String, dynamic> data) {
    final status = data['status'] as String;
    final studentName = data['studentName'] ?? 'Unknown';
    final studentId = data['studentId'] ?? 'N/A';
    final location = data['location'] ?? 'Unknown';
    final category = data['category'] ?? 'emergency';
    final createdAt = data['createdAt'] as Timestamp?;
    final acknowledgedBy = data['acknowledgedBy'] as String?;

    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 2), // ✅ Colored border
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminSosDetailPage(alertId: alertId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Status badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status), size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: GoogleFonts.firaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✅ Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_getCategoryEmoji(category)} ${_formatCategory(category)}',
                      style: GoogleFonts.firaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(category),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ✅ Student info
              Row(
                children: [
                  Icon(Icons.person, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$studentName ($studentId)',
                      style: GoogleFonts.firaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1800AD),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ✅ Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ✅ Timestamp
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    createdAt != null
                        ? DateFormat('MMM d, yyyy - h:mm a').format(createdAt.toDate())
                        : 'N/A',
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // ✅ Show who acknowledged (if applicable)
              if (acknowledgedBy != null) ...[
                const SizedBox(height: 6),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(acknowledgedBy).get(),
                  builder: (context, snapshot) {
                    String adminName = 'Admin';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      adminName = snapshot.data!.get('name') ?? 'Admin';
                    }
                    return Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Responded by: $adminName',
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 10),

              // ✅ Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSosDetailPage(alertId: alertId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'active' ? Colors.red : const Color(0xFF1800AD),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    status == 'active' ? 'RESPOND NOW' : 'View Details',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
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

  // ✅ Empty state
  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == 'resolved' ? Icons.check_circle_outline : Icons.notification_important,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            status == 'resolved' ? 'No Resolved Alerts' : 'No Active Alerts',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status == 'resolved'
                ? 'Resolved alerts will appear here'
                : 'Active SOS alerts will appear here',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Helper functions
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red;
      case 'acknowledged':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.warning_amber_rounded;
      case 'acknowledged':
        return Icons.check_circle_outline;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'ACTIVE';
      case 'acknowledged':
        return 'RESPONDING';
      case 'resolved':
        return 'RESOLVED';
      default:
        return 'UNKNOWN';
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'safety':
        return '⚠️';
      default:
        return '❓';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Colors.red[700]!;
      case 'medical':
        return Colors.blue[700]!;
      case 'safety':
        return Colors.orange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _formatCategory(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}