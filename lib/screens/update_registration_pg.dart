import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateRegistrationPage extends StatefulWidget {
  final String uid;// users uid
  final Map<String, dynamic> currentData;

  const UpdateRegistrationPage({
    super.key,
    required this.uid,
    required this.currentData,
  });

  @override
  State<UpdateRegistrationPage> createState() => _UpdateRegistrationPageState();
}

class _UpdateRegistrationPageState extends State<UpdateRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emergencyCtrl;
  late final TextEditingController _blockCtrl;
  late final TextEditingController _roomCtrl;

  // Read-only data
  late final String _email;
  late final String _studentId;

  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();

    // Initialize read-only fields
    _email = widget.currentData['email'] ?? '';
    _studentId = widget.currentData['studentId'] ?? '';

    // Initialize editable fields with current data
    _nameCtrl = TextEditingController(text: widget.currentData['name'] ?? '');
    _emergencyCtrl = TextEditingController(text: widget.currentData['emergencyContact'] ?? '');
    _blockCtrl = TextEditingController(text: widget.currentData['block'] ?? '');
    _roomCtrl = TextEditingController(text: widget.currentData['room'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emergencyCtrl.dispose();
    _blockCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final block = _blockCtrl.text.trim().toUpperCase();

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'name': _nameCtrl.text.trim(),
        'nameLower': _nameCtrl.text.trim().toLowerCase(),
        'block': block,
        'room': _roomCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        'approvalStatus': 'pending', // Reset to pending for re-review
        'rejectionReason': null, // Clear rejection reason
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 60, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                'Information Updated!',
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
            'Your information has been updated and submitted for admin review. You will be notified once approved.',
            style: GoogleFonts.firaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to waiting screen
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
      setState(() {
        _error = 'Failed to update: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    Widget? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dangrek(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: prefixIcon,
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
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          style: GoogleFonts.dangrek(color: const Color(0xFF1800AD)),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required Widget prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1800AD),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!, width: 2),
          ),
          child: Row(
            children: [
              prefixIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.dangrek(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(Icons.lock, size: 20, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This field cannot be changed',
          style: GoogleFonts.firaSans(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Update Information',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Update your information and submit for admin re-review. Email and Student ID cannot be changed.',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), //before email

              // Read-only: Email
              _buildReadOnlyField(
                label: 'Email',
                value: _email,
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Read-only: Student ID
              _buildReadOnlyField(
                label: 'Student ID',
                value: _studentId,
                prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
              ),
              const SizedBox(height: 15),

              // Divider
              Divider(thickness: 2, color: Colors.grey[300]),
              const SizedBox(height: 15),

              Text(
                'Editable Information',
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1800AD),
                ),
              ),
              const SizedBox(height: 16),

              // Editable: Name
              _buildTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: const Icon(Icons.person, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value.trim())) {
                    return 'Enter a valid name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Editable: Block
              _buildTextField(
                controller: _blockCtrl,
                label: 'Block',
                hint: 'Enter your block',
                prefixIcon: const Icon(Icons.home_outlined, color: Color(0xFF1800AD)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Block is required';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value.trim())) {
                    return 'Enter a valid block';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Editable: Room
              _buildTextField(
                controller: _roomCtrl,
                label: 'Room',
                hint: 'Enter your room number',
                prefixIcon: const Icon(Icons.meeting_room_outlined, color: Color(0xFF1800AD)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Room is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Editable: Emergency Contact
              _buildTextField(
                controller: _emergencyCtrl,
                label: 'Emergency Contact',
                hint: 'Enter emergency contact number',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF1800AD)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Emergency contact is required';
                  }
                  if (!RegExp(r'^\d{8,15}$').hasMatch(value.trim())) {
                    return 'Enter a valid phone number (8-15 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Error message
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: GoogleFonts.firaSans(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50, // slightly taller for comfort
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1800AD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20), // prevent clipping
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Submit for Review',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dangrek(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1800AD), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.dangrek(
                      color: const Color(0xFF1800AD),
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