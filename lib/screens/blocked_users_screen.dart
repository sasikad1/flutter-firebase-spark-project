import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _auth = FirebaseAuth.instance;
  final _blockService = BlockService();
  bool _isLoading = false;

  Future<void> _unblockUser(String userId, String userName) async {
    setState(() => _isLoading = true);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _blockService.unblockUser(userId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User unblocked successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please login again'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: _blockService.getBlockedUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final blockedUsers = snapshot.data ?? [];

          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No blocked users',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users you block will appear here',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final user = blockedUsers[index];
              final timestamp = user['timestamp'] as Timestamp?;
              final blockedDate = timestamp?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: user['profileImageUrl'] != null
                        ? NetworkImage(user['profileImageUrl'])
                        : null,
                    backgroundColor: Colors.pink.shade100,
                    child: user['profileImageUrl'] == null
                        ? const Icon(Icons.person, color: Colors.pink)
                        : null,
                  ),
                  title: Text(
                    user['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: blockedDate != null
                      ? Text('Blocked ${_getTimeAgo(blockedDate)}')
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.pink),
                    onPressed: () => _unblockUser(user['userId'], user['name']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}