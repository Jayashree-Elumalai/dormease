import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'connect_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';

class LostFoundPage extends StatefulWidget {
  const LostFoundPage({super.key});

  @override
  State<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends State<LostFoundPage> with SingleTickerProviderStateMixin {
  final int _selectedIndex = 2;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  Stream<QuerySnapshot> _getUnclaimedStream() {
    Query query = FirebaseFirestore.instance
        .collection('lostAndFound')
        .where('status', isEqualTo: 'unclaimed');

    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.orderBy('postedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> _getMyClaimsStream(String status) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('lostAndFound')
        .where('claimedBy', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: status)
        .orderBy('claimedAt', descending: true)
        .snapshots();
  }

  List<DocumentSnapshot> _filterBySearch(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final itemName = (data['itemName'] ?? '').toLowerCase();
      final description = (data['description'] ?? '').toLowerCase();
      return itemName.contains(_searchQuery.toLowerCase()) ||
          description.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.dangrek(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.dangrek(fontSize: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Unclaimed'),
            Tab(text: 'My Claims'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                 TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by item name...',
                      hintStyle: GoogleFonts.firaSans(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                  ),

                const SizedBox(height: 10),

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFF1800AD), width: 2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1800AD)),
                        style: GoogleFonts.firaSans(
                          color: const Color(0xFF1800AD),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
                          ),
                          DropdownMenuItem(
                            value: 'electronics',
                            child: Text('Electronics', style: GoogleFonts.firaSans()),
                          ),
                          DropdownMenuItem(
                            value: 'personal_items',
                            child: Text('Personal Items', style: GoogleFonts.firaSans()),
                          ),
                          DropdownMenuItem(
                            value: 'clothing',
                            child: Text('Clothing', style: GoogleFonts.firaSans()),
                          ),
                          DropdownMenuItem(
                            value: 'books_stationery',
                            child: Text('Books & Stationery', style: GoogleFonts.firaSans()),
                          ),
                          DropdownMenuItem(
                            value: 'id_cards',
                            child: Text('ID/Cards', style: GoogleFonts.firaSans()),
                          ),
                          DropdownMenuItem(
                            value: 'others',
                            child: Text('Others', style: GoogleFonts.firaSans()),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUnclaimedTab(),
                _buildMyClaimsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportFoundItemPage()),
          );
        },
        backgroundColor: const Color(0xFF1800AD),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
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
            _buildNavItem(Icons.home, 'Home', 2, forceGrey: true),
            _buildNavItem(Icons.chat, 'Connect', 3),
            _buildNavItem(Icons.warning, 'SOS', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildUnclaimedTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _getUnclaimedStream(),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              Icons.inbox_outlined,
              'No Unclaimed Items',
              'Items reported will appear here',
            );
          }

          final allItems = snapshot.data!.docs;
          final filteredItems = _filterBySearch(allItems);

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
              return _buildItemCard(doc.id, data, showClaimButton: true);
            },
          );
        },
      ),
    );
  }

  Widget _buildMyClaimsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              indicatorColor: const Color(0xFF1800AD),
              labelColor: const Color(0xFF1800AD),
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.firaSans(fontSize: 14, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Waiting'),
                Tab(text: 'Confirmed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildClaimStatusTab('waiting'),
                _buildClaimStatusTab('confirmed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimStatusTab(String status) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _getMyClaimsStream(status),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              status == 'waiting' ? Icons.pending_actions : Icons.check_circle_outline,
              status == 'waiting' ? 'No Waiting Claims' : 'No Confirmed Claims',
              status == 'waiting'
                  ? 'Items you claim will appear here'
                  : 'Confirmed claims will appear here',
            );
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildItemCard(
                doc.id,
                data,
                showCancelButton: status == 'waiting',
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildItemCard(
      String itemId,
      Map<String, dynamic> data, {
        bool showClaimButton = false,
        bool showCancelButton = false,
      }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final itemName = data['itemName'] ?? 'Untitled';
    final category = data['category'] ?? 'others';
    final location = data['location'] ?? 'Unknown';
    final status = data['status'] ?? 'unclaimed';
    final postedAt = data['postedAt'] as Timestamp?;
    final claimedAt = data['claimedAt'] as Timestamp?;
    final confirmedAt = data['confirmedAt'] as Timestamp?;
    final imageUrl = data['photoUrl'] as String?;
    final postedBy = data['postedBy'] as String?;

    final categoryInfo = _getCategoryInfo(category);
    final isMyItem = postedBy == currentUser?.uid && status == 'unclaimed';

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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailPage(
                  itemId: itemId,
                  itemData: data,
                  showDeleteButton: isMyItem, // ✅ ADDED
                  showCancelButton: showCancelButton,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                )
                    : Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryInfo['color'].withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryInfo['icon'], size: 12, color: categoryInfo['color']),
                              const SizedBox(width: 4),
                              Text(
                                categoryInfo['label'],
                                style: GoogleFonts.firaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: categoryInfo['color'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
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
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 4),
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
                    const SizedBox(height: 8),
                    Text(
                      itemName,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1800AD),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
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
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _getDateLabel(status, postedAt, claimedAt, confirmedAt),
                          style: GoogleFonts.firaSans(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (showClaimButton && !isMyItem)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _claimItem(itemId, itemName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Claim',
                                style: GoogleFonts.firaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        if (showClaimButton && !isMyItem) const SizedBox(width: 8),
                        if (showCancelButton)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cancelClaim(itemId, itemName),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel Claim',
                                style: GoogleFonts.firaSans(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        if (showCancelButton) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailPage(
                                      itemId: itemId,
                                      itemData: data,
                                      showDeleteButton: isMyItem, // ✅ ADDED
                                      showCancelButton: showCancelButton,
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateLabel(String status, Timestamp? posted, Timestamp? claimed, Timestamp? confirmed) {
    switch (status) {
      case 'waiting':
        return 'Claimed: ${_formatDateTime(claimed)}';
      case 'confirmed':
        return 'Confirmed: ${_formatDateTime(confirmed)}';
      default:
        return 'Posted: ${_formatDateTime(posted)}';
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return 'N/A';
    return DateFormat('MMM d, yyyy, h:mm a').format(ts.toDate());
  }

  Future<void> _claimItem(String itemId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Column(
          children: [
            const Icon(Icons.inventory_2, size: 50, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              'Claim this item?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: Text(
          'Make sure you have retrieved "$itemName" from admin before claiming',
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
            child: Text('Confirm Claim', // ✅ FIXED
                style: GoogleFonts.firaSans(fontWeight: FontWeight.bold, color: Colors.green)), // ✅ FIXED
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser; // ✅ ADDED
      if (currentUser == null) return; // ✅ ADDED

      final userDoc = await FirebaseFirestore.instance // ✅ ADDED
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Unknown'; // ✅ ADDED

      await FirebaseFirestore.instance.collection('lostAndFound').doc(itemId).update({ // ✅ CHANGED: delete → update
        'status': 'waiting', // ✅ ADDED
        'claimedBy': currentUser.uid, // ✅ ADDED
        'claimedByName': userName, // ✅ ADDED
        'claimedAt': FieldValue.serverTimestamp(), // ✅ ADDED
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item claimed. Waiting for admin confirmation.', // ✅ FIXED
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

  Future<void> _cancelClaim(String itemId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Column(
          children: [
            const Icon(Icons.cancel_outlined, size: 50, color: Colors.orange),  // ✅ Added icon
            const SizedBox(height: 8),
            Text(
              'Cancel Claim?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'This will move "$itemName" back to unclaimed items',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,  // ✅ Made bold
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.firaSans(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes', style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.red
            )),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('lostAndFound').doc(itemId).update({
        'status': 'unclaimed',
        'claimedBy': null,
        'claimedByName': null,
        'claimedAt': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim cancelled',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
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

  Future<void> _deleteItem(String itemId, String? imageUrl) async {
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

      await FirebaseFirestore.instance.collection('lostAndFound').doc(itemId).delete();

      if (!mounted) return;
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


  Widget _buildEmptyState(IconData icon, String message, String subtitle) {
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
            style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {bool forceGrey = false}) {
    bool isSelected = _selectedIndex == index;
    Color color = (isSelected && !forceGrey) ? const Color(0xFF1800AD) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 70,
        child: Column(
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

// ===== REPORT FOUND ITEM PAGE =====
class ReportFoundItemPage extends StatefulWidget {
  const ReportFoundItemPage({super.key});

  @override
  State<ReportFoundItemPage> createState() => _ReportFoundItemPageState();
}

class _ReportFoundItemPageState extends State<ReportFoundItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _selectedCategory;
  DateTime _dateFound = DateTime.now();
  File? _imageFile;
  bool _loading = false;

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      if (fileSize > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image too large. Maximum 5MB allowed.',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (fileSize > 1024 * 1024) {
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 70,
        );

        if (compressedFile != null) {
          setState(() => _imageFile = File(compressedFile.path));
        }
      } else {
        setState(() => _imageFile = file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFound,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1800AD),
              onPrimary: Colors.white, // Header text color
              onSurface: const Color(0xFF1800AD),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1800AD), // Button text color (OK/CANCEL)
                textStyle: GoogleFonts.firaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // Rounded corners
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateFound = picked);
    }
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add a photo of the item',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('lostAndFound')
          .child('${currentUser.uid}_$timestamp.jpg');

      await ref.putFile(_imageFile!);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('lostAndFound').add({
        'itemName': _itemNameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'category': _selectedCategory ?? 'others',
        'location': _locationCtrl.text.trim(),
        'dateFound': Timestamp.fromDate(_dateFound),
        'photoUrl': imageUrl,
        'status': 'unclaimed',
        'postedBy': currentUser.uid,
        'postedByName': userName,
        'postedAt': FieldValue.serverTimestamp(),
        'claimedBy': null,
        'claimedByName': null,
        'claimedAt': null,
        'confirmedBy': null,
        'confirmedAt': null,
      });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          title: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 12),
              Text(
                'Item Reported!',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'Your found item has been reported successfully',
            style: GoogleFonts.firaSans(fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'OK',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
            ),
          ],
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Report Found Item',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.dangrek(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Photo',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              if (_imageFile == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1800AD), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt, color: Color(0xFF1800AD)),
                        label: Text(
                          'Camera',
                          style: GoogleFonts.firaSans(
                            color: const Color(0xFF1800AD),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1800AD), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library, color: Color(0xFF1800AD)),
                        label: Text(
                          'Gallery',
                          style: GoogleFonts.firaSans(
                            color: const Color(0xFF1800AD),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _imageFile!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() => _imageFile = null),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              Text(
                'Item Name',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              TextFormField(
                controller: _itemNameCtrl,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: 'e.g., iPhone 14 Pro',
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '',
                  errorStyle: GoogleFonts.dangrek(fontSize: 14, color: Colors.red),
                ),
                style: GoogleFonts.firaSans(fontSize: 15),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Enter at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              Text(
                'Category',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: Text('Select category', style: GoogleFonts.firaSans(color: Colors.grey)),
                decoration: InputDecoration(
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
                  errorStyle: GoogleFonts.dangrek(fontSize: 14, color: Colors.red),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'electronics',
                    child: Row(
                      children: [
                        const Icon(Icons.devices, color: Colors.purple, size: 20),
                        const SizedBox(width: 10),
                        Text('Electronics', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'personal_items',
                    child: Row(
                      children: [
                        const Icon(Icons.business_center, color: Colors.blue, size: 20),
                        const SizedBox(width: 10),
                        Text('Personal Items', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'clothing',
                    child: Row(
                      children: [
                        const Icon(Icons.checkroom, color: Colors.pink, size: 20),
                        const SizedBox(width: 10),
                        Text('Clothing', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'books_stationery',
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book, color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Text('Books & Stationery', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'id_cards',
                    child: Row(
                      children: [
                        const Icon(Icons.badge, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Text('ID/Cards', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'others',
                    child: Row(
                      children: [
                        const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                        const SizedBox(width: 10),
                        Text('Others', style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value!),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              Text(
                'Location Found',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              TextFormField(
                controller: _locationCtrl,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'e.g., Block A Lobby',
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: '',
                  errorStyle: GoogleFonts.dangrek(fontSize: 14, color: Colors.red),
                ),
                style: GoogleFonts.firaSans(fontSize: 15),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Location is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Enter at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              Text(
                'Date Found',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1800AD), width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF1800AD), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM d, yyyy').format(_dateFound),
                        style: GoogleFonts.firaSans(fontSize: 15, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Text(
                'Description',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              TextFormField(
                controller: _descriptionCtrl,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the item in detail...',
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  errorStyle: GoogleFonts.dangrek(fontSize: 14, color: Colors.red),
                ),
                style: GoogleFonts.firaSans(fontSize: 15),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Enter at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 5),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    'Submit Report',
                    style: GoogleFonts.dangrek(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== ITEM DETAIL PAGE =====
class ItemDetailPage extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;
  final bool showDeleteButton; // ✅ ADDED
  final bool showCancelButton; // ✅ ADDED

  const ItemDetailPage({
    super.key,
    required this.itemId,
    required this.itemData,
    this.showDeleteButton = false, // ✅ ADDED
    this.showCancelButton = false, // ✅ ADDED
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState(); // ✅ ADDED
}

class _ItemDetailPageState extends State<ItemDetailPage> {

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
        // ✅ ADDED: Actions for delete and cancel
        actions: [if (widget.showCancelButton) // ✅ Cancel claim button - Now with red styling
          Padding(
            padding: const EdgeInsets.only(right: 8), // ✅ ADDED: spacing from edge
            child: ElevatedButton(
              onPressed: () => _cancelClaim(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // ✅ ADDED: Red background
                foregroundColor: Colors.white, // ✅ ADDED: White text
                padding: const EdgeInsets.symmetric(horizontal: 10), // ✅ ADDED: padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // ✅ ADDED: rounded corners
                  side: const BorderSide(color: Colors.white, width: 2), // ✅ ADDED: white border
                ),
                elevation: 3, // ✅ ADDED: shadow for depth
              ),
              child: Row( // ✅ ADDED: Icon + Text for better visibility
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel, size: 18), // ✅ ADDED: icon
                  const SizedBox(width: 6), // ✅ ADDED: spacing
                  Text(
                    'Cancel Claim',
                    style: GoogleFonts.dangrek(
                      fontSize: 15, // ✅ CHANGED: 16→14 to fit better
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showDeleteButton) // ✅ ADDED: Delete button
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

      Navigator.pop(context); // Go back to previous page

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

  Future<void> _cancelClaim(BuildContext context) async {
    final itemName = widget.itemData['itemName'] ?? 'this item';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Column(
          children: [
            const Icon(Icons.cancel_outlined, size: 50, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Cancel Claim?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'This will move "$itemName" back to unclaimed items',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.firaSans(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes', style: GoogleFonts.firaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.red
            )),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('lostAndFound').doc(widget.itemId).update({
        'status': 'unclaimed',
        'claimedBy': null,
        'claimedByName': null,
        'claimedAt': null,
      });

      if (!mounted) return;

      Navigator.pop(context); // Go back to previous page

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim cancelled',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
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
}
