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
          _showOnlineStatus = data['showOnlineStatus'] ?? true;
          _showProfile = data['showProfile'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      _showErrorSnackBar('Failed to load settings');
    }
  }

  // Save settings to Firestore
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'showOnlineStatus': _showOnlineStatus,
        'showProfile': _showProfile,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessSnackBar('Settings saved successfully!');
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save settings');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper method to show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Helper method to show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // 🔐 Password Change Function with Firebase Auth
  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate user first (required for sensitive operations)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);

      if (mounted) {
        _showSuccessSnackBar('Password changed successfully!');
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Password change failed';

      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'New password is too weak (min 6 characters)';
          break;
        case 'requires-recent-login':
          message = 'Please log in again to change password';
          break;
        default:
          message = 'Error: ${e.message}';
      }

      if (mounted) {
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Change Password Dialog with Validation
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Password
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm New Password
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm new password';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context); // Close dialog

                // Call password change function
                await _changePassword(
                  currentPassword: currentPasswordController.text.trim(),
                  newPassword: newPasswordController.text.trim(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  // Delete Account Dialog with Double Confirmation
  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _firstStepComplete = false;

    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 40,
              ),
              content: Container(
                width: double.maxFinite,
                child: !_firstStepComplete
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Are you absolutely sure? This action:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Cannot be undone'),
                    const Text('• Permanently removes all your data'),
                    const Text('• You will lose all matches and messages'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _firstStepComplete = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text('I Understand, Continue'),
                    ),
                  ],
                )
                    : Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Final Step',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your password to confirm account deletion:',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        autofocus: true,
                      ),
                    ],
                  ),
                ),
              ),
              actions: !_firstStepComplete
                  ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ]
                  : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context); // Close dialog
                      await _deleteAccount(passwordController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Account Function with Comprehensive Error Handling
  Future<void> _deleteAccount(String password) async {
    // Show loading dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Step 1: Re-authenticate before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Step 2: Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Step 3: Delete user from Firebase Auth
      await user.delete();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Step 4: Sign out
      await _auth.signOut();

      // Show success message (after navigation)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      String message = 'Account deletion failed';

      switch (e.code) {
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'requires-recent-login':
          message = 'For security, please log out and log in again before deleting your account.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Error: ${e.message}';
      }

      if (mounted) {
        _showErrorSnackBar(message);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred. Please try again.');
      }
    }
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
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
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
                  // Navigate to profile tab
                  DefaultTabController.of(context)?.animateTo(3);
                },
              ),
              const Divider(),

              // Privacy Section
              _buildSectionHeader('Privacy', Icons.lock),
              SwitchListTile(
                title: const Text('Show Online Status'),
                subtitle: const Text('Let others see when you\'re online'),
                value: _showOnlineStatus,
                onChanged: _isLoading ? null : (value) {
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
                onChanged: _isLoading ? null : (value) {
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
                    const SnackBar(
                      content: Text('Blocked users feature coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
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
                onTap: _isLoading ? null : _showChangePasswordDialog,
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
                onTap: _isLoading ? null : _showDeleteAccountDialog,
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
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha:0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
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