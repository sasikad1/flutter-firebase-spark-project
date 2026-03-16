import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'blocked_users_screen.dart';
import '../providers/theme_provider.dart';

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
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _checkEmailVerification();
  }

  // Check email verification status
  void _checkEmailVerification() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isEmailVerified = user.emailVerified;
      });
    }
  }

  // Send verification email
  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Check and update verification status
  Future<void> _checkVerificationStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = _auth.currentUser;
      if (updatedUser != null && updatedUser.emailVerified != _isEmailVerified) {
        setState(() {
          _isEmailVerified = updatedUser.emailVerified;
        });

        if (_isEmailVerified) {
          await _firestore.collection('users').doc(user.uid).update({
            'emailVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status: Not verified yet'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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

  // 🌙 Theme selection dialog
  Future<void> _showThemeDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Light Mode'),
              leading: const Icon(Icons.light_mode),
              selected: themeProvider.currentTheme == AppTheme.light,
              selectedTileColor: Colors.pink.shade50,
              onTap: () {
                themeProvider.setTheme(AppTheme.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Dark Mode'),
              leading: const Icon(Icons.dark_mode),
              selected: themeProvider.currentTheme == AppTheme.dark,
              selectedTileColor: Colors.pink.shade50,
              onTap: () {
                themeProvider.setTheme(AppTheme.dark);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('System Default'),
              leading: const Icon(Icons.settings),
              selected: themeProvider.currentTheme == AppTheme.system,
              selectedTileColor: Colors.pink.shade50,
              onTap: () {
                themeProvider.setTheme(AppTheme.system);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🔐 Password Change Function
  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
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
      if (mounted) _showErrorSnackBar(message);
    } catch (e) {
      if (mounted) _showErrorSnackBar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Change Password Dialog
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
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter current password';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter new password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm new password';
                    if (value != newPasswordController.text) return 'Passwords do not match';
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
                Navigator.pop(context);
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

  // Delete Account Dialog
  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _firstStepComplete = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      onPressed: () => setState(() => _firstStepComplete = true),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Enter your password to confirm account deletion:'),
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
                          if (value == null || value.isEmpty) return 'Please enter your password';
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
                      Navigator.pop(context);
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

  // Delete Account Function
  Future<void> _deleteAccount(String password) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();

      if (mounted) Navigator.pop(context);
      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      String message = 'Account deletion failed';
      switch (e.code) {
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'requires-recent-login':
          message = 'Please log in again to delete your account.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      if (mounted) _showErrorSnackBar(message);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showErrorSnackBar('An unexpected error occurred.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
                  DefaultTabController.of(context)?.animateTo(3);
                },
              ),
              const Divider(),

              // 🌙 Appearance Section (Theme)
              _buildSectionHeader('Appearance', Icons.palette),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Icon(
                        themeProvider.currentTheme == AppTheme.light
                            ? Icons.light_mode
                            : themeProvider.currentTheme == AppTheme.dark
                            ? Icons.dark_mode
                            : Icons.settings,
                        color: Colors.pink,
                      );
                    },
                  ),
                ),
                title: const Text('Theme'),
                subtitle: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Text(
                      themeProvider.currentTheme == AppTheme.light
                          ? 'Light Mode'
                          : themeProvider.currentTheme == AppTheme.dark
                          ? 'Dark Mode'
                          : 'System Default',
                    );
                  },
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showThemeDialog,
              ),
              const Divider(),

              // ✅ UPDATED: Account Security Section with Verification UI
              _buildSectionHeader('Account Security', Icons.security),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isEmailVerified ? Colors.green.shade50 : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEmailVerified ? Icons.verified : Icons.warning,
                    color: _isEmailVerified ? Colors.green : Colors.orange,
                  ),
                ),
                title: Row(
                  children: [
                    const Text('Email Verification'),
                    const SizedBox(width: 8),
                    if (_isEmailVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  _isEmailVerified
                      ? 'Your email is verified ✓'
                      : 'Verify your email to secure your account and get a verified badge',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Refresh button to check verification status
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _checkVerificationStatus,
                      tooltip: 'Check verification status',
                    ),
                    if (!_isEmailVerified)
                      TextButton(
                        onPressed: _sendVerificationEmail,
                        child: const Text('Verify', style: TextStyle(color: Colors.blue)),
                      ),
                  ],
                ),
              ),
              const Divider(),

              // Privacy Section
              _buildSectionHeader('Privacy', Icons.lock),
              SwitchListTile(
                title: const Text('Show Online Status'),
                subtitle: const Text('Let others see when you\'re online'),
                value: _showOnlineStatus,
                onChanged: _isLoading ? null : (value) => setState(() => _showOnlineStatus = value),
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
                onChanged: _isLoading ? null : (value) => setState(() => _showProfile = value),
              ),

              // Blocked Users
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
                subtitle: const Text('Manage users you have blocked'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
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
              child: const Center(child: CircularProgressIndicator()),
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