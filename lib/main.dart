import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'features/home/home_page.dart';
import 'features/auth/screens/login_page.dart';
import 'features/profile/services/profile_service.dart';
import 'features/profile/screens/profile_page.dart';
import 'features/social_connect/social_connect_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved theme preference
  await ThemeController.instance.loadTheme();

  runApp(const NexauraApp());
}

// =====================================================
// NEXAURA APP
// =====================================================

class NexauraApp extends StatelessWidget {
  const NexauraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'NEXAURA',
          debugShowCheckedModeBanner: false,

          // App Themes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,

          home: const AuthWrapper(),
        );
      },
    );
  }
}

// =====================================================
// AUTHENTICATION WRAPPER
// =====================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Authentication error: ${snapshot.error}',
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return UserProfileGate(user: user);
      },
    );
  }
}

// =====================================================
// USER PROFILE GATE
// =====================================================

class UserProfileGate extends StatefulWidget {
  final User user;

  const UserProfileGate({
    super.key,
    required this.user,
  });

  @override
  State<UserProfileGate> createState() =>
      _UserProfileGateState();
}

class _UserProfileGateState extends State<UserProfileGate> {
  late Future<void> _profileFuture;

  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _profileFuture = _ensureProfile();
  }

  Future<void> _ensureProfile() async {
    final profile = await _profileService.getUserProfile();

    if (!profile.exists) {
      await _profileService.createUserProfile(
        name: widget.user.displayName ??
            widget.user.email?.split('@').first ??
            'NEXAURA User',
        email: widget.user.email ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Profile loading failed!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _profileFuture = _ensureProfile();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const MainScreen();
      },
    );
  }
}

// =====================================================
// MAIN SCREEN
// =====================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<String> titles = [
    'NEXAURA',
    'Explore',
    'Messages',
    'Shopping',
    'Social Connect',
    'Profile',
  ];

  final List<IconData> icons = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.chat_rounded,
    Icons.shopping_bag_rounded,
    Icons.hub_rounded,
    Icons.person_rounded,
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final pages = [
          const HomePage(),
          const Center(child: Text('Explore')),
          const Center(child: Text('Messages')),
          const Center(child: Text('Shopping')),
          const SocialConnectPage(),
          const ProfilePage(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titles[selectedIndex],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                ),
              ),
              IconButton(
                onPressed: _logout,
                tooltip: 'Logout',
                icon: const Icon(
                  Icons.logout_rounded,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: List.generate(
                    titles.length,
                    (index) => NavigationRailDestination(
                      icon: Icon(icons[index]),
                      label: Text(titles[index]),
                    ),
                  ),
                ),

              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: pages,
                ),
              ),
            ],
          ),

          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  destinations: List.generate(
                    titles.length,
                    (index) => NavigationDestination(
                      icon: Icon(icons[index]),
                      label: titles[index],
                    ),
                  ),
                ),
        );
      },
    );
  }
}