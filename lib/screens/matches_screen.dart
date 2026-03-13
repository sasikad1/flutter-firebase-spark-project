import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'profile_details_screen.dart'; // Full profile screen (විකල්පය)

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Please login again'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('matches')
            .where('users', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Error handling
          if (snapshot.hasError) {
            print('Error in matches stream: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // No matches
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No matches yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start liking profiles to get matches!',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Go to Discover tab
                      DefaultTabController.of(context)?.animateTo(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Discover People'),
                  ),
                ],
              ),
            );
          }

          final matches = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final matchData = matches[index].data() as Map<String, dynamic>;
              final matchId = matches[index].id;

              // Get the other user's ID
              final otherUserId = (matchData['users'] as List)
                  .firstWhere((id) => id != currentUserId);

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  // Handle user data loading
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey,
                          child: CircularProgressIndicator(),
                        ),
                        title: Text('Loading...'),
                      ),
                    );
                  }

                  // Handle user data error
                  if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink(); // Don't show if user data missing
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final lastMessage = matchData['lastMessage'] ?? 'Say hi! 👋';
                  final lastMessageTime = matchData['lastMessageTime'] != null
                      ? (matchData['lastMessageTime'] as Timestamp).toDate()
                      : null;

                  return _buildMatchCard(
                    matchId: matchId,
                    userId: otherUserId,
                    userData: userData,
                    lastMessage: lastMessage,
                    lastMessageTime: lastMessageTime,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Match Card Builder - Single tap -> Chat, Long press -> Profile Dialog
  Widget _buildMatchCard({
    required String matchId,
    required String userId,
    required Map<String, dynamic> userData,
    required String lastMessage,
    DateTime? lastMessageTime,
  }) {
    final name = userData['name'] ?? 'Unknown';
    final profileImageUrl = userData['profileImageUrl'];

    // Time format
    String timeString = '';
    if (lastMessageTime != null) {
      final now = DateTime.now();
      final difference = now.difference(lastMessageTime);

      if (difference.inDays > 0) {
        timeString = '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        timeString = '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        timeString = '${difference.inMinutes}m';
      } else {
        timeString = 'now';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Single tap -> Chat screen
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                matchId: matchId,
                otherUserId: userId,
                otherUserData: userData,
              ),
            ),
          );
        },
        // Long press -> Profile dialog
        onLongPress: () {
          _showProfileDialog(context, userData);
        },
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            radius: 30,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl)
                : null,
            backgroundColor: Colors.pink.shade100,
            child: profileImageUrl == null
                ? const Icon(Icons.person, color: Colors.pink)
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (timeString.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    timeString,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              // Long press indicator (optional)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.pink.shade200,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show profile in a dialog
  void _showProfileDialog(BuildContext context, Map<String, dynamic> userData) {
    final name = userData['name'] ?? 'Unknown';
    final bio = userData['bio'] ?? 'No bio available';
    final homeTown = userData['homeTown'] ?? '';
    final country = userData['country'] ?? '';
    final profileImageUrl = userData['profileImageUrl'];
    final birthDate = userData['birthDate'] != null
        ? (userData['birthDate'] as Timestamp).toDate()
        : null;
    final interests = userData['interests'] as List<dynamic>? ?? [];

    // Age calculate
    String age = '';
    if (birthDate != null) {
      final now = DateTime.now();
      final difference = now.difference(birthDate);
      age = '${(difference.inDays / 365).floor()}';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with image
              Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      image: profileImageUrl != null
                          ? DecorationImage(
                        image: NetworkImage(profileImageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.pink.shade100,
                    ),
                    child: profileImageUrl == null
                        ? Center(
                      child: Icon(Icons.person, size: 80, color: Colors.pink.shade300),
                    )
                        : null,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Age
                      Text(
                        age.isNotEmpty ? '$name, $age' : name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Location
                      if (homeTown.isNotEmpty || country.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.pink.shade300),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                homeTown.isNotEmpty && country.isNotEmpty
                                    ? '$homeTown, $country'
                                    : homeTown.isNotEmpty
                                    ? homeTown
                                    : country,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Bio
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(bio),
                      ],

                      // Interests
                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Interests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests.map((interest) {
                            return Chip(
                              label: Text(interest.toString()),
                              backgroundColor: Colors.pink.shade50,
                              labelStyle: const TextStyle(color: Colors.pink),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Go to Chat button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            // TODO: Navigate to chat (you'll need matchId and userId)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Navigate to chat from dialog')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Go to Chat'),
                        ),
                      ),
                    ],
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