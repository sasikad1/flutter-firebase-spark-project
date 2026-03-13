import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  // Block a user
  Future<bool> blockUser(String blockedUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      // Check if already blocked
      final existingBlock = await _firestore
          .collection('blocks')
          .doc('${currentUserId}_$blockedUserId')
          .get();

      if (existingBlock.exists) {
        return false; // Already blocked
      }

      // Create block document
      await _firestore
          .collection('blocks')
          .doc('${currentUserId}_$blockedUserId')
          .set({
        'blockerId': currentUserId,
        'blockedId': blockedUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'blocked',
      });

      // Optionally delete any existing matches
      await _deleteMatchIfExists(currentUserId, blockedUserId);

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  // Unblock a user
  Future<bool> unblockUser(String blockedUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      await _firestore
          .collection('blocks')
          .doc('${currentUserId}_$blockedUserId')
          .delete();
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('blocks')
          .doc('${currentUserId}_$otherUserId')
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking block status: $e');
      return false;
    }
  }

  // Get all blocked users IDs for current user
  Future<List<String>> getBlockedUserIds() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .get();

      return snapshot.docs.map((doc) => doc['blockedId'] as String).toList();
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  // Get blocked users with details
  Stream<List<Map<String, dynamic>>> getBlockedUsers() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> blockedUsers = [];

      for (var doc in snapshot.docs) {
        final blockedId = doc['blockedId'] as String;

        // Get user details
        final userDoc = await _firestore.collection('users').doc(blockedId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          blockedUsers.add({
            'userId': blockedId,
            'name': userData['name'] ?? 'Unknown',
            'profileImageUrl': userData['profileImageUrl'],
            'timestamp': doc['timestamp'],
          });
        }
      }

      return blockedUsers;
    });
  }

  // Delete match if exists (optional)
  Future<void> _deleteMatchIfExists(String userId1, String userId2) async {
    try {
      // Find match where both users are in the users array
      final matchSnapshot = await _firestore
          .collection('matches')
          .where('users', arrayContains: userId1)
          .get();

      for (var doc in matchSnapshot.docs) {
        final users = doc['users'] as List;
        if (users.contains(userId2)) {
          await doc.reference.delete();
          break;
        }
      }
    } catch (e) {
      print('Error deleting match: $e');
    }
  }

  // Get blocked users IDs as Set for efficient filtering
  Future<Set<String>> getBlockedUserIdsSet() async {
    final list = await getBlockedUserIds();
    return Set.from(list);
  }
}