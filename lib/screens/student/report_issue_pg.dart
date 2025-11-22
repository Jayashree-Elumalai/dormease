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

import 'home_pg.dart';
import 'connect_pg.dart';
import 'parcel_pg.dart';
import 'sos_pg.dart';
import '/services/auth_service.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  int _selectedIndex = 0;
  String reportFilter = 'all'; // 'all', 'pending', 'ongoing', 'completed'

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

  // Get stream based on filter
  Stream<QuerySnapshot> _getReportStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('reports')
        .where('studentUid', isEqualTo: currentUser.uid);

    if (reportFilter != 'all') {
      query = query.where('status', isEqualTo: reportFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  // Get active report count for badge (pending + ongoing)
  Stream<int> _getActiveReportCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('reports')
        .where('studentUid', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['pending', 'ongoing'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }


  // Relative time formatter
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
              onPressed: () => AuthService.logout(context),
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
              // Filter tabs
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

              // Report list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  key: ValueKey(reportFilter),
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

                    final reports = snapshot.data!.docs;

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

      // FAB - Add Report
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReportPage()),
          );
        },
        backgroundColor: const Color(0xFF1800AD),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),

      // Bottom Navigation with Badge
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
                _buildNavItem(Icons.report, 'Report', 0, badgeCount: badgeCount),
                _buildNavItem(Icons.inventory, 'Parcel', 1),
                _buildNavItem(Icons.home, 'Home', 2),
                _buildNavItem(Icons.chat, 'Connect', 3),
                _buildNavItem(Icons.warning, 'SOS', 4),
              ],
            ),
          );
        },
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
        subtitle = "Tap the + button to report issue!";
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
    final status = data['status'] ?? 'pending';
    final sentAt = data['sentAt'] as Timestamp?;
    final imageUrl = data['imageUrl'] as String?;

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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailPage(reportId: reportId, reportData: data),
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
                    child: Text(
                      issue,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1800AD),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              // Time
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
                  // Image indicator
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Icon(Icons.image, size: 16, color: Colors.grey[500]),
                ],
              ),
              const SizedBox(height: 10),
              // View details button
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View Details →',
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: const Color(0xFF38B6FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    bool isSelected = _selectedIndex == index;
    Color color = isSelected ? const Color(0xFF1800AD) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 70, // Fixed width to prevent overflow
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
                    color: Colors.red, // Navy blue badge
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
}

// ===== ADD REPORT PAGE =====
class AddReportPage extends StatefulWidget {
  const AddReportPage({super.key});

  @override
  State<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends State<AddReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _issueCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _selectedCategory;
  File? _imageFile;
  bool _loading = false;

  @override
  void dispose() {
    _issueCtrl.dispose();
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

      // Check if file is > 5MB
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
      // Compress if > 1MB
      if (fileSize > 1024 * 1024) {
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 70,
        );
        if (compressedFile != null) {
          setState(() {
            _imageFile = File(compressedFile.path);
          });
        }
      } else {
        setState(() {
          _imageFile = file;
        });
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

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      // Get student info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final studentId = userData?['studentId'] ?? 'Unknown';
      final studentName = userData?['name'] ?? 'Unknown';

      String? imageUrl;

      // Upload image if exists
      if (_imageFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance
            .ref()
            .child('reports')
            .child('${currentUser.uid}_$timestamp.jpg');

        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // Create report document
      await FirebaseFirestore.instance.collection('reports').add({
        'studentUid': currentUser.uid,
        'studentId': studentId,
        'studentName': studentName,
        'issue': _issueCtrl.text.trim(),
        'category': _selectedCategory ?? 'other',
        'location': _locationCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'imageUrl': imageUrl,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'adminNotes': null,
        'handledBy': null,
      });

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 13, vertical: 5),
          title: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 12),

              Text(
                'Report Submitted!',
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
            'Your report has been submitted successfully. Admin will review it soon',
            style: GoogleFonts.firaSans(fontSize: 14,fontWeight: FontWeight.bold,),
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 0),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to report list
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
          content: Text(
            'Error: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
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
            'New Report',
            style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.dangrek(
                  color: Colors.white,
                  fontSize: 16,
                ),
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
                // Issue Title
                Text(
                'Issue Title',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 3),
              TextFormField(
                controller: _issueCtrl,
                maxLength: 50,
                decoration: InputDecoration(
                    hintText: 'e.g., Broken window',
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

                  // make validation message larger & clearer
                  errorStyle: GoogleFonts.dangrek(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),

              style: GoogleFonts.firaSans(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Issue title is required';
                }
                if (value.trim().length < 5) {
                  return 'Enter at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Category
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
              hint: Text(
                'Select category',
                style: GoogleFonts.firaSans(color: Colors.grey),
              ),
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
                errorStyle: GoogleFonts.dangrek( // 👈 add it here
                  fontSize: 14,
                  color: Colors.red,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items:  [
                DropdownMenuItem(
                  value: 'electrical',
                  child: Row(
                    children: [
                      Icon(Icons.electrical_services, color: Colors.amber, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Electrical',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'plumbing',
                  child: Row(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text('Plumbing',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'air_conditioning',
                  child: Row(
                    children: [
                      Icon(Icons.ac_unit, color: Colors.cyan, size: 20),
                      SizedBox(width: 10),
                      Text('Air Conditioning',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'furniture',
                  child: Row(
                    children: [
                      Icon(Icons.weekend, color: Colors.brown, size: 20),
                      SizedBox(width: 10),
                      Text('Furniture',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'cleanliness',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.green, size: 20),
                      SizedBox(width: 10),
                      Text('Cleanliness',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'security',
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Security',
                          style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'structural',
                  child: Row(
                    children: [
                      Icon(Icons.foundation, color: Colors.grey, size: 20),
                      SizedBox(width: 10),
                      Text('Structural',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Row(
                    children: [
                      Icon(Icons.more_horiz, color: Colors.purple, size: 20),
                      SizedBox(width: 10),
                      Text('Other',
                        style: GoogleFonts.firaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },

              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Location
            Text(
              'Location',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 3),
            TextFormField(
              controller: _locationCtrl,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'e.g., Block A, Room 101',
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

                // make validation message larger & clearer
                errorStyle: GoogleFonts.dangrek(
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),

              style: GoogleFonts.firaSans(fontSize: 15),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                if (value.trim().length < 5) {
                  return 'Enter at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Description
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
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe the issue in detail...',
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

                // make validation message larger & clearer
                errorStyle: GoogleFonts.dangrek(
                  fontSize: 14,
                  color: Colors.red,
                ),
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
            const SizedBox(height: 8),
            // Image Upload
            Text(
              'Upload Image (Optional)',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1800AD),
              ),
            ),
            const SizedBox(height: 8),

            if (_imageFile == null) ...[
    // Image picker buttons
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1800AD), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    // Image preview
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
            onPressed: () {
              setState(() {
                _imageFile = null;
              });
            },
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
    const SizedBox(height: 18),

    // Submit button
    SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1800AD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10), // added vertical padding
      ),
      child: _loading
        ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
          ),
        )
          : Text(
              'Submit Report',
              style: GoogleFonts.dangrek(
              color: Colors.white,
              fontSize: 18,
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
}

// ===== REPORT DETAIL PAGE =====
class ReportDetailPage extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const ReportDetailPage({
    super.key,
    required this.reportId,
    required this.reportData,
  });


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

  Future<void> _deleteReport(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            titlePadding: const EdgeInsets.only(
                top: 12, left: 16, right: 16, bottom: 5),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 5),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 50,
                    color: Colors.orange),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Delete Report?",
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
              'Are you sure you want to delete this report? This action cannot be undone',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1800AD),
              ),
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 0),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
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
      final imageUrl = reportData['imageUrl'] as String?;

      // Delete image from storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (e) {
          // Ignore if image already deleted
        }
      }

      // Delete report document
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();

      if (!context.mounted) return;

      Navigator.pop(context); // Go back to list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report deleted successfully',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting report: $e',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = reportData['issue'] ?? 'Untitled';
    final category = reportData['category'] ?? 'other';
    final location = reportData['location'] ?? 'Unknown';
    final description = reportData['description'] ?? 'No description';
    final status = reportData['status'] ?? 'pending';
    final imageUrl = reportData['imageUrl'] as String?;
    final sentAt = reportData['sentAt'] as Timestamp?;
    final startedAt = reportData['startedAt'] as Timestamp?;
    final completedAt = reportData['completedAt'] as Timestamp?;
    final adminNotes = reportData['adminNotes'] as String?;

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

    final canDelete = status == 'pending';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Report Details',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (canDelete)
            IconButton(
              onPressed: () => _deleteReport(context),
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Delete Report',
            ),
        ],
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
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
            const SizedBox(height: 10),

            // Divider
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 10),

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
            const SizedBox(height: 10),

            // Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 10),
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
                    builder: (_) =>
                        Dialog(
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
              const SizedBox(height: 10),
            ],

            // Timeline
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 10),
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
            const SizedBox(height: 24),

            // Admin Notes
            if (adminNotes != null && adminNotes.isNotEmpty) ...[
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 20),
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
                    Icon(Icons.info_outline, color: Colors.blue.shade700,
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        adminNotes,
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
        ),
      ),
    );
  }

  Widget _buildTimelineItem(IconData icon, String label, String time,
      Color color) {
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