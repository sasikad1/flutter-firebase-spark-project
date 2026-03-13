import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/block_service.dart';
import '../services/presence_service.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String otherUserId;
  final Map<String, dynamic> otherUserData;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherUserId,
    required this.otherUserData,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _blockService = BlockService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    final isBlocked = await _blockService.isUserBlocked(widget.otherUserId);
    if (mounted) {
      setState(() {
        _isBlocked = isBlocked;
      });
    }
  }

  Future<void> _blockUser() async {
    final userName = widget.otherUserData['name'] ?? 'this user';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.block, color: Colors.red, size: 40),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Block User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Are you sure you want to block $userName?'),
            const SizedBox(height: 8),
            const Text(
              'They will not be able to send you messages and the chat will be deleted.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _blockService.blockUser(widget.otherUserId);
      if (success && mounted) {
        setState(() { _isBlocked = true; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to block user'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send messages to blocked user'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_messageController.text.trim().isEmpty) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await _firestore
          .collection('chats')
          .doc(widget.matchId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      await _firestore.collection('matches').doc(widget.matchId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.otherUserData['name'] ?? 'User';
    final otherUserPhoto = widget.otherUserData['profileImageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Profile picture with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                  backgroundColor: Colors.pink.shade100,
                  child: otherUserPhoto == null ? const Icon(Icons.person, size: 20, color: Colors.pink) : null,
                ),
                // ✅ Online status indicator (respects privacy)
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('users').doc(widget.otherUserId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();

                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final isOnline = data?['isOnline'] ?? false;
                    final showOnlineStatus = data?['showOnlineStatus'] ?? true; // Get privacy setting

                    // Don't show dot if user disabled online status
                    if (!showOnlineStatus) return const SizedBox();

                    return Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),

            // User name and online status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Online/Offline/Last seen text (respects privacy)
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('users').doc(widget.otherUserId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      final isOnline = data?['isOnline'] ?? false;
                      final lastSeen = data?['lastSeen'] as Timestamp?;
                      final showOnlineStatus = data?['showOnlineStatus'] ?? true;

                      // Don't show any status if user disabled it
                      if (!showOnlineStatus) {
                        return const SizedBox();
                      }

                      return Text(
                        isOnline ? 'Online' : PresenceService().getLastSeenText(lastSeen),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          if (!_isBlocked)
            IconButton(
              icon: const Icon(Icons.block),
              onPressed: _isLoading ? null : _blockUser,
              tooltip: 'Block User',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_isBlocked)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have blocked $otherUserName. Unblock to send messages.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.matchId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Say hi! 👋', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == _auth.currentUser?.uid;
                    return _buildMessageBubble(messageData, isMe);
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.grey.shade200.withValues(alpha:0.5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isBlocked,
                    decoration: InputDecoration(
                      hintText: _isBlocked ? 'Cannot send messages' : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isBlocked
                          ? Colors.grey.shade200
                          : (Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade100
                          : const Color(0xFF2C2C2C)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isBlocked ? Colors.grey : Colors.pink,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isBlocked ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isMe) {
    final text = messageData['text'] ?? '';
    final timestamp = messageData['timestamp'] != null
        ? (messageData['timestamp'] as Timestamp).toDate()
        : null;

    String timeString = '';
    if (timestamp != null) {
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      if (difference.inDays > 0) {
        timeString = DateFormat('MMM d').format(timestamp);
      } else if (difference.inHours > 0) {
        timeString = '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        timeString = '${difference.inMinutes}m';
      } else {
        timeString = 'now';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.pink : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    timeString,
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}