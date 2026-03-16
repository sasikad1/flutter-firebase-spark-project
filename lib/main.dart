import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Add this for provider
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/presence_service.dart';
import 'providers/theme_provider.dart'; // Add theme provider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    // Wrap with MultiProvider for theme management
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        PresenceService().setOnline(true);
        print('📱 App resumed - User online');
        break;
      case AppLifecycleState.paused:
        PresenceService().setOnline(false);
        print('📱 App paused - User offline');
        break;
      case AppLifecycleState.detached:
        PresenceService().setOnline(false);
        print('📱 App detached - User offline');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // Check if user has profile, if not create one
  Future<void> _checkAndCreateUserProfile(User user) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final docSnapshot = await firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        // Create new user profile with Google data
        final userData = {
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'profileImageUrl': user.photoURL ?? '',
          'bio': '',
          'homeTown': '',
          'country': '',
          'gender': null,
          'partnerGender': null,
          'birthDate': null,
          'interests': [],
          'showOnlineStatus': true,
          'showProfile': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        };

        await firestore.collection('users').doc(user.uid).set(userData);
        print('✅ New user profile created for ${user.email}');
      }
    } catch (e) {
      print('❌ Error checking/creating user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer to listen to theme changes
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Spark Dating App',
          // Light theme
          theme: themeProvider.getThemeData(false),
          // Dark theme
          darkTheme: themeProvider.getThemeData(true),
          // Theme mode based on user preference
          themeMode: themeProvider.currentTheme == AppTheme.system
              ? ThemeMode.system
              : themeProvider.currentTheme == AppTheme.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                final user = snapshot.data!;

                // Check/create profile when user logs in
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await _checkAndCreateUserProfile(user);
                  PresenceService().setOnline(true);
                  print('📱 User logged in - Online');
                });

                return const HomeScreen();
              }
              return const AuthScreen();
            },
          ),
        );
      },
    );
  }
}

// ==================== AUTH SCREEN WITH GOOGLE SIGN-IN ====================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLogin = true;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email/Password Sign In/Sign Up
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      } else if (e.code == 'user-not-found') {
        message = 'No user found with that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is badly formatted.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Google Sign-In Function
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Google Sign-In process
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await _auth.signInWithCredential(credential);

    } catch (e) {
      print('Google Sign-In Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme for dynamic colors
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with theme-aware color
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha:0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Title
                    Text(
                      _isLogin ? 'Welcome Back!' : 'Create Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLogin ? 'Sign in to continue' : 'Sign up to get started',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha:0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button (Email/Password)
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _isLogin ? 'Login' : 'Sign Up',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Login',
                              style: TextStyle(color: theme.colorScheme.primary),
                            ),
                          ),

                          // Divider
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: theme.dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha:0.5)),
                                  ),
                                ),
                                Expanded(child: Divider(color: theme.dividerColor)),
                              ],
                            ),
                          ),

                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface,
                                side: BorderSide(color: theme.dividerColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    child: const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Sign in with Google',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Note about Google Sign-In
                          Text(
                            'Sign in with your Google account',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha:0.5),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}