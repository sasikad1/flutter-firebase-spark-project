import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_details_screen.dart';
import '../services/block_service.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _blockService = BlockService();

  String? _selectedGender;
  RangeValues _ageRange = const RangeValues(18, 50);
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final blockedIds = await _blockService.getBlockedUserIdsSet();
    if (mounted) {
      setState(() {
        _blockedUserIds = blockedIds;
      });
    }
  }

  Future<Set<String>> _getLikedAndPassedUserIds(String currentUserId) async {
    final Set<String> userIds = {};

    try {
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();

      for (var doc in likesSnapshot.docs) {
        final data = doc.data();
        userIds.add(data['toUserId']);
      }

      final passesSnapshot = await _firestore
          .collection('passes')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();

      for (var doc in passesSnapshot.docs) {
        final data = doc.data();
        userIds.add(data['toUserId']);
      }
    } catch (e) {
      print('Error getting interacted users: $e');
    }

    return userIds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .where('name', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];
          final currentUserId = _auth.currentUser?.uid;

          if (currentUserId == null) {
            return const Center(child: Text('Please login again'));
          }

          // Filter out users who have showProfile = false
          final visibleUsers = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final showProfile = data['showProfile'] ?? true;
            return showProfile == true;
          }).toList();

          // Current userව filter කරන්න
          final otherUsers = visibleUsers.where((doc) => doc.id != currentUserId).toList();

          if (otherUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later!',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<Set<String>>(
            future: _getLikedAndPassedUserIds(currentUserId),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final interactedUserIds = futureSnapshot.data ?? {};

              // Filter out users that current user already liked, passed, or blocked
              final availableUsers = otherUsers
                  .where((doc) => !interactedUserIds.contains(doc.id))
                  .where((doc) => !_blockedUserIds.contains(doc.id))
                  .toList();

              if (availableUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sentiment_satisfied, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No more profiles',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later!',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Apply gender filter
              var filteredUsers = availableUsers;
              if (_selectedGender != null) {
                filteredUsers = filteredUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['gender'] == _selectedGender;
                }).toList();
              }

              // Apply age filter
              filteredUsers = filteredUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final birthDate = data['birthDate'] != null
                    ? (data['birthDate'] as Timestamp).toDate()
                    : null;

                if (birthDate == null) return false;

                final now = DateTime.now();
                final age = now.difference(birthDate).inDays ~/ 365;

                return age >= _ageRange.start && age <= _ageRange.end;
              }).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _loadBlockedUsers();
                  });
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredUsers[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    return _buildUserCard(userData, userDoc.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ User Card Builder - Verified Badge Bottom Right
  Widget _buildUserCard(Map<String, dynamic> userData, String userId) {
    final name = userData['name'] ?? 'Unknown';
    final bio = userData['bio'] ?? '';
    final country = userData['country'] ?? '';
    final birthDate = userData['birthDate'] != null
        ? (userData['birthDate'] as Timestamp).toDate()
        : null;
    final emailVerified = userData['emailVerified'] ?? false; // Verified status

    final isOnline = userData['isOnline'] ?? false;
    final showOnlineStatus = userData['showOnlineStatus'] ?? true;

    String age = '';
    if (birthDate != null) {
      final now = DateTime.now();
      final difference = now.difference(birthDate);
      age = '${(difference.inDays / 365).floor()}';
    }

    final profileImageUrl = userData['profileImageUrl'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileDetailsScreen(
              userData: userData,
              userId: userId,
            ),
          ),
        ).then((_) {
          _loadBlockedUsers();
        });
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image Section
            Expanded(
              child: Stack(
                children: [
                  // Profile Image
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      image: profileImageUrl != null
                          ? DecorationImage(
                        image: NetworkImage(profileImageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.grey.shade200,
                    ),
                    child: profileImageUrl == null
                        ? Center(
                      child: Icon(Icons.person, size: 50, color: Colors.grey.shade400),
                    )
                        : null,
                  ),

                  // ✅ Online Status Dot (Top Right)
                  if (showOnlineStatus)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // User Info Section
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Age
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          age.isNotEmpty ? '$name, $age' : name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Location
                  if (country.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            country,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  // Bio
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // ✅ Verified Badge (Bottom Right)
                  if (emailVerified)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 12, color: Colors.blue),
                            SizedBox(width: 2),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter Dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Gender'),
                  value: _selectedGender,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Non-binary', child: Text('Non-binary')),
                    DropdownMenuItem(value: 'Prefer not to say', child: Text('Not specified')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                Text('Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}'),
                RangeSlider(
                  values: _ageRange,
                  min: 18,
                  max: 80,
                  divisions: 62,
                  labels: RangeLabels(
                    _ageRange.start.round().toString(),
                    _ageRange.end.round().toString(),
                  ),
                  onChanged: (values) {
                    setState(() {
                      _ageRange = values;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedGender = null;
                    _ageRange = const RangeValues(18, 50);
                  });
                  Navigator.pop(context);
                  this.setState(() {});
                },
                child: const Text('Clear'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  this.setState(() {});
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}