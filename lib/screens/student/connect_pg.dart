import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../login_pg.dart';
import 'home_pg.dart';
import 'parcel_pg.dart';
import 'report_issue_pg.dart';
import 'sos_pg.dart';
import '/services/auth_service.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final int _selectedIndex = 3;
  final _searchController = TextEditingController();

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

  // Get unread message count for badge
  Stream<int> _getUnreadCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastMessageBy = data['lastMessageBy'] as String?;

        // Check if blocked
        final status = Map<String, dynamic>.from(data['status'] ?? {});
        final myStatus = status[currentUser.uid];
        if (myStatus == 'blocked') continue; // Skip blocked conversations

        // Don't count if I sent the last message
        if (lastMessageBy == currentUser.uid) continue;

        // Count unread messages in this conversation
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .where('sentBy', isNotEqualTo: currentUser.uid)
            .get();

        for (var msgDoc in messagesSnapshot.docs) {
          final msgData = msgDoc.data();

          // Skip system messages
          if (msgData['isSystemMessage'] == true) continue;
          final readBy = List<String>.from(msgData['readBy'] ?? []);
          if (!readBy.contains(currentUser.uid)) {
            totalUnread++;
          }
        }
      }
      return totalUnread;
    });
  }

  //CONNECT PG UI
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        elevation: 0,
        title: Text(
          'Connect',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // New chat button
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Colors.white),
            onSelected: (value) {
              if (value == 'direct') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatPage(isGroup: false)),
                );
              } else if (value == 'group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatPage(isGroup: true)),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'direct',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF1800AD)),
                    const SizedBox(width: 12),
                    Text('New Chat', style: GoogleFonts.firaSans(fontSize: 15)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Color(0xFF1800AD)),
                    const SizedBox(width: 12),
                    Text('New Group', style: GoogleFonts.firaSans(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
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
      body: currentUser == null
          ? const Center(child: Text('Please login'))
          : Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: GoogleFonts.firaSans(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD)),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Conversations list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final conversations = snapshot.data!.docs;
                final searchQuery = _searchController.text.trim().toLowerCase();

                // Filter by search ONLY if there's a search query
                final filtered = searchQuery.isEmpty
                    ? conversations
                    : conversations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'direct';

                  if (type == 'group') {
                    final groupName = (data['groupName'] ?? '').toLowerCase();
                    return groupName.contains(searchQuery);
                  } else {
                    // Search in participant names
                    final participants = data['participantDetails'] as Map<String, dynamic>?;
                    if (participants == null) return false;

                    for (var uid in participants.keys) {
                      if (uid == currentUser.uid) continue;
                      final name = (participants[uid]['name'] ?? '').toLowerCase();
                      if (name.contains(searchQuery)) return true;
                    }
                    return false;
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          searchQuery.isEmpty ? 'No conversations found' : 'No results for "$searchQuery"',
                          style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildConversationTile(doc.id, data, currentUser.uid);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _getUnreadCount(),
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
                _buildNavItem(Icons.report, 'Report', 0),
                _buildNavItem(Icons.inventory, 'Parcel', 1),
                _buildNavItem(Icons.home, 'Home', 2),
                _buildNavItem(Icons.chat, 'Connect', 3, badgeCount: badgeCount),
                _buildNavItem(Icons.warning, 'SOS', 4),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Conversations Yet',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start a new chat',
            style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(String conversationId, Map<String, dynamic> data, String currentUid) {
    final type = data['type'] ?? 'direct';
    final participants = data['participantDetails'] as Map<String, dynamic>?;
    final lastMessage = data['lastMessage'] ?? '';
    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
    final lastMessageBy = data['lastMessageBy'] as String?;

    String displayName = '';
    String displayInitials = '';
    Color avatarColor = Colors.blue;

    if (type == 'group') {
      displayName = data['groupName'] ?? 'Group Chat';
      displayInitials = displayName.substring(0, 1).toUpperCase();
      avatarColor = Colors.purple;
    } else {
      // Get other participant's details
      if (participants != null) {
        for (var uid in participants.keys) {
          if (uid != currentUid) {
            displayName = participants[uid]['name'] ?? 'Unknown';
            displayInitials = _getInitials(displayName);
            avatarColor = _getColorFromString(uid);
            break;
          }
        }
      }
    }

    return FutureBuilder<int>(
      future: _getUnreadCountForConversation(conversationId, currentUid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avatarColor,
            child: type == 'group'
                ? const Icon(Icons.group, color: Colors.white)
                : Text(
              displayInitials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.firaSans(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1800AD),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Builder( // 🆕 WRAPPED: Use Builder to handle null safety
            builder: (context) {
              // 🆕 ADDED: Get lastMessageType from data, default to 'text' if not set
              final messageType = data['lastMessageType'] as String?;
              final isDeleted = messageType == 'deleted'; // 🆕 ADDED: Check if deleted

              return Row(
                children: [
                  // 🆕 ADDED: Show block icon ONLY if lastMessageType is 'deleted'
                  if (isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.block, // 🎯 Same icon as in chat bubbles
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  Expanded(
                    child: Text(
                      lastMessage,
                      style: GoogleFonts.firaSans(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontStyle: isDeleted // 🆕 ADDED: Italic ONLY if deleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
          onTap: () async { // ✅ CHANGED: Made async
            await Navigator.push( // ✅ CHANGED: Added await
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: conversationId,
                  chatName: displayName,
                  isGroup: type == 'group',
                ),
              ),
            );
            // 🆕 ADDED: Force rebuild to update timestamps
            if (mounted) {
              setState(() {}); // This triggers rebuild and fetches fresh data
            }
          },
        );
      },
    );
  }

  Future<int> _getUnreadCountForConversation(String conversationId, String currentUid) async {
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('sentBy', isNotEqualTo: currentUid)
        .get();

    int unread = 0;
    for (var doc in messagesSnapshot.docs) {
      final data = doc.data();

      // 🆕 ADDED: Skip system messages
      if (data['isSystemMessage'] == true) continue;
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(currentUid)) unread++;
    }
    return unread;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(date);
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
                    color: Color(0xFF1800AD),
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
}

// ===== NEW CHAT PAGE (Search Students) =====
class NewChatPage extends StatefulWidget {
  final bool isGroup;

  const NewChatPage({super.key, this.isGroup = false});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _searchController = TextEditingController();
  final _selectedUsers = <String, Map<String, dynamic>>{};
  late bool _isCreatingGroup;
  final _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isCreatingGroup = widget.isGroup;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  //NEW CHAT/NEW GROUP PG UI
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          _isCreatingGroup ? 'New Group' : 'New Chat',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 22),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedUsers.isNotEmpty && !_isCreatingGroup)
            TextButton(
              onPressed: () {
                setState(() => _isCreatingGroup = true);
              },
              child: Text(
                'Group',
                style: GoogleFonts.dangrek(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search dormmates...',
                hintStyle: GoogleFonts.firaSans(color: Colors.grey,fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD), size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                isDense: true,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Group name input (if creating group)
          if (_isCreatingGroup)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.group, color: Color(0xFF1800AD), size: 20),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // ✅ CHANGED: 12→8
                  isDense: true,
                ),
              ),
            ),
          if (_isCreatingGroup)
          // Selected users chips
          if (_selectedUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUsers.entries.map((entry) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _getColorFromString(entry.key),
                      child: Text(
                        _getInitials(entry.value['name']),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    label: Text(entry.value['name']),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedUsers.remove(entry.key);
                        if (_selectedUsers.length < 2 && !widget.isGroup) {
                          _isCreatingGroup = false;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          // Instruction text
          if (_isCreatingGroup && _selectedUsers.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select at least 2 members to create a group',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          // Students list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .where('approvalStatus', isEqualTo: 'approved')
                  .orderBy('nameLower')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found',
                      style: GoogleFonts.firaSans(fontSize: 16),
                    ),
                  );
                }

                final students = snapshot.data!.docs.where((doc) {
                  // Exclude current user
                  if (doc.id == currentUser?.uid) return false;

                  // Filter by search
                  final searchQuery = _searchController.text.trim().toLowerCase();
                  if (searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['nameLower'] ?? '').toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No students found'
                          : 'No results for "${_searchController.text.trim()}"',
                      style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final doc = students[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final uid = doc.id;
                    final isSelected = _selectedUsers.containsKey(uid);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorFromString(uid),
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.firaSans(fontSize: 16),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF1800AD))
                          : null,
                      onTap: () {
                        if (_isCreatingGroup) {
                          setState(() {
                            if (isSelected) {
                              _selectedUsers.remove(uid);
                            } else {
                              _selectedUsers[uid] = {'name': name, 'nameLower': data['nameLower']};
                            }
                          });
                        } else {
                          if (_selectedUsers.isEmpty) {
                            // Start 1-on-1 chat immediately
                            _startDirectChat(uid, name, data['nameLower']);
                          } else {
                            setState(() {
                              if (isSelected) {
                                _selectedUsers.remove(uid);
                              } else {
                                _selectedUsers[uid] = {'name': name, 'nameLower': data['nameLower']};
                              }
                            });
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 🆕 ADDED: FAB (Floating Action Button) for creating group
      floatingActionButton: _isCreatingGroup && _selectedUsers.length >= 2
          ? FloatingActionButton.extended(
        onPressed: _createGroupChat,
        backgroundColor: Colors.green,
        //icon: const Icon(Icons.check, color: Colors.white),
        label: Text(
          'Create Group',
          style: GoogleFonts.dangrek(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _startDirectChat(String otherUid, String otherName, String otherNameLower) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check if conversation already exists
      final existingConv = await FirebaseFirestore.instance
          .collection('conversations')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      String? conversationId;

      for (var doc in existingConv.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUid)) {
          conversationId = doc.id;
          break;
        }
      }

      // Get current user details
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';
      final currentUserNameLower = currentUserDoc.data()?['nameLower'] ?? '';

      // Create new conversation if doesn't exist
      if (conversationId == null) {
        final newConv = await FirebaseFirestore.instance.collection('conversations').add({
          'type': 'direct',
          'participants': [currentUser.uid, otherUid],
          'participantDetails': {
            currentUser.uid: {
              'name': currentUserName,
              'nameLower': currentUserNameLower,
            },
            otherUid: {
              'name': otherName,
              'nameLower': otherNameLower,
            },
          },
          // 🆕 ADDED: Blocking system fields
          'status': {
            currentUser.uid: 'accepted',
            otherUid: 'pending',
          },
          'blockedBy': {
            currentUser.uid: null,
            otherUid: null,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageBy': null,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.uid,
        });
        conversationId = newConv.id;
      }

      if (!mounted) return;

      // Navigate to chat screen
      Navigator.push( // ✅ CHANGED: pushReplacement → push
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId!,
            chatName: otherName,
            isGroup: false,
          ),
        ),
      ).then((_) {
        // 🆕 ADDED: After chat closes, go back to Connect page
        if (mounted) {
          Navigator.pop(context); // Go back to Connect page
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _createGroupChat() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedUsers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 members')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user details
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';
      final currentUserNameLower = currentUserDoc.data()?['nameLower'] ?? '';

      final participants = [currentUser.uid, ..._selectedUsers.keys];
      final participantDetails = {
        currentUser.uid: {
          'name': currentUserName,
          'nameLower': currentUserNameLower,
        },
        ..._selectedUsers,
      };

      // 🆕 ADDED: Track who has seen the "added to group" banner
      final seenAddedBanner = <String, bool>{};
      for (var uid in participants) {
        if (uid == currentUser.uid) {
          seenAddedBanner[uid] = true; // Creator doesn't need to see banner
        } else {
          seenAddedBanner[uid] = false; // Others need to see it
        }
      }

      final newGroup = await FirebaseFirestore.instance.collection('conversations').add({
        'type': 'group',
        'groupName': _groupNameController.text.trim(),
        'participants': participants,
        'participantDetails': participantDetails,
        'seenAddedBanner': seenAddedBanner,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
      });

      if (!mounted) return;

      Navigator.push( // ✅ CHANGED: pushReplacement → push
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: newGroup.id,
            chatName: _groupNameController.text.trim(),
            isGroup: true,
          ),
        ),
      ).then((_) {
        // 🆕 ADDED: After chat closes, go back to Connect page
        if (mounted) {
          Navigator.pop(context); // Go back to Connect page
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }
}

// ===== CHAT SCREEN =====
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String chatName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  // 🆕 ADDED: Mark "added to group" banner as seen
  Future<void> _markAddedBannerAsSeen() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'seenAddedBanner.${currentUser.uid}': true,
      });
    } catch (e) {
      // Silently fail if field doesn't exist (old groups)
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .where('sentBy', isNotEqualTo: currentUser.uid)
        .get();

    for (var doc in messagesSnapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(currentUser.uid)) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }
    }
  }

  // Accept chat request
  Future<void> _acceptChatRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'accepted',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chat request accepted',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Block user
  Future<void> _blockUser(String otherUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 🆕 ADDED: Better padding
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12),

        // 🔄 CHANGED: Better styled title with icon
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 50, color: Colors.red), // 🆕 ADDED: Block icon
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Block ${widget.chatName}?',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold, // 🆕 ADDED: Bold
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),

        content: Text(
          "You won't see their messages and they can't send you new messages",
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600, // 🆕 ADDED: Semi-bold
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold, // 🆕 ADDED: Bold
                  color: Colors.grey[700],
                )
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                'Block',
                style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red
                )
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'blocked',
        'blockedBy.${currentUser.uid}': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User blocked',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // 🆕 ADDED: Unblock user
  Future<void> _unblockUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'status.${currentUser.uid}': 'accepted',
        'blockedBy.${currentUser.uid}': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User unblocked',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Leave group function
  Future<void> _leaveGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app, size: 50, color: Colors.orange),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Leave ${widget.chatName}?',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        content: Text(
          "You'll be removed from this group. You can be added back by any member.",
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                )
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                'Leave',
                style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange
                )
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final convRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId);

      // Get current conversation data
      final convDoc = await convRef.get();
      final convData = convDoc.data();

      if (convData != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          final userName = userDoc.data()?['name'] ?? 'Someone';

          // 🆕 Post "{name} left" system message BEFORE removing from group
          await convRef.collection('messages').add({
            'text': '$userName left',
            'sentBy': 'system',
            'sentByName': 'System',
            'sentAt': FieldValue.serverTimestamp(),
            'readBy': [],
            'isSystemMessage': true, // 🆕 Mark as system message
          });
        }

        // Remove user from participants array
        await convRef.update({
          'participants': FieldValue.arrayRemove([currentUser?.uid]),
          'participantDetails.${currentUser?.uid}': FieldValue.delete(),
          'seenAddedBanner.${currentUser?.uid}': FieldValue.delete(),
        });
      }

      if (!mounted) return;

      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You left ${widget.chatName}',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
        ),
      );

      // Go back to Connect page
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserDoc.data()?['name'] ?? 'Unknown';

      final messageText = _messageController.text.trim();
      _messageController.clear();

      // 🆕 ADDED: Mark banner as seen when sending first message
      if (widget.isGroup) {
        _markAddedBannerAsSeen();
      }

      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'text': messageText,
        'sentBy': currentUser.uid,
        'sentByName': currentUserName,
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid],
        'editedAt': null,
        'deletedAt': null,
        'deletedBy': null,
      });

      // Update conversation's last message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageBy': currentUser.uid,
        'lastMessageType': 'text',
      });

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get message being deleted
      final msgDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .get();

      final msgData = msgDoc.data();
      final isLastMessage = msgData?['sentAt'] != null;

      // Mark message as deleted
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // ✅ NEW: Update conversation's lastMessage if this was the last message
      if (isLastMessage) {
        // Check if this is actually the most recent message
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get();

        final convData = conversationDoc.data();
        final lastMessageBy = convData?['lastMessageBy'];

        // Only update if this message was from the current user (likely the last one)
        if (lastMessageBy == currentUser.uid) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({
            'lastMessage': 'Message deleted', // ✅ CHANGED: Show deletion indicator
            'lastMessageType': 'deleted', // 🆕 ADDED: Track message type
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  Future<void> _editMessage(String messageId, String currentText) async {
    final controller = TextEditingController(text: currentText);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // 🆕 ADDED: Better padding
        titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        // ✅ IMPROVED: Styled title
        title: Text(
          'Edit Message',
          style: GoogleFonts.firaSans(
            fontSize: 20, // 🆕 ADDED
            fontWeight: FontWeight.bold, // 🆕 ADDED
            color: const Color(0xFF1800AD), // 🆕 ADDED
          ),
          textAlign: TextAlign.center, // 🆕 ADDED
        ),

        // ✅ IMPROVED: Styled text field
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true, // 🆕 ADDED: Auto-focus for convenience
          style: GoogleFonts.firaSans( // 🆕 ADDED: Match chat style
            fontSize: 15,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: GoogleFonts.firaSans( // ✅ CHANGED: Now using firaSans
              color: Colors.grey,
              fontSize: 15,
            ),
            filled: true, // 🆕 ADDED
            fillColor: Colors.grey[100], // 🆕 ADDED
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // ✅ CHANGED: 8→12
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2), // 🆕 ADDED
            ),
            enabledBorder: OutlineInputBorder( // 🆕 ADDED
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
            ),
            focusedBorder: OutlineInputBorder( // 🆕 ADDED
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1800AD), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12), // 🆕 ADDED
          ),
        ),

        // ✅ IMPROVED: Styled buttons
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom( // 🆕 ADDED: Button styling
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.firaSans(
                fontSize: 15, // 🆕 ADDED
                fontWeight: FontWeight.bold, // ✅ CHANGED: Made bold
                color: Colors.grey[700], // ✅ CHANGED: Grey color
              ),
            ),
          ),

          // Save button
          TextButton( // ✅ CHANGED: TextButton → ElevatedButton
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: TextButton.styleFrom( // 🆕 ADDED: Green button
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.firaSans(
                fontSize: 15, // 🆕 ADDED
                fontWeight: FontWeight.bold, // ✅ CHANGED: Made bold
                color: Colors.green, // 🆕 ADDED
              ),
            ),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Update message
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .doc(messageId)
            .update({
          'text': newText,
          'editedAt': FieldValue.serverTimestamp(),
        });

        // ✅ NEW: Update conversation's lastMessage if this was the last message
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get();

        final convData = conversationDoc.data();
        final lastMessageBy = convData?['lastMessageBy'];

        // Only update if this message was from the current user (likely the last one)
        if (lastMessageBy == currentUser.uid) {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({
            'lastMessage': newText, // ✅ CHANGED: Update with edited text
            'lastMessageType': 'text', // 🆕 ADDED: Track message type
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing message: $e')),
        );
      }
    }
  }

  void _showMessageOptions(String messageId, String text, Timestamp? sentAt, String sentBy) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || sentBy != currentUser.uid) return;

    final now = DateTime.now();
    final messageTime = sentAt?.toDate() ?? now;
    final diff = now.difference(messageTime);
    final canEdit = diff.inMinutes <= 5;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text('Edit', style: GoogleFonts.firaSans()),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(messageId, text);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: GoogleFonts.firaSans(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: Text('Cancel', style: GoogleFonts.firaSans()),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chatName,
              style: GoogleFonts.dangrek(color: Colors.white, fontSize: 18),
            ),
            if (widget.isGroup)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final participants = List<String>.from(
                      data?['participants'] ?? []);
                  return Text(
                    '${participants.length} members',
                    style: GoogleFonts.firaSans(color: Colors.white70, fontSize: 12),
                  );
                },
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showGroupInfo,
            )
          // 🆕 ADDED: Block/Unblock menu for direct chats only
          else
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final data = snapshot.data?.data() as Map<String, dynamic>?;

                // 🆕 ADDED: Check if status and participants exist
                if (data == null) return const SizedBox.shrink();

                final status = Map<String, dynamic>.from(data['status'] ?? {});
                final myStatus = status[currentUser?.uid];
                final participants = List<String>.from(data['participants'] ?? []);
                final otherUid = participants.firstWhere(
                        (uid) => uid != currentUser?.uid,
                    orElse: () => ''
                );

                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'block') {
                      _blockUser(otherUid);
                    } else if (value == 'unblock') {
                      _unblockUser();
                    }
                  },
                  itemBuilder: (context) => [
                    if (myStatus != 'blocked')
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block, color: Colors.red),
                            const SizedBox(width: 12),
                            Text('Block User', style: GoogleFonts.firaSans(color: Colors.red)),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'unblock',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 12),
                            Text('Unblock User', style: GoogleFonts.firaSans(color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .snapshots(),
          builder: (context, convSnapshot) {
    if (!convSnapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
    }

    final convData = convSnapshot.data?.data() as Map<String, dynamic>?;

    // 🆕 ADDED: Safe null handling
    final status = convData != null
    ? Map<String, dynamic>.from(convData['status'] ?? {})
        : <String, dynamic>{};
    final participants = convData != null
    ? List<String>.from(convData['participants'] ?? [])
        : <String>[];

    final myStatus = status[currentUser?.uid];
    final otherUid = participants.firstWhere(
    (uid) => uid != currentUser?.uid,
    orElse: () => ''
    );
    final otherStatus = status[otherUid];

    // 🆕 ADDED: Check blocking status
    final iBlockedThem = myStatus == 'blocked';
    final theyBlockedMe = otherStatus == 'blocked';
    final isPending = myStatus == 'pending' && !widget.isGroup;
    // 🆕 ADDED: Check if user has seen "added to group" banner
    final seenAddedBanner = convData != null
    ? Map<String, dynamic>.from(convData['seenAddedBanner'] ?? {})
        : <String, dynamic>{};
    final showAddedBanner = widget.isGroup &&
    (seenAddedBanner[currentUser?.uid] == false || seenAddedBanner[currentUser?.uid] == null);


    return Column(
      children: [
        // 🆕 ADDED: "Added to group" banner
        if (showAddedBanner)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF1800AD), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You've been added to ${widget.chatName}",
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1800AD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // 🆕 ADDED: Accept/Block banner for pending requests
        if (isPending && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  Text(
                    'Accept chat request from ${widget.chatName}?',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // 🔄 CHANGED: TextButton → Outlined button for better visibility
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _blockUser(otherUid),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Block',
                          style: GoogleFonts.firaSans(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // 🆕 ADDED: Space between buttons
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _acceptChatRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Accept',
                          style: GoogleFonts.firaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // 🆕 ADDED: Blocker banner
        if (iBlockedThem && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.block, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You blocked this user. Unblock to continue chatting.',
                    style: GoogleFonts.firaSans(fontSize: 14, color: Colors.red.shade900),
                  ),
                ),
                TextButton(
                  onPressed: _unblockUser,
                  child: Text('Unblock', style: GoogleFonts.firaSans(color: Colors.red)),
                ),
              ],
            ),
          ),
        // 🆕 ADDED: Blocked banner
        if (theyBlockedMe && !widget.isGroup)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This user is unavailable',
                    style: GoogleFonts.firaSans(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        // Messages list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .orderBy('sentAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60,
                          color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: GoogleFonts.firaSans(
                            fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send a message to start the conversation',
                        style: GoogleFonts.firaSans(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final doc = messages[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final deletedAt = data['deletedAt'] as Timestamp?;

                  final currentMessageTime = (data['sentAt'] as Timestamp?)
                      ?.toDate();
                  final previousMessageTime = index < messages.length - 1
                      ? ((messages[index + 1].data() as Map<String,
                      dynamic>)['sentAt'] as Timestamp?)?.toDate()
                      : null;

                  final showDateHeader = _shouldShowDateHeader(
                      currentMessageTime, previousMessageTime);
                  return Column(
                    children: [
                      // 🆕 ADDED: Date header
                      if (showDateHeader && currentMessageTime != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDateHeader(currentMessageTime),
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),

                      // Message bubble
                      if (deletedAt != null)
                        _buildDeletedMessage(data['sentBy'] == currentUser?.uid)
                      else
                        if (data['isSystemMessage'] ==
                            true) // 🆕 ADDED: System messages
                          _buildSystemMessage(data['text'] ?? '')
                        else
                          _buildMessageBubble(
                            doc.id,
                            data,
                            currentUser?.uid ?? '',
                          ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  // 🆕 ADDED: Disable if blocked
                  enabled: !iBlockedThem && !theyBlockedMe && (myStatus == 'accepted' || widget.isGroup),
                  decoration: InputDecoration(
                    hintText: iBlockedThem || theyBlockedMe
                        ? 'Cannot send messages'
                        : isPending
                        ? 'Accept request to send messages'
                        : 'Type a message...',
                    hintStyle: GoogleFonts.firaSans(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: (iBlockedThem || theyBlockedMe || isPending)
                    ? Colors.grey
                    : const Color(0xFF1800AD),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: (iBlockedThem || theyBlockedMe || isPending)
                      ? null
                      : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
          },
      ),
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data, String currentUid) {
    final text = data['text'] ?? '';
    final sentBy = data['sentBy'] ?? '';
    final sentByName = data['sentByName'] ?? 'Unknown';
    final sentAt = data['sentAt'] as Timestamp?;
    final editedAt = data['editedAt'] as Timestamp?;
    final readBy = List<String>.from(data['readBy'] ?? []);

    final isMe = sentBy == currentUid;
    final allRead = readBy.length > 1; // More than just sender

    return GestureDetector(
      onLongPress: isMe ? () => _showMessageOptions(messageId, text, sentAt, sentBy) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && widget.isGroup)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: _getColorFromString(sentBy),
                  child: Text(
                    _getInitials(sentByName),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1800AD) : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && widget.isGroup)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          sentByName,
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    Text(
                      text,
                      style: GoogleFonts.firaSans(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(sentAt),
                          style: GoogleFonts.firaSans(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (editedAt != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: GoogleFonts.firaSans(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            allRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: allRead ? Colors.blue[200] : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedMessage(bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'This message was deleted',
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 System message bubble
  Widget _buildSystemMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: GoogleFonts.firaSans(
              fontSize: 13,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final participantDetails = data?['participantDetails'] as Map<String, dynamic>? ?? {};

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Group Members (${participantDetails.length})',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...participantDetails.entries.map((entry) {
                  final name = entry.value['name'] ?? 'Unknown';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getColorFromString(entry.key),
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(name, style: GoogleFonts.firaSans()),
                  );
                }),
                const Divider(height: 1),

                // 🆕 ADDED: Add Members button
                ListTile(
                  leading: const Icon(Icons.person_add, color: Color(0xFF1800AD)),
                  title: Text(
                    'Add Members',
                    style: GoogleFonts.firaSans(
                      color: const Color(0xFF1800AD),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close modal
                    _showAddMembersPage(); // 🆕 Open add members page
                  },
                ),

                const Divider(height: 1),

                // 🆕 ADDED: Leave Group button
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: Text(
                    'Leave Group',
                    style: GoogleFonts.firaSans(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close modal first
                    _leaveGroup(); // Then show leave confirmation
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🆕 ADD THIS ENTIRE FUNCTION AFTER _showGroupInfo():
  void _showAddMembersPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => AddMembersSheet(
          conversationId: widget.conversationId,
          groupName: widget.chatName,
        ),
      ),
    );
  }

  bool _shouldShowDateHeader(DateTime? current, DateTime? previous) {
    if (current == null) return false;
    if (previous == null) return true; // First message always shows date

    // Show header if different day
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  // 🆕 Format date header
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(date); // Monday, Tuesday, etc.
    } else {
      return DateFormat('MMM d, yyyy').format(date); // Jan 15, 2024
    }
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    return DateFormat('h:mm a').format(date);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }
}

// ===== ADD MEMBERS SHEET =====
class AddMembersSheet extends StatefulWidget {
  final String conversationId;
  final String groupName;

  const AddMembersSheet({
    super.key,
    required this.conversationId,
    required this.groupName,
  });

  @override
  State<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<AddMembersSheet> {
  final _searchController = TextEditingController();
  final _selectedUsers = <String, Map<String, dynamic>>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1800AD),
        title: Text(
          'Add Members',
          style: GoogleFonts.dangrek(color: Colors.white, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                hintStyle: GoogleFonts.firaSans(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1800AD), size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                isDense: true,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          // Selected users chips
          if (_selectedUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUsers.entries.map((entry) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _getColorFromString(entry.key),
                      child: Text(
                        _getInitials(entry.value['name']),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    label: Text(entry.value['name']),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() => _selectedUsers.remove(entry.key));
                    },
                  );
                }).toList(),
              ),
            ),

          // Students list
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .get(),
              builder: (context, convSnapshot) {
                if (!convSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final convData = convSnapshot.data?.data() as Map<String, dynamic>?;
                final existingParticipants = List<String>.from(convData?['participants'] ?? []);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'student')
                      .where('approvalStatus', isEqualTo: 'approved')
                      .orderBy('nameLower')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No students found',
                          style: GoogleFonts.firaSans(fontSize: 16),
                        ),
                      );
                    }

                    // Filter out existing members and apply search
                    final students = snapshot.data!.docs.where((doc) {
                      // Exclude existing members
                      if (existingParticipants.contains(doc.id)) return false;

                      final searchQuery = _searchController.text.trim().toLowerCase();
                      if (searchQuery.isEmpty) return true;

                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['nameLower'] ?? '').toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();

                    if (students.isEmpty) {
                      return Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'All students are already in the group'
                              : 'No results for "${_searchController.text.trim()}"',
                          style: GoogleFonts.firaSans(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final doc = students[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unknown';
                        final uid = doc.id;
                        final isSelected = _selectedUsers.containsKey(uid);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getColorFromString(uid),
                            child: Text(
                              _getInitials(name),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(name, style: GoogleFonts.firaSans(fontSize: 16)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFF1800AD))
                              : null,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedUsers.remove(uid);
                              } else {
                                _selectedUsers[uid] = {
                                  'name': name,
                                  'nameLower': data['nameLower']
                                };
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedUsers.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _addMembers,
        backgroundColor: Colors.green,
        label: Text(
          'Add ${_selectedUsers.length} ${_selectedUsers.length == 1 ? "Member" : "Members"}',
          style: GoogleFonts.dangrek(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: const Icon(Icons.check, color: Colors.white),
      )
          : null,
    );
  }

  Future<void> _addMembers() async {
    if (_selectedUsers.isEmpty) return;

    try {
      final convRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId);

      // Get current conversation
      final convDoc = await convRef.get();
      final convData = convDoc.data();

      if (convData != null) {
        final currentParticipants = List<String>.from(convData['participants'] ?? []);
        final newParticipants = [...currentParticipants, ..._selectedUsers.keys];

        final currentDetails = Map<String, dynamic>.from(convData['participantDetails'] ?? {});
        final newDetails = {...currentDetails, ..._selectedUsers};

        // 🆕 Update seenAddedBanner for new members
        final seenAddedBanner = Map<String, dynamic>.from(convData['seenAddedBanner'] ?? {});
        for (var uid in _selectedUsers.keys) {
          seenAddedBanner[uid] = false; // New members need to see banner
        }

        // Update conversation
        await convRef.update({
          'participants': newParticipants,
          'participantDetails': newDetails,
          'seenAddedBanner': seenAddedBanner,
        });

        // 🆕 Post system message
        final addedBy = FirebaseAuth.instance.currentUser;
        if (addedBy != null) {
          final adderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(addedBy.uid)
              .get();
          final adderName = adderDoc.data()?['name'] ?? 'Someone';

          final memberNames = _selectedUsers.values.map((v) => v['name'] as String).join(', ');

          await convRef.collection('messages').add({
            'text': '$adderName added $memberNames',
            'sentBy': 'system',
            'sentByName': 'System',
            'sentAt': FieldValue.serverTimestamp(),
            'readBy': [],
            'isSystemMessage': true, // 🆕 Mark as system message
          });
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedUsers.length} ${_selectedUsers.length == 1 ? "member" : "members"} added',
            style: GoogleFonts.firaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color _getColorFromString(String str) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final hash = str.hashCode;
    return colors[hash % colors.length];
  }
}