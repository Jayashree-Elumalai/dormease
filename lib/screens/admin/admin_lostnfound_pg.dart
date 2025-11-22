import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'admin_annnouncements_pg.dart';
import 'admin_report_pg.dart';
import 'admin_parcel_pg.dart';
import 'admin_sos_pg.dart';
import '../../services/auth_service.dart';

class AdminLostnfoundPg extends StatefulWidget {
  const AdminLostnfoundPg({super.key});

  @override
  State<AdminLostnfoundPg> createState() => _AdminLostnfoundPgState();
}

// SingleTickerProviderStateMixin enables TabController animations
class _AdminLostnfoundPgState extends State<AdminLostnfoundPg> with SingleTickerProviderStateMixin {
  int _selectedIndex = 3; // Lost/Found is index 3

  // TabController - Manages main tabs (All + Status)
  late TabController _mainTabController;

  // Search and filter state
  String _searchQuery = ''; // Search text
  String _selectedCategory = 'all'; // Category filter

  @override
  void initState() {
    super.initState();
    // Initialize TabController with 2 tabs
    // vsync: this - Links animation to widget lifecycle (prevents memory leaks)
    _mainTabController = TabController(length: 2, vsync: this); // All + Status
  }

  @override
  void dispose() {
    // Clean up: Dispose TabController to prevent memory leaks
    _mainTabController.dispose();
    super.dispose();
  }
  // Navigate between admin pages
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

  // Get stream for "All" tab
  //  INDEX if category filter used
  Stream<QuerySnapshot> _getAllItemsStream() {
    Query query = FirebaseFirestore.instance
        .collection('lostAndFound')
        .orderBy('postedAt', descending: true);

    // Apply category filter if not "all"
    if (_selectedCategory != 'all') {//index
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    return query.snapshots();
  }

  // Get stream filtered by status
  // INDEX if category filter used
  Stream<QuerySnapshot> _getStatusItemsStream(String status) {
    Query query = FirebaseFirestore.instance
        .collection('lostAndFound')
        .where('status', isEqualTo: status);

    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Sort: Waiting first (needs action), then by date
    return query.orderBy('postedAt', descending: true).snapshots();
  }

  // Filter by search query
  List<DocumentSnapshot> _filterBySearch(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final itemName = (data['itemName'] ?? '').toLowerCase();
      final postedByName = (data['postedByName'] ?? '').toLowerCase();
      final claimedByName = (data['claimedByName'] ?? '').toLowerCase();
      // Check if any field contains search query
      return itemName.contains(_searchQuery.toLowerCase()) ||
          postedByName.contains(_searchQuery.toLowerCase()) ||
          claimedByName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Get statistics for badges.Stream that calculates badge counts
  Stream<Map<String, int>> _getStatistics() {
    return FirebaseFirestore.instance
        .collection('lostAndFound')
        .snapshots()
        .map((snapshot) {
      // Count items by status
      int unclaimed = 0;
      int waiting = 0;
      int confirmed = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] ?? 'unclaimed';
        if (status == 'unclaimed') unclaimed++;
        if (status == 'waiting') waiting++;
        if (status == 'confirmed') confirmed++;
      }

      return {
        'unclaimed': unclaimed,
        'waiting': waiting,
        'confirmed': confirmed,
      };
    });
  }

  // Get active items count for bottom nav badge (waiting only)
  Stream<int> _getActiveItemsCount() {
    return FirebaseFirestore.instance
        .collection('lostAndFound')
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  // Format timestamp
  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('MMM d, yyyy').format(ts.toDate());
  }

  @override
  //ADMIN LOST N FOUND UI
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: Text(
          'Lost & Found',
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
        //TabBar in AppBar
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.dangrek(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.dangrek(fontSize: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Status'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Cards
          StreamBuilder<Map<String, int>>(
            stream: _getStatistics(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {
                'unclaimed': 0,
                'waiting': 0,
                'confirmed': 0,
              };
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    // Unclaimed count
                    Expanded(
                      child: _buildStatCard(
                        'Unclaimed',
                        stats['unclaimed']!,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Waiting count
                    Expanded(
                      child: _buildStatCard(
                        'Waiting',
                        stats['waiting']!,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirmed count
                    Expanded(
                      child: _buildStatCard(
                        'Confirmed',
                        stats['confirmed']!,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search Bar + Category Filter
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by item or student name...',
                    hintStyle: GoogleFonts.firaSans(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    isDense: true,
                  ),
                  style: GoogleFonts.firaSans(color: const Color(0xFF1800AD)),
                ),
                const SizedBox(height: 10),

                // Category Dropdown filter
                Row(
                  children: [
                    Text(
                      'Category: ',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1800AD),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF1800AD), width: 2),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          underline: const SizedBox(),
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1800AD)),
                          style: GoogleFonts.firaSans(
                            color: const Color(0xFF1800AD),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          items: [
                            // All categories option
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
                            ),
                            // Electronics
                            DropdownMenuItem(
                              value: 'electronics',
                              child: Row(
                                children: [
                                  const Icon(Icons.devices, color: Colors.purple, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Electronics', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                            // Personal Items
                            DropdownMenuItem(
                              value: 'personal_items',
                              child: Row(
                                children: [
                                  const Icon(Icons.business_center, color: Colors.blue, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Personal Items', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                            //clothing
                            DropdownMenuItem(
                              value: 'clothing',
                              child: Row(
                                children: [
                                  const Icon(Icons.checkroom, color: Colors.pink, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Clothing', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                            // Books & Stationery
                            DropdownMenuItem(
                              value: 'books_stationery',
                              child: Row(
                                children: [
                                  const Icon(Icons.menu_book, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Books & Stationery', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                            // ID/Cards
                            DropdownMenuItem(
                              value: 'id_cards',
                              child: Row(
                                children: [
                                  const Icon(Icons.badge, color: Colors.orange, size: 16),
                                  const SizedBox(width: 8),
                                  Text('ID/Cards', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                            //Others
                            DropdownMenuItem(
                              value: 'others',
                              child: Row(
                                children: [
                                  const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Others', style: GoogleFonts.firaSans()),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value!);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                _buildAllTab(),
                _buildStatusTab(),//Status-filtered items
              ],
            ),
          ),
        ],
      ),
      //bottom nav bar with badge (waiting)
      bottomNavigationBar: StreamBuilder<int>(
        stream: _getActiveItemsCount(),
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
                _buildNavItem(Icons.report, 'Reports', 0),
                _buildNavItem(Icons.inventory, 'Parcel', 1),
                _buildNavItem(Icons.warning, 'SOS', 2),
                // Lost/Found with badge counts
                _buildNavItem(Icons.search, 'Lost/Found', 3, badgeCount: badgeCount),
                _buildNavItem(Icons.announcement, 'Announce', 4),
              ],
            ),
          );
        },
      ),
    );
  }
  // HELPER: Build statistics card
  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        // Count number
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
            // Label
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
  // BUILD: "All" tab content
  Widget _buildAllTab() {
    return RefreshIndicator(// Pull down to refresh
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {}); // Refresh UI
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _getAllItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading items',
                style: GoogleFonts.firaSans(color: Colors.red),
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              Icons.inbox_outlined,
              'No Items',
              'No items have been reported yet',
            );
          }

          final allItems = snapshot.data!.docs;
          // Apply search filter
          final filteredItems = _filterBySearch(allItems);

          if (filteredItems.isEmpty) {
            return _buildEmptyState(
              Icons.search_off,
              'No Results',
              'Try different keywords or category',
            );
          }
          // Build list of items
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final doc = filteredItems[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildItemCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // BUILD: Status tab content (with nested tabs)
  Widget _buildStatusTab() {
    return DefaultTabController(//Nested tabs (Unclaimed, Waiting, Confirmed)
      length: 3,// 3 status tabs
      child: Column(
        children: [
          // Sub-tab bar
          Container(
            color: Colors.grey[100],
            child: TabBar(
              indicatorColor: const Color(0xFF1800AD),
              labelColor: const Color(0xFF1800AD),
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.firaSans(fontSize: 14, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Unclaimed'),
                Tab(text: 'Waiting'),
                Tab(text: 'Confirmed'),
              ],
            ),
          ),
          // Sub-tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildStatusItemsList('unclaimed'),
                _buildStatusItemsList('waiting'),
                _buildStatusItemsList('confirmed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BUILD: Status-filtered list
  Widget _buildStatusItemsList(String status) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _getStatusItemsStream(status),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            String message;
            String subtitle;
            IconData icon;

            switch (status) {
              case 'waiting':
                icon = Icons.pending_actions;
                message = 'No Waiting Claims';
                subtitle = 'Claims needing confirmation will appear here';
                break;
              case 'confirmed':
                icon = Icons.check_circle_outline;
                message = 'No Confirmed Claims';
                subtitle = 'Verified claims will appear here';
                break;
              default:
                icon = Icons.inbox_outlined;
                message = 'No Unclaimed Items';
                subtitle = 'Reported items will appear here';
            }

            return _buildEmptyState(icon, message, subtitle);
          }

          final items = snapshot.data!.docs;
          final filteredItems = _filterBySearch(items);

          if (filteredItems.isEmpty) {
            return _buildEmptyState(
              Icons.search_off,
              'No Results',
              'Try different keywords or category',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final doc = filteredItems[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildItemCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  // BUILD: Item card with image thumbnail
  Widget _buildItemCard(String itemId, Map<String, dynamic> data) {
    final itemName = data['itemName'] ?? 'Untitled';
    final category = data['category'] ?? 'others';
    final location = data['location'] ?? 'Unknown';
    final status = data['status'] ?? 'unclaimed';
    final imageUrl = data['photoUrl'] as String?;// Image URL from Firebase Storage
    final postedByName = data['postedByName'] ?? 'Unknown';
    final postedBy = data['postedBy'] as String?;
    final claimedByName = data['claimedByName'] as String?;
    final claimedBy = data['claimedBy'] as String?;
    final postedAt = data['postedAt'] as Timestamp?;
    final claimedAt = data['claimedAt'] as Timestamp?;

    final categoryInfo = _getCategoryInfo(category);
    // Status badge appearance
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusText = 'WAITING';
        statusIcon = Icons.pending;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'CONFIRMED';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'UNCLAIMED';
        statusIcon = Icons.inventory_2;
    }

    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(// Makes entire card tappable with ripple effect
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminItemDetailPage(
                  itemId: itemId,
                  itemData: data,
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
            Row(
            children: [
            // Image thumbnail- Image loading from Firebase Storage
            ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              //Error handling for broken images
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                );
              },
            )
                : Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.grey, size: 30),
            ),
          ),
          const SizedBox(width: 12),
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryInfo['color'].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryInfo['icon'], size: 10, color: categoryInfo['color']),
                          const SizedBox(width: 3),
                          Text(
                            categoryInfo['label'],
                            style: GoogleFonts.firaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: categoryInfo['color'],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusColor),
                          const SizedBox(width: 3),
                          Text(
                            statusText,
                            style: GoogleFonts.firaSans(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  itemName,
                  style: GoogleFonts.firaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1800AD),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
        const SizedBox(height: 10),

        // Posted by info
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(postedBy)
              .get(),
          builder: (context, snapshot) {
            String postedById = 'N/A';
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              postedById = userData['studentId'] ?? 'N/A';
            }
            return Row(
              children: [
                Icon(Icons.person_outline, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Posted by: ',
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Expanded(
                  child: Text(
                    '$postedByName ($postedById)',
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),

        if (claimedByName != null) ...[
          const SizedBox(height: 4),
          // Claimed by info
          FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(claimedBy)
              .get(),
          builder: (context, snapshot) {
            String claimedById = 'N/A';
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              claimedById = userData['studentId'] ?? 'N/A';
            }
            return Row(
              children: [
                Icon(Icons.check_circle_outline, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Claimed by: ',
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Expanded(
                  child: Text(
                    '$claimedByName ($claimedById)',
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
          ),
        ],

        const SizedBox(height: 8),
        // Dates
        Row(
          children: [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Posted: ${_formatDateTime(postedAt)}',
              style: GoogleFonts.firaSans(
              fontSize: 11,
              color: Colors.grey[700],
              ),
            ),
            if (claimedAt != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Claimed: ${_formatDateTime(claimedAt)}',
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 10),
        // Action buttons
        Row(
          children: [
            if (status == 'waiting')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmClaim(itemId, itemName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check_circle, size: 14, color: Colors.white),
                label: Text(
                  'Confirm',
                  style: GoogleFonts.firaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (status == 'waiting') const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminItemDetailPage(
                        itemId: itemId,
                        itemData: data,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38B6FF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.firaSans(
                    color: const Color(0xFF38B6FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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

  // Confirm claim function
  Future<void> _confirmClaim(String itemId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Column(
          children: [
            const Icon(Icons.check_circle, size: 50, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              'Confirm Claim?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: Text(
          'This will mark "$itemName" as confirmed and notify the student',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('lostAndFound').doc(itemId).update({
        'status': 'confirmed',
        'confirmedBy': FirebaseAuth.instance.currentUser?.uid,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim confirmed successfully',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyState(IconData icon, String message, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[400]),
          //const SizedBox(height: 10),
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
            style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
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
            if (badgeCount > 0)
              Positioned(
                right: 12,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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

  Map<String, dynamic> _getCategoryInfo(String category) {
    const categoryMap = {
      'electronics': {
        'icon': Icons.devices,
        'color': Colors.purple,
        'label': 'Electronics',
      },
      'personal_items': {
        'icon': Icons.business_center,
        'color': Colors.blue,
        'label': 'Personal Items',
      },
      'clothing': {
        'icon': Icons.checkroom,
        'color': Colors.pink,
        'label': 'Clothing',
      },
      'books_stationery': {
        'icon': Icons.menu_book,
        'color': Colors.green,
        'label': 'Books',
      },
      'id_cards': {
        'icon': Icons.badge,
        'color': Colors.orange,
        'label': 'ID/Cards',
      },
      'others': {
        'icon': Icons.more_horiz,
        'color': Colors.grey,
        'label': 'Others',
      },
    };

    return categoryMap[category] ?? categoryMap['others']!;
  }
}

//ADMIN ITEM DETAIL PAGE
class AdminItemDetailPage extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const AdminItemDetailPage({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<AdminItemDetailPage> createState() => _AdminItemDetailPageState();
}

class _AdminItemDetailPageState extends State<AdminItemDetailPage> {
  String _getFormattedDateTime(Timestamp? ts) {
    if (ts == null) return "N/A";
    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(ts.toDate());
  }

  Map<String, dynamic> _getCategoryInfo(String category) {
    const categoryMap = {
      'electronics': {
        'icon': Icons.devices,
        'color': Colors.purple,
        'label': 'Electronics',
      },
      'personal_items': {
        'icon': Icons.business_center,
        'color': Colors.blue,
        'label': 'Personal Items',
      },
      'clothing': {
        'icon': Icons.checkroom,
        'color': Colors.pink,
        'label': 'Clothing',
      },
      'books_stationery': {
        'icon': Icons.menu_book,
        'color': Colors.green,
        'label': 'Books & Stationery',
      },
      'id_cards': {
        'icon': Icons.badge,
        'color': Colors.orange,
        'label': 'ID/Cards',
      },
      'others': {
        'icon': Icons.more_horiz,
        'color': Colors.grey,
        'label': 'Others',
      },
    };

    return categoryMap[category] ?? categoryMap['others']!;
  }

  // Confirm claim in detail page
  Future<void> _confirmClaim(BuildContext context) async {
    final itemName = widget.itemData['itemName'] ?? 'this item';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Column(
          children: [
            const Icon(Icons.check_circle, size: 50, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              'Confirm Claim?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: Text(
          'This will mark "$itemName" as confirmed and notify the student',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('lostAndFound').doc(widget.itemId).update({
        'status': 'confirmed',
        'confirmedBy': FirebaseAuth.instance.currentUser?.uid,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context); // Go back to list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim confirmed successfully',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete unclaimed item
  Future<void> _deleteItem(BuildContext context) async {
    final imageUrl = widget.itemData['photoUrl'] as String?;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        title: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Delete Item?',
              style: GoogleFonts.firaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone',
          style: GoogleFonts.firaSans(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Ignore if image already deleted
        }
      }
      await FirebaseFirestore.instance.collection('lostAndFound').doc(widget.itemId).delete();

      if (!mounted) return;

      Navigator.pop(context); // Go back to list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item deleted successfully',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.itemData['itemName'] ?? 'Untitled';
    final category = widget.itemData['category'] ?? 'others';
    final location = widget.itemData['location'] ?? 'Unknown';
    final description = widget.itemData['description'] ?? 'No description';
    final status = widget.itemData['status'] ?? 'unclaimed';
    final photoUrl = widget.itemData['photoUrl'] as String?;
    final dateFound = widget.itemData['dateFound'] as Timestamp?;
    final postedAt = widget.itemData['postedAt'] as Timestamp?;
    final claimedAt = widget.itemData['claimedAt'] as Timestamp?;
    final confirmedAt = widget.itemData['confirmedAt'] as Timestamp?;
    final postedBy = widget.itemData['postedBy'] as String?;
    final claimedBy = widget.itemData['claimedBy'] as String?;
    final postedByName = widget.itemData['postedByName'] ?? 'Unknown';
    final claimedByName = widget.itemData['claimedByName'];

    final categoryInfo = _getCategoryInfo(category);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'waiting':
        statusColor = Colors.orange;
        statusText = 'WAITING';
        statusIcon = Icons.pending;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'CONFIRMED';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'UNCLAIMED';
        statusIcon = Icons.inventory_2;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Item Details',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Confirm button for waiting items
          if (status == 'waiting')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () => _confirmClaim(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Confirm',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Delete button for unclaimed items only
          if (status == 'unclaimed')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _deleteItem(context),
              tooltip: 'Delete Item',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if (photoUrl != null && photoUrl.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: Image.network(photoUrl),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photoUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 250,
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
                        height: 250,
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
              const SizedBox(height: 20),
            ],

            // Item header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryInfo['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    categoryInfo['icon'],
                    color: categoryInfo['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: GoogleFonts.firaSans(
                          fontSize: 18,
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
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: statusColor, width: 2),
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

            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 5),

            // Posted by info with student ID
            Text(
              'Posted By',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(postedBy).get(),
              builder: (context, snapshot) {
                String studentId = 'N/A';
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  studentId = userData['studentId'] ?? 'N/A';
                }
                return Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$postedByName ($studentId)',
                        style: GoogleFonts.firaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Claimed by info (if applicable)
            if (claimedByName != null) ...[
              const SizedBox(height: 10),
              Text(
                'Claimed By',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(claimedBy).get(),
                builder: (context, snapshot) {
                  String studentId = 'N/A';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    studentId = userData['studentId'] ?? 'N/A';
                  }
                  return Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$claimedByName ($studentId)',
                          style: GoogleFonts.firaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 5),

            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 5),

            // Timeline
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
              Icons.calendar_today,
              'Date Found',
              _getFormattedDateTime(dateFound),
              Colors.blue,
            ),
            _buildTimelineItem(
              Icons.upload,
              'Posted',
              _getFormattedDateTime(postedAt),
              Colors.blue,
            ),
            if (claimedAt != null)
              _buildTimelineItem(
                Icons.pending,
                'Claimed',
                _getFormattedDateTime(claimedAt),
                Colors.orange,
              ),
            if (confirmedAt != null)
              _buildTimelineItem(
                Icons.check_circle,
                'Confirmed',
                _getFormattedDateTime(confirmedAt),
                Colors.green,
              ),
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
