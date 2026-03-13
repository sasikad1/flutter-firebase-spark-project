import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'discovery_screen.dart';
import 'matches_screen.dart'; // මේක add කරන්න

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return DefaultTabController(
      length: 4, // Home, Discover, Matches, Profile tabs 4ක්
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spark'),
          toolbarHeight: 70,
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(50.0),
            child: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true, // tabs ගොඩක් නිසා scrollable කරන්න
              tabs: [
                Tab(icon: Icon(Icons.home), text: 'Home'),
                Tab(icon: Icon(Icons.people), text: 'Discover'),
                Tab(icon: Icon(Icons.favorite), text: 'Matches'), // අලුත් tab එක
                Tab(icon: Icon(Icons.person), text: 'Profile'),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Home Tab
            _buildHomeTab(context, user),

            // Discover Tab
            const DiscoveryScreen(),

            // Matches Tab
            const MatchesScreen(),

            // Profile Tab
            const ProfileScreen(),
          ],
        ),
      ),
    );
  }

  // Home Tab Content
  Widget _buildHomeTab(BuildContext context, User user) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite,
            size: 100,
            color: Colors.pink,
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to Spark!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Logged in as:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            user.email ?? 'No email',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Discover tab එකට යන්න
              DefaultTabController.of(context).animateTo(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Discover People',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}