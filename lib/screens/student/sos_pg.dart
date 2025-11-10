import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'connect_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> with SingleTickerProviderStateMixin {
  final int _selectedIndex = 4;
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = true;
  bool _hasActiveAlert = false;
  String? _activeAlertId;
  late AnimationController _pulseController;
  String _studentDefaultRoom = '';

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _checkActiveAlert();

    // Pulse animation for SOS button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Load default location from user profile
  Future<void> _loadUserLocation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final block = userData?['block'] ?? userData?['dormBlock'] ?? '';
        final room = userData?['room'] ?? userData?['dormRoom'] ?? '';
        final defaultRoom = block.isNotEmpty && room.isNotEmpty
            ? 'Block $block, Room $room'
            : 'Dorm A, Room 302';
        setState(() {
          _studentDefaultRoom = defaultRoom; // ✅ CHANGED: Store separately
          _locationController.text = defaultRoom;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _studentDefaultRoom = 'Dorm A, Room 302';
        _locationController.text = 'Dorm A, Room 302';
        _isLoading = false;
      });
    }
  }

  // Check if user has an active alert
  Future<void> _checkActiveAlert() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final activeAlerts = await FirebaseFirestore.instance
          .collection('sosAlerts')
          .where('studentUid', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['active', 'acknowledged'])
          .limit(1)
          .get();

      if (activeAlerts.docs.isNotEmpty) {
        setState(() {
          _hasActiveAlert = true;
          _activeAlertId = activeAlerts.docs.first.id;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

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

  // Send SOS Alert
  Future<void> _sendSosAlert() async {
    // Validation
    if (_locationController.text
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your location',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.only(
                top: 20, left: 20, right: 20, bottom: 10),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.only(
                left: 12, right: 12, bottom: 12),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.warning_amber_rounded, size: 50, color: Colors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  'Send SOS Alert?',
                  style: GoogleFonts.firaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Text(
              'This will immediately notify all admins of your emergency',
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
                child: Text(
                  'Cancel',
                  style: GoogleFonts.firaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Send Alert',
                  style: GoogleFonts.firaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      // Get user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final studentName = userData?['name'] ?? 'Unknown';
      final studentId = userData?['studentId'] ?? 'N/A';

      // Create SOS alert
      final alertRef = await FirebaseFirestore.instance
          .collection('sosAlerts')
          .add({
        'studentUid': currentUser.uid,
        'studentName': studentName,
        'studentId': studentId,
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'acknowledgedAt': null,
        'acknowledgedBy': null,
        'resolvedAt': null,
        'resolvedBy': null,
        'adminNotes': null,
      });

      if (!mounted) return;

      // Navigate to status page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SosStatusPage(alertId: alertRef.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasActiveAlert) {
      // If user has active alert, redirect to status page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SosStatusPage(alertId: _activeAlertId!),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
        ),
        title: Text(
          'SOS Emergency',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView( // ✅ CHANGED: SingleChildScrollView → Column (no scrolling)
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Text(
                    'SOS EMERGENCY ALERT',
                    style: GoogleFonts.firaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ONLY USE IN REAL EMERGENCIES',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            //const SizedBox(height: 5),
            // ✅ Emergency Type Buttons (Horizontal Row)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCategoryButtonCompact(
                    icon: '🔥',
                    label: 'Fire',
                    value: 'fire',
                    color: Colors.red[600]!,
                  ),
                  _buildCategoryButtonCompact(
                    icon: '🏥',
                    label: 'Medical',
                    value: 'medical',
                    color: Colors.blue[600]!,
                  ),
                  _buildCategoryButtonCompact(
                    icon: '⚠️',
                    label: 'Safety',
                    value: 'safety',
                    color: Colors.orange[600]!,
                  ),
                  _buildCategoryButtonCompact(
                    icon: '❓',
                    label: 'Others',
                    value: 'others',
                    color: Colors.grey[600]!,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Center SOS Button (Larger, no surrounding buttons)
            GestureDetector(
              onTap: _sendSosAlert,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(
                              0.5 * _pulseController.value),
                          blurRadius: 30 * _pulseController.value,
                          spreadRadius: 15 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_active, color: Colors
                            .white, size: 56), // ✅ INCREASED: 50→56
                        const SizedBox(height: 8),
                        Text(
                          'SOS',
                          style: GoogleFonts.firaSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Location Dropdown with Custom Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Dropdown for quick selection
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: null,
                        // Always null so it shows hint
                        isExpanded: true,
                        isDense: true,
                        hint: Row(
                          children: [
                            const Icon(
                                Icons.location_on, color: Color(0xFF1800AD),
                                size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Quick select location',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(
                            0xFF1800AD)),
                        items: [
                          // ✅ FIXED: Always show student's actual room, not current selected location
                          if (_studentDefaultRoom.isNotEmpty)
                            DropdownMenuItem(
                              value: _studentDefaultRoom,
                              // ✅ CHANGED: Use stored default room
                              child: Text(
                                '🏠 My Room: $_studentDefaultRoom',
                                // ✅ CHANGED: Always show actual room
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1800AD),
                                ),
                              ),
                            ),
                          // ✅ Common locations
                          DropdownMenuItem(
                            value: 'Lobby',
                            child: Text('🏢 Lobby',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'Cafeteria',
                            child: Text('🍽️ Cafeteria',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'Study Room',
                            child: Text('📚 Study Room',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'Laundry Room',
                            child: Text('🧺 Laundry Room',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'Parking Lot',
                            child: Text('🚗 Parking Lot',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'Common Area',
                            child: Text('👥 Common Area',
                                style: GoogleFonts.firaSans(fontSize: 14)),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _locationController.text =
                                  value; // ✅ Update text field
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ✅ FIXED: Custom text input with proper padding
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    // ✅ CHANGED: 8→12 for more space
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row( // ✅ CHANGED: Wrap in Row to control icon positioning
                      children: [
                        const Icon(
                            Icons.edit, color: Color(0xFF1800AD), size: 18),
                        const SizedBox(width: 12),
                        // ✅ ADDED: Space between icon and text
                        Expanded( // ✅ ADDED: Constrain text field width
                          child: TextField(
                            controller: _locationController,
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Or type custom location',
                              hintStyle: GoogleFonts.firaSans(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.all(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ✅ Optional Description (Compact, Reduced height)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12), // ✅ REDUCED: 14→12
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  // ✅ REDUCED: 4→3
                  maxLength: 100,
                  // ✅ REDUCED: 200→150
                  style: GoogleFonts.firaSans(
                    fontSize: 13, // ✅ REDUCED: 14→13
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Additional details (optional)',
                    hintStyle: GoogleFonts.firaSans(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    counterStyle: GoogleFonts.firaSans(fontSize: 10),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 10, horizontal: 15),
                  ),
                ),
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

  Widget _buildCategoryButtonCompact({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        width: 75, // ✅ REDUCED: 85→75 to fit row
        height: 75,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            // ✅ REDUCED: 28→24
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.firaSans(
                fontSize: 11, // ✅ REDUCED: 12→11
                fontWeight: FontWeight.w900,
                color: isSelected ? color : Colors.black,
              ),
            ),
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
              style: GoogleFonts.firaSans(
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
}

// ============================================================
// SOS STATUS PAGE
// ============================================================

class SosStatusPage extends StatefulWidget {
  final String alertId;
  const SosStatusPage({super.key, required this.alertId});

  @override
  State<SosStatusPage> createState() => _SosStatusPageState();
}

class _SosStatusPageState extends State<SosStatusPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
        title: Text(
          'SOS Alert Status',
          style: GoogleFonts.dangrek(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sosAlerts')
            .doc(widget.alertId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Alert not found',
                style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          final location = data['location'] as String;
          final category = data['category'] as String?;
          final description = data['description'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;
          final acknowledgedAt = data['acknowledgedAt'] as Timestamp?;
          final resolvedAt = data['resolvedAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status), width: 2),
                  ),
                  child: Column(
                    children: [
                      Icon(_getStatusIcon(status), size: 60, color: _getStatusColor(status)),
                      const SizedBox(height: 10),
                      Text(
                        _getStatusText(status),
                        style: GoogleFonts.firaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _getStatusColor(status),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getStatusDescription(status),
                        style: GoogleFonts.firaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Alert Details
                _buildDetailCard('Location', location, Icons.location_on),
                if (category != null) _buildDetailCard('Category', _formatCategory(category), Icons.category),
                if (description != null) _buildDetailCard('Description', description, Icons.description),
                if (createdAt != null)
                  _buildDetailCard(
                    'Alert Sent',
                    DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt.toDate()),
                    Icons.access_time,
                  ),
                if (acknowledgedAt != null)
                  _buildDetailCard(
                    'Acknowledged',
                    DateFormat('MMM dd, yyyy - hh:mm a').format(acknowledgedAt.toDate()),
                    Icons.check_circle,
                  ),
                if (resolvedAt != null)
                  _buildDetailCard(
                    'Resolved',
                    DateFormat('MMM dd, yyyy - hh:mm a').format(resolvedAt.toDate()),
                    Icons.done_all,
                  ),

                const SizedBox(height: 20),

                // Cancel Button (only if active)
                if (status == 'active')
                  ElevatedButton(
                    onPressed: () => _cancelAlert(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      'Cancel Alert',
                      style: GoogleFonts.dangrek(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1800AD), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.firaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        return 'ALERT ACTIVE';
      case 'acknowledged':
        return 'HELP ON THE WAY';
      case 'resolved':
        return 'RESOLVED';
      default:
        return 'UNKNOWN';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'active':
        return 'Admin team has been notified and will respond shortly';
      case 'acknowledged':
        return 'An admin has acknowledged your alert and is on the way';
      case 'resolved':
        return 'Your emergency has been resolved';
      default:
        return '';
    }
  }

  String _formatCategory(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }

  Future<void> _cancelAlert(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Column(
          children: [
            const Icon(Icons.cancel_outlined, size: 50, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Cancel Alert?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'This will stop your active SOS alert',
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
            child: Text(
              'No',
              style: GoogleFonts.firaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes, Cancel Alert',
              style: GoogleFonts.firaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ CHANGED: Delete the alert instead of marking as resolved
      await FirebaseFirestore.instance
          .collection('sosAlerts')
          .doc(widget.alertId)
          .delete();

      if (!context.mounted) return;

      // ✅ Navigate back to home after deletion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert cancelled', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.firaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
