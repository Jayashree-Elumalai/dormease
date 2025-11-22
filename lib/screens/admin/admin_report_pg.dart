import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'admin_home_pg.dart';
import 'admin_annnouncements_pg.dart';
import 'admin_lostnfound_pg.dart';
import 'admin_parcel_pg.dart';
import 'admin_sos_pg.dart';
import '/services/auth_service.dart';

class AdminReportPg extends StatefulWidget {
  const AdminReportPg({super.key});

  @override
  State<AdminReportPg> createState() => _AdminReportPgState();
}

class _AdminReportPgState extends State<AdminReportPg> {
  int _selectedIndex = 0;
  String reportFilter = 'all'; // 'all', 'pending', 'ongoing', 'completed'
  String categoryFilter = 'all';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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

  // Get reports stream with filters
  Stream<QuerySnapshot> _getReportStream() {
    Query query = FirebaseFirestore.instance.collection('reports');

    // Filter by status
    if (reportFilter != 'all') {
      query = query.where('status', isEqualTo: reportFilter);
    }

    // Filter by category
    if (categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    // Sort based on status
    if (reportFilter == 'pending') {
      // Pending: Oldest first (needs urgent attention)
      query = query.orderBy('createdAt', descending: false);
    } else {
      // All/Ongoing/Completed: Newest first
      query = query.orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }

  // Get statistics
  Stream<Map<String, int>> _getStatistics() {
    return FirebaseFirestore.instance
        .collection('reports')
        .snapshots()
        .map((snapshot) {
      int pending = 0;
      int ongoing = 0;
      int completed = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'pending';
        if (status == 'pending') pending++;
        if (status == 'ongoing') ongoing++;
        if (status == 'completed') completed++;
      }

      return {
        'pending': pending,
        'ongoing': ongoing,
        'completed': completed,
      };
    });
  }


  Stream<int> _getActiveReportCount() {
    return FirebaseFirestore.instance
        .collection('reports')
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'pending';
        if (status == 'pending' || status == 'ongoing') {
          count++;
        }
      }
      return count;
    });
  }

  // Quick action: Mark as Ongoing
  Future<void> _markAsOngoing(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mark as Ongoing?',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
        ),
        content: Text(
          'This will mark the report as ongoing and notify the student that work has started.',
          style: GoogleFonts.firaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
        'handledBy': adminUid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report marked as ongoing',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Quick action: Mark as Completed
  Future<void> _markAsCompleted(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mark as Completed?',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
        ),
        content: Text(
          'This will mark the report as completed and notify the student that the issue has been resolved.',
          style: GoogleFonts.firaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report marked as completed',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle urgent priority
  Future<void> _toggleUrgent(String reportId, bool currentUrgent) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'isUrgent': !currentUrgent,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentUrgent ? 'Removed from urgent' : 'Marked as urgent',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: currentUrgent ? Colors.grey : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getRelativeTime(Timestamp? ts) {
    if (ts == null) return "N/A";
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    if (diff.inDays < 30) return "${(diff.inDays / 7).floor()}w ago";
    return "${(diff.inDays / 30).floor()}mo ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: Text(
          'Report Issue',
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
              onPressed:() => AuthService.logout(context),
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Statistics Cards
              StreamBuilder<Map<String, int>>(
                stream: _getStatistics(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {'pending': 0, 'ongoing': 0, 'completed': 0};
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          stats['pending']!,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Ongoing',
                          stats['ongoing']!,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          stats['completed']!,
                          Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase().trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by student name...',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey,fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD),size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF1800AD),size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),

                ),
                style: GoogleFonts.firaSans(color: const Color(0xFF1800AD)),
              ),
              const SizedBox(height: 12),

              // Category Filter
              Row(
                children: [
                  Text(
                    'Category:',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1800AD),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF1800AD), width: 2),
                      ),
                      child: DropdownButton<String>(
                        value: categoryFilter,
                        isExpanded: true,
                        underline: const SizedBox(),
                        isDense: true,
                        itemHeight: 48,
                        style: GoogleFonts.firaSans(
                          color: const Color(0xFF1800AD),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Categories'),
                          ),
                          // 🔄 CHANGED: All emojis replaced with icons
                          DropdownMenuItem(
                            value: 'electrical',
                            child: Row(
                              children: [
                                Icon(Icons.electrical_services, color: Colors.amber, size: 16), // 🔄 size: 16
                                const SizedBox(width: 8),
                                const Text('Electrical'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'plumbing',
                            child: Row(
                              children: [
                                Icon(Icons.water_drop, color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                const Text('Plumbing'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'air_conditioning',
                            child: Row(
                              children: [
                                Icon(Icons.ac_unit, color: Colors.cyan, size: 16),
                                const SizedBox(width: 8),
                                const Text('Air Conditioning'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'furniture',
                            child: Row(
                              children: [
                                Icon(Icons.weekend, color: Colors.brown, size: 16),
                                const SizedBox(width: 8),
                                const Text('Furniture'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'cleanliness',
                            child: Row(
                              children: [
                                Icon(Icons.cleaning_services, color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                const Text('Cleanliness'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'security',
                            child: Row(
                              children: [
                                Icon(Icons.security, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                const Text('Security'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'structural',
                            child: Row(
                              children: [
                                Icon(Icons.foundation, color: Colors.grey, size: 16),
                                const SizedBox(width: 8),
                                const Text('Structural'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Row(
                              children: [
                                Icon(Icons.more_horiz, color: Colors.purple, size: 16),
                                const SizedBox(width: 8),
                                const Text('Other'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            categoryFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Pending', 'pending'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Ongoing', 'ongoing'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Completed', 'completed'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Report List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  key: ValueKey('$reportFilter-$categoryFilter'),
                  stream: _getReportStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading reports',
                          style: GoogleFonts.firaSans(color: Colors.red),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Filter by search query
                    var reports = snapshot.data!.docs.where((doc) {
                      if (searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                      return studentName.contains(searchQuery);
                    }).toList();

                    // Sort urgent reports to top for pending and ongoing
                    if (reportFilter == 'pending' || reportFilter == 'ongoing') {
                      reports.sort((a, b) {
                        final aUrgent = (a.data() as Map<String, dynamic>)['isUrgent'] ?? false;
                        final bUrgent = (b.data() as Map<String, dynamic>)['isUrgent'] ?? false;
                        if (aUrgent && !bUrgent) return -1;
                        if (!aUrgent && bUrgent) return 1;
                        return 0;
                      });
                    }

                    if (reports.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No reports found',
                              style: GoogleFonts.firaSans(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final doc = reports[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildReportCard(doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
        bottomNavigationBar: StreamBuilder<int>(
          stream: _getActiveReportCount(),
          builder: (context, snapshot) {
            final badgeCount = snapshot.data ?? 0;
            return Container(
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
                  _buildNavItem(Icons.report, 'Reports', 0, badgeCount: badgeCount),
                  _buildNavItem(Icons.inventory, 'Parcel', 1),
                  _buildNavItem(Icons.warning, 'SOS', 2),
                  _buildNavItem(Icons.search, 'Lost/Found', 3),
                  _buildNavItem(Icons.announcement, 'Announce', 4),
                ],
              ),
            );
          },
        ),
        );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4,horizontal: 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          Text(
            label,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = reportFilter == value;

    Color selectedColor;
    switch (value) {
      case 'pending':
        selectedColor = Colors.orange;
        break;
      case 'ongoing':
        selectedColor = Colors.blue;
        break;
      case 'completed':
        selectedColor = Colors.green;
        break;
      default:
        selectedColor = const Color(0xFF1800AD);
    }

    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.dangrek(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => reportFilter = value);
      },
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      selectedColor: selectedColor,
      backgroundColor: Colors.grey,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String message;
    String subtitle;

    switch (reportFilter) {
      case 'pending':
        icon = Icons.check_circle_outline;
        message = "No Pending Reports";
        subtitle = "All caught up!";
        break;
      case 'ongoing':
        icon = Icons.build_circle_outlined;
        message = "No Ongoing Reports";
        subtitle = "Nothing being fixed now";
        break;
      case 'completed':
        icon = Icons.inbox_outlined;
        message = "No Completed Reports";
        subtitle = "No resolved issues yet";
        break;
      default:
        icon = Icons.report_outlined;
        message = "No Reports Yet";
        subtitle = "No issues reported by students";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String reportId, Map<String, dynamic> data) {
    final issue = data['issue'] ?? 'Untitled';
    final category = data['category'] ?? 'other';
    final location = data['location'] ?? 'Unknown';
    final studentName = data['studentName'] ?? 'Unknown';
    final studentId = data['studentId'] ?? 'N/A';
    final status = data['status'] ?? 'pending';
    final sentAt = data['sentAt'] as Timestamp?;
    final imageUrl = data['imageUrl'] as String?;
    final isUrgent = data['isUrgent'] ?? false;

    // Get category config
    final categoryInfo = _getCategoryInfo(category);

    // Status badge
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'ongoing':
        statusColor = Colors.blue;
        statusText = 'ONGOING';
        statusIcon = Icons.build_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.pending;
    }

    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isUrgent ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isUrgent
              ? const BorderSide(color: Colors.red, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminReportDetailPage(
                  reportId: reportId,
                  reportData: data,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Header Row
            Row(
            children: [
            // Category icon
            Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryInfo['color'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryInfo['icon'],
              color: categoryInfo['color'],
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Issue title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue,
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1800AD),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isUrgent)
                  Row(
                    children: [
                      const Icon(Icons.priority_high, size: 14, color: Colors.red),
                      const SizedBox(width: 2),
                      Text(
                        'URGENT',
                        style: GoogleFonts.firaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: GoogleFonts.firaSans(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
        const SizedBox(height: 10),

        // Student info
        Row(
          children: [
            Icon(Icons.person, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$studentName ($studentId)',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Location
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Time and Image
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Sent: ${_getRelativeTime(sentAt)}',
              style: GoogleFonts.firaSans(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const Spacer(),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Icon(Icons.image, size: 16, color: Colors.grey[500]),
          ],
        ),
        const SizedBox(height: 10),

        // Action Buttons
        Row(
            children: [
            // Urgent toggle button (for pending and ongoing only)
            if (status != 'completed')
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _toggleUrgent(reportId, isUrgent),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                    color: isUrgent ? Colors.red : Colors.grey,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                  icon: Icon(
                    isUrgent ? Icons.priority_high : Icons.flag_outlined,
                    size: 14,
                    color: isUrgent ? Colors.red : Colors.grey[700],
                  ),
                  label: Text(
                    isUrgent ? 'Urgent' : 'Flag',
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUrgent ? Colors.red : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quick action button based on status
              if (status == 'pending')
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsOngoing(reportId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.build_circle, size: 16, color: Colors.white),
                    label: Text(
                      'Start',
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 2),

              if (status == 'ongoing')
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsCompleted(reportId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical:  6, horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                    label: Text(
                      'Complete',
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // View Details button
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminReportDetailPage(
                          reportId: reportId,
                          reportData: data,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38B6FF), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Details',
                        style: GoogleFonts.firaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF38B6FF),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF38B6FF)),
                    ],
                  ),
                ),
              ),
            ],
        ),
                ],
            ),
          ),
        ),
    );
  }

    Map<String, dynamic> _getCategoryInfo(String category) {
      const categoryMap = {
        'electrical': {
          'icon': Icons.electrical_services,
          'color': Colors.amber,
          'label': 'Electrical',
        },
        'plumbing': {
          'icon': Icons.water_drop,
          'color': Colors.blue,
          'label': 'Plumbing',
        },
        'air_conditioning': {
          'icon': Icons.ac_unit,
          'color': Colors.cyan,
          'label': 'Air Conditioning',
        },
        'furniture': {
          'icon': Icons.weekend,
          'color': Colors.brown,
          'label': 'Furniture',
        },
        'cleanliness': {
          'icon': Icons.cleaning_services,
          'color': Colors.green,
          'label': 'Cleanliness',
        },
        'security': {
          'icon': Icons.security,
          'color': Colors.red,
          'label': 'Security',
        },
        'structural': {
          'icon': Icons.foundation,
          'color': Colors.grey,
          'label': 'Structural',
        },
        'other': {
          'icon': Icons.more_horiz,
          'color': Colors.purple,
          'label': 'Other',
        },
      };

      return categoryMap[category] ?? categoryMap['other']!;
    }


    Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
      bool isSelected = _selectedIndex == index;
      Color color = isSelected ? const Color(0xFF1800AD) : Colors.grey;

      return InkWell(
        onTap: () => _onItemTapped(index),
        child: SizedBox(
          width: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Badge
              if (badgeCount > 0)
                Positioned(
                  right: 12,
                  top: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }





// ===== ADMIN REPORT DETAIL PAGE =====
class AdminReportDetailPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const AdminReportDetailPage({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  @override
  State<AdminReportDetailPage> createState() => _AdminReportDetailPageState();
}

class _AdminReportDetailPageState extends State<AdminReportDetailPage> {
  final _notesController = TextEditingController();
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill existing notes
    _notesController.text = widget.reportData['adminNotes'] ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getFormattedDateTime(Timestamp? ts) {
    if (ts == null) return "N/A";
    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(ts.toDate());
  }

  Map<String, dynamic> _getCategoryInfo(String category) {
    const categoryMap = {
      'electrical': {
        'icon': Icons.electrical_services,
        'color': Colors.amber,
        'label': 'Electrical',
      },
      'plumbing': {
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'label': 'Plumbing',
      },
      'air_conditioning': {
        'icon': Icons.ac_unit,
        'color': Colors.cyan,
        'label': 'Air Conditioning',
      },
      'furniture': {
        'icon': Icons.weekend,
        'color': Colors.brown,
        'label': 'Furniture',
      },
      'cleanliness': {
        'icon': Icons.cleaning_services,
        'color': Colors.green,
        'label': 'Cleanliness',
      },
      'security': {
        'icon': Icons.security,
        'color': Colors.red,
        'label': 'Security',
      },
      'structural': {
        'icon': Icons.foundation,
        'color': Colors.grey,
        'label': 'Structural',
      },
      'other': {
        'icon': Icons.more_horiz,
        'color': Colors.purple,
        'label': 'Other',
      },
    };

    return categoryMap[category] ?? categoryMap['other']!;
  }

  Future<void> _markAsOngoing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          'Mark as Ongoing?',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'This will mark the report as ongoing and notify the student that work has begun.',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId)
          .update({
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
        'handledBy': adminUid,
      });

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report marked as ongoing',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsCompleted() async {
    // Require notes for completed status
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add notes before marking as completed',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          'Mark as Completed?',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'This will mark the report as completed and notify the student that the issue has been resolved.',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'adminNotes': _notesController.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report marked as completed',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId)
          .update({
        'adminNotes': _notesController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notes saved successfully',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving notes: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.reportData['issue'] ?? 'Untitled';
    final category = widget.reportData['category'] ?? 'other';
    final location = widget.reportData['location'] ?? 'Unknown';
    final description = widget.reportData['description'] ?? 'No description';
    final studentName = widget.reportData['studentName'] ?? 'Unknown';
    final studentId = widget.reportData['studentId'] ?? 'N/A';
    final status = widget.reportData['status'] ?? 'pending';
    final imageUrl = widget.reportData['imageUrl'] as String?;
    final sentAt = widget.reportData['sentAt'] as Timestamp?;
    final startedAt = widget.reportData['startedAt'] as Timestamp?;
    final completedAt = widget.reportData['completedAt'] as Timestamp?;
    final isUrgent = widget.reportData['isUrgent'] ?? false;

    final categoryInfo = _getCategoryInfo(category);

    // Status config
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'ongoing':
        statusColor = Colors.blue;
        statusText = 'ONGOING';
        statusIcon = Icons.build_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.pending;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Report Details',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category icon and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: categoryInfo['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryInfo['icon'],
                    color: categoryInfo['color'],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue,
                        style: GoogleFonts.firaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1800AD),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoryInfo['label'],
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isUrgent)
                        Row(
                          children: [
                            const Icon(Icons.priority_high, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              'URGENT',
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: GoogleFonts.firaSans(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Student info
            Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$studentName ($studentId)',
                    style: GoogleFonts.firaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Location
            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.firaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Divider
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 5),

            // Description
            Text(
              'Description',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.firaSans(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 5),

            // Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 5),
              Text(
                'Image',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: Image.network(imageUrl),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red, size: 50),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to view full size',
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
            ],

            // Timeline
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 5),
            Text(
              'Timeline',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 12),
            _buildTimelineItem(
              Icons.send,
              'Sent',
              _getFormattedDateTime(sentAt),
              Colors.orange,
            ),
            if (startedAt != null)
              _buildTimelineItem(
                Icons.build_circle,
                'Started',
                _getFormattedDateTime(startedAt),
                Colors.blue,
              ),
            if (completedAt != null)
              _buildTimelineItem(
                Icons.check_circle,
                'Completed',
                _getFormattedDateTime(completedAt),
                Colors.green,
              ),


            // Admin Notes Section (visible for all statuses, editable for non-completed)
            if (status != 'completed') ...[
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 5),
              Text(
                'Admin Notes',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              if (status == 'completed')
                Text(
                  '(Required before completing)',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLength: 500,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Add notes for the student (visible to them)...',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: GoogleFonts.firaSans(fontSize: 16),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _savingNotes ? null : _saveNotes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: _savingNotes
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _savingNotes ? 'Saving...' : 'Save Notes',
                    style: GoogleFonts.dangrek(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Show saved notes for completed reports (read-only)
              if (_notesController.text.isNotEmpty) ...[
                Divider(thickness: 1, color: Colors.grey[300]),
                const SizedBox(height: 5),
                Text(
                  'Admin Notes',
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1800AD),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _notesController.text,
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 5),

            // Action Buttons (hide for completed)
            if (status != 'completed') ...[
              Divider(thickness: 2, color: Colors.grey[300]),
              const SizedBox(height: 5),
              Text(
                'Admin Actions',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 12),

              if (status == 'pending')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _markAsOngoing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.build_circle, color: Colors.white),
                    label: Text(
                      'Mark as Ongoing',
                      style: GoogleFonts.dangrek(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

              if (status == 'ongoing')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _markAsCompleted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      'Mark as Completed',
                      style: GoogleFonts.dangrek(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(IconData icon, String label, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                time,
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
