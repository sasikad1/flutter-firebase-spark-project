import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const ProfileDetailsScreen({
    super.key,
    required this.userData,
    required this.userId,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _hasLiked = false;
  bool _hasPassed = false;

  @override
  void initState() {
    super.initState();
    _checkUserInteraction();
  }

  // Check if current user already liked/passed this profile
  Future<void> _checkUserInteraction() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Check for like
      final likeDoc = await _firestore
          .collection('likes')
          .doc('${currentUserId}_${widget.userId}')
          .get();

      if (likeDoc.exists) {
        setState(() {
          _hasLiked = true;
        });
        return;
      }

      // Check for pass
      final passDoc = await _firestore
          .collection('passes')
          .doc('${currentUserId}_${widget.userId}')
          .get();

      if (passDoc.exists) {
        setState(() {
          _hasPassed = true;
        });
      }
    } catch (e) {
      print('Error checking interaction: $e');
    }
  }

  // Like function
  Future<void> _likeUser() async {
    setState(() => _isLoading = true);

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Add to likes collection
      await _firestore
          .collection('likes')
          .doc('${currentUserId}_${widget.userId}')
          .set({
        'fromUserId': currentUserId,
        'toUserId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Check if it's a match (other user already liked current user)
      final otherLikeDoc = await _firestore
          .collection('likes')
          .doc('${widget.userId}_$currentUserId')
          .get();

      if (otherLikeDoc.exists) {
        // It's a match! Create match document
        await _firestore.collection('matches').add({
          'users': [currentUserId, widget.userId],
          'timestamp': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("It's a match! ❤️"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _hasLiked = true;
        _hasPassed = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liked!'),
            backgroundColor: Colors.pink,
          ),
        );
      }

    } catch (e) {
      print('Error liking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Pass function
  Future<void> _passUser() async {
    setState(() => _isLoading = true);

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Add to passes collection
      await _firestore
          .collection('passes')
          .doc('${currentUserId}_${widget.userId}')
          .set({
        'fromUserId': currentUserId,
        'toUserId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasPassed = true;
        _hasLiked = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passed'),
            backgroundColor: Colors.grey,
          ),
        );

        // Go back to discovery page after pass
        Navigator.pop(context);
      }

    } catch (e) {
      print('Error passing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name'] ?? 'Unknown';
    final bio = widget.userData['bio'] ?? 'No bio available';
    final homeTown = widget.userData['homeTown'] ?? '';
    final country = widget.userData['country'] ?? '';
    final gender = widget.userData['gender'] ?? 'Not specified';
    final partnerGender = widget.userData['partnerGender'] ?? 'Not specified';
    final birthDate = widget.userData['birthDate'] != null
        ? (widget.userData['birthDate'] as Timestamp).toDate()
        : null;
    final interests = widget.userData['interests'] as List<dynamic>? ?? [];
    final profileImageUrl = widget.userData['profileImageUrl'];

    // Age calculate කරන්න
    String age = '';
    if (birthDate != null) {
      final now = DateTime.now();
      final difference = now.difference(birthDate);
      age = '${(difference.inDays / 365).floor()}';
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          // App Bar with image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                age.isNotEmpty ? '$name, $age' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                ),
              ),
              background: profileImageUrl != null
                  ? Image.network(
                profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.pink.shade100,
                    child: Center(
                      child: Icon(Icons.person, size: 80, color: Colors.pink.shade300),
                    ),
                  );
                },
              )
                  : Container(
                color: Colors.pink.shade100,
                child: Center(
                  child: Icon(Icons.person, size: 80, color: Colors.pink.shade300),
                ),
              ),
            ),
          ),

          // Profile Details
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Bio
                _buildSection(
                  title: 'About Me',
                  content: bio,
                  icon: Icons.description,
                ),
                const SizedBox(height: 20),

                // Basic Info Grid
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.location_on, 'Location',
                            homeTown.isNotEmpty ? '$homeTown, $country' : country),
                        _buildInfoRow(Icons.people, 'Gender', gender),
                        _buildInfoRow(Icons.favorite, 'Interested in', partnerGender),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Interests
                if (interests.isNotEmpty)
                  _buildInterestsSection(interests),
                const SizedBox(height: 20),

                // Action Buttons (Like/Pass)
                if (!_hasLiked && !_hasPassed)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _likeUser,
                          icon: const Icon(Icons.favorite),
                          label: const Text('Like'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _passUser,
                          icon: const Icon(Icons.close),
                          label: const Text('Pass'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_hasLiked)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Colors.pink),
                          SizedBox(width: 8),
                          Text(
                            'You liked this profile',
                            style: TextStyle(color: Colors.pink),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_hasPassed)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'You passed this profile',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Section Builder
  Widget _buildSection({required String title, required String content, required IconData icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.pink),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // Info Row Builder
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.pink.shade300),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // Interests Section
  Widget _buildInterestsSection(List<dynamic> interests) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.interests, color: Colors.pink),
                SizedBox(width: 8),
                Text(
                  'Interests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}