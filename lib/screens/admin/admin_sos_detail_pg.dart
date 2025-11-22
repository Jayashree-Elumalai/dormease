import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminSosDetailPage extends StatefulWidget {
  final String alertId;

  const AdminSosDetailPage({super.key, required this.alertId});

  @override
  State<AdminSosDetailPage> createState() => _AdminSosDetailPageState();
}

class _AdminSosDetailPageState extends State<AdminSosDetailPage> {
  final _notesController = TextEditingController();
  bool _isAcknowledging = false;
  bool _isResolving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // acknowledge alert (mark as "responding")
  Future<void> _acknowledgeAlert() async {
    setState(() => _isAcknowledging = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      // Get current alert status
      final alertDoc = await FirebaseFirestore.instance
          .collection('sosAlerts')
          .doc(widget.alertId)
          .get();

      if (!alertDoc.exists) {
        throw Exception('Alert not found');
      }

      final currentStatus = alertDoc.data()?['status'];

      // Only allow acknowledging if status is 'active'
      if (currentStatus != 'active') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This alert has already been acknowledged',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isAcknowledging = false);
        return;
      }

      //  Update Firestore
      await FirebaseFirestore.instance
          .collection('sosAlerts')
          .doc(widget.alertId)
          .update({
        'status': 'acknowledged',
        'acknowledgedBy': currentUser.uid,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are responding to this alert',
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
    } finally {
      if (mounted) setState(() => _isAcknowledging = false);
    }
  }

  // Resolve alert (mark as resolved with notes)
  Future<void> _resolveAlert() async {
    // Validate notes (minimum 10 characters)
    if (_notesController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add notes (minimum 10 characters)',
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Column(
          children: [
            const Icon(Icons.check_circle, size: 50, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              'Mark as Resolved?',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: Text(
          'This will close the alert and notify the student',
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
              'Cancel',
              style: GoogleFonts.firaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Resolve',
              style: GoogleFonts.firaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResolving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not logged in');

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('sosAlerts')
          .doc(widget.alertId)
          .update({
        'status': 'resolved',
        'resolvedBy': currentUser.uid,
        'resolvedAt': FieldValue.serverTimestamp(),
        'adminNotes': _notesController.text.trim(),
      });

      if (!mounted) return;

      // Navigate back
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alert resolved successfully',
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
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'SOS Alert Details',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Alert not found',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          final studentName = data['studentName'] ?? 'Unknown';
          final studentId = data['studentId'] ?? 'N/A';
          final location = data['location'] ?? 'Unknown';
          final category = data['category'] ?? 'emergency';
          final description = data['description'] as String?;
          final createdAt = data['createdAt'] as Timestamp?;
          final acknowledgedAt = data['acknowledgedAt'] as Timestamp?;
          final acknowledgedBy = data['acknowledgedBy'] as String?;
          final resolvedAt = data['resolvedAt'] as Timestamp?;
          final resolvedBy = data['resolvedBy'] as String?;
          final adminNotes = data['adminNotes'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status), width: 3),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 60,
                        color: _getStatusColor(status),
                      ),
                      //const SizedBox(height: 10),
                      Text(
                        _getStatusText(status),
                        style: GoogleFonts.firaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _getStatusColor(status),
                        ),
                      ),
                      //const SizedBox(height: 6),
                      Text(
                        _getStatusDescription(status),
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Student Info Card
                _buildInfoCard(
                  icon: Icons.person,
                  label: 'Student',
                  value: '$studentName ($studentId)',
                  color: const Color(0xFF1800AD),
                ),

                // Location Card
                _buildInfoCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: location,
                  color: Colors.red[700]!,
                ),

                // Category Card
                _buildInfoCard(
                  icon: _getCategoryIcon(category),
                  label: 'Emergency Type',
                  value: '${_formatCategory(category)}',
                  color: _getCategoryColor(category),
                ),

                // Description (if exists)
                if (description != null && description.isNotEmpty)
                  _buildInfoCard(
                    icon: Icons.description,
                    label: 'Description',
                    value: description,
                    color: Colors.grey[700]!,
                  ),

                const SizedBox(height: 5),

                // Timeline
                Text(
                  'Timeline',
                  style: GoogleFonts.firaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1800AD),
                  ),
                ),
                const SizedBox(height: 5),

                if (createdAt != null)
                  _buildTimelineItem(
                    icon: Icons.notifications_active,
                    label: 'Alert Sent',
                    time: DateFormat('MMM d, yyyy - h:mm a').format(createdAt.toDate()),
                    color: Colors.red,
                  ),

                if (acknowledgedAt != null && acknowledgedBy != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(acknowledgedBy)
                        .get(),
                    builder: (context, adminSnapshot) {
                      String adminName = 'Admin';
                      if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                        adminName = adminSnapshot.data!.get('name') ?? 'Admin';
                      }
                      return _buildTimelineItem(
                        icon: Icons.check_circle_outline,
                        label: 'Acknowledged by $adminName',
                        time: DateFormat('MMM d, yyyy - h:mm a')
                            .format(acknowledgedAt.toDate()),
                        color: Colors.orange,
                      );
                    },
                  ),

                if (resolvedAt != null && resolvedBy != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(resolvedBy)
                        .get(),
                    builder: (context, adminSnapshot) {
                      String adminName = 'Admin';
                      if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                        adminName = adminSnapshot.data!.get('name') ?? 'Admin';
                      }
                      return _buildTimelineItem(
                        icon: Icons.check_circle,
                        label: 'Resolved by $adminName',
                        time: DateFormat('MMM d, yyyy - h:mm a')
                            .format(resolvedAt.toDate()),
                        color: Colors.green,
                      );
                    },
                  ),

                const SizedBox(height: 10),

                // Admin Notes Section (only if acknowledged or resolved)
                if (status == 'acknowledged' || status == 'resolved') ...[
                  Text(
                    status == 'resolved' ? 'Resolution Notes' : 'Add Notes',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1800AD),
                    ),
                  ),
                  const SizedBox(height: 5),

                  if (status == 'resolved' && adminNotes != null)
                  // Show notes (read-only)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Text(
                        adminNotes,
                        style: GoogleFonts.firaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  else
                  // Notes input (editable)
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: 'Describe actions taken',
                        hintStyle: GoogleFonts.firaSans(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1800AD),
                            width: 2,
                          ),
                        ),
                      ),
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const SizedBox(height: 10),
                ],

                // Action Buttons
                if (status == 'active')
                // Acknowledge button (only if active)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isAcknowledging ? null : _acknowledgeAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: _isAcknowledging
                          ? const SizedBox(
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        _isAcknowledging ? 'Acknowledging...' : 'RESPOND NOW',
                        style: GoogleFonts.dangrek(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (status == 'acknowledged')
                // Resolve button (only if acknowledged)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isResolving ? null : _resolveAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: _isResolving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.check, color: Colors.white),
                      label: Text(
                        _isResolving ? 'Resolving...' : 'Mark as Resolved',
                        style: GoogleFonts.dangrek(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper: Info Card
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),

                Text(
                  value,
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
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

  // Helper: Timeline Item
  Widget _buildTimelineItem({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  // Helper functions
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
        return 'ACTIVE ALERT';
      case 'acknowledged':
        return 'RESPONDING';
      case 'resolved':
        return 'RESOLVED';
      default:
        return 'UNKNOWN';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'active':
        return 'Emergency alert requires immediate attention';
      case 'acknowledged':
        return 'Admin is responding to this alert';
      case 'resolved':
        return 'This emergency has been resolved';
      default:
        return '';
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'medical':
        return Icons.local_hospital;
      case 'safety':
        return Icons.security;
      default:
        return Icons.help_outline;
    }
  }

  String _formatCategory(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}