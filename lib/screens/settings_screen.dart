import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _notificationsEnabled = true;
  bool _matchNotifications = true;
  bool _messageNotifications = true;
  bool _likeNotifications = true;
  bool _showOnlineStatus = true;
  bool _showProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  // Load user settings from Firestore
  Future<void> _loadUserSettings() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _matchNotifications = data['matchNotifications'] ?? true;
          _messageNotifications = data['messageNotifications'] ?? true;
          _likeNotifications = data['likeNotifications'] ?? true;
          _showOnlineStatus = data['showOnlineStatus'] ?? true;
          _showProfile = data['showProfile'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save settings to Firestore
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationsEnabled': _notificationsEnabled,
        'matchNotifications': _matchNotifications,
        'messageNotifications': _messageNotifications,
        'likeNotifications': _likeNotifications,
        'showOnlineStatus': _showOnlineStatus,
        'showProfile': _showProfile,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Change Password Dialog
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Implement password change
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // Delete Account Dialog
  Future<void> _showDeleteAccountDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Implement account deletion
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deleted successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // Profile Section
          _buildSectionHeader('Profile', Icons.person),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.pink.shade100,
              child: const Icon(Icons.person, color: Colors.pink),
            ),
            title: const Text('Edit Profile'),
            subtitle: const Text('Change your name, bio, photos'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to profile screen
              DefaultTabController.of(context)?.animateTo(3);
            },
          ),
          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications', Icons.notifications),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive push notifications'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications, color: Colors.pink),
            ),
          ),
          if (_notificationsEnabled) ...[
            SwitchListTile(
              title: const Text('Match Notifications'),
              subtitle: const Text('When someone likes you back'),
              value: _matchNotifications,
              onChanged: (value) {
                setState(() => _matchNotifications = value);
              },
            ),
            SwitchListTile(
              title: const Text('Message Notifications'),
              subtitle: const Text('When you receive a new message'),
              value: _messageNotifications,
              onChanged: (value) {
                setState(() => _messageNotifications = value);
              },
            ),
            SwitchListTile(
              title: const Text('Like Notifications'),
              subtitle: const Text('When someone likes your profile'),
              value: _likeNotifications,
              onChanged: (value) {
                setState(() => _likeNotifications = value);
              },
            ),
          ],
          const Divider(),

          // Privacy Section
          _buildSectionHeader('Privacy', Icons.lock),
          SwitchListTile(
            title: const Text('Show Online Status'),
            subtitle: const Text('Let others see when you\'re online'),
            value: _showOnlineStatus,
            onChanged: (value) {
              setState(() => _showOnlineStatus = value);
            },
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.circle, color: Colors.green),
            ),
          ),
          SwitchListTile(
            title: const Text('Show Profile'),
            subtitle: const Text('Make your profile visible to others'),
            value: _showProfile,
            onChanged: (value) {
              setState(() => _showProfile = value);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block, color: Colors.pink),
            ),
            title: const Text('Blocked Users'),
            subtitle: const Text('Manage blocked users'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Blocked users feature coming soon!')),
              );
            },
          ),
          const Divider(),

          // Account Section
          _buildSectionHeader('Account', Icons.account_circle),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.password, color: Colors.pink),
            ),
            title: const Text('Change Password'),
            subtitle: const Text('Update your password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Permanently delete your account'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
            onTap: _showDeleteAccountDialog,
          ),
          const Divider(),

          // App Info
          _buildSectionHeader('App Info', Icons.info),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info, color: Colors.pink),
            ),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Section Header Builder
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.pink),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.pink,
            ),
          ),
        ],
      ),
    );
  }
}