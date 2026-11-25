import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexaura/features/social/screens/social_feed_page.dart';
import 'package:nexaura/features/weather/screens/weather_page.dart';

import '../../shared/widgets/service_card.dart';
import '../profile/screens/profile_page.dart';
import '../calendar/screens/calendar_page.dart';
import '../tasks/screens/task_page.dart';
import '../notes/screens/notes_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  final List<Map<String, dynamic>> services = [
    {
      'title': 'Social',
      'subtitle': 'Posts, Stories & Friends',
      'icon': Icons.people_alt_rounded,
      'color': Colors.purpleAccent,
    },
    {
      'title': 'Shopping',
      'subtitle': 'Products & Orders',
      'icon': Icons.shopping_bag_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'title': 'AI Assistant',
      'subtitle': 'Smart AI Support',
      'icon': Icons.smart_toy_rounded,
      'color': Colors.greenAccent,
    },
    {
      'title': 'Profile',
      'subtitle': 'Your Account',
      'icon': Icons.person_rounded,
      'color': Colors.pinkAccent,
    },
    {
      'title': 'Weather',
      'subtitle': 'Weather Updates',
      'icon': Icons.cloud_rounded,
      'color': Colors.lightBlueAccent,
    },
    {
      'title': 'Utilities',
      'subtitle': 'Daily Tools',
      'icon': Icons.grid_view_rounded,
      'color': Colors.amberAccent,
    },
    {
      'title': 'Google Browser',
      'subtitle': 'Search the Web',
      'icon': Icons.language_rounded,
      'color': Colors.blueAccent,
    },
    {
      'title': 'Calendar',
      'subtitle': 'Events & Schedule',
      'icon': Icons.calendar_month_rounded,
      'color': Colors.tealAccent,
    },
    {
      'title': 'To-Do & Tasks',
      'subtitle': 'Manage Your Tasks',
      'icon': Icons.task_alt_rounded,
      'color': Colors.deepOrangeAccent,
    },
    {
      'title': 'Quick Notes',
      'subtitle': 'Save Your Ideas',
      'icon': Icons.note_alt_rounded,
      'color': Colors.yellowAccent,
    },
    {
      'title': 'News & Updates',
      'subtitle': 'Latest News',
      'icon': Icons.newspaper_rounded,
      'color': Colors.cyanAccent,
    },
    {
      'title': 'Maps & Location',
      'subtitle': 'Explore Places',
      'icon': Icons.location_on_rounded,
      'color': Colors.redAccent,
    },
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Open the original Google Chrome app on Android.
  // If Chrome is unavailable, fall back to the default browser.
  Future<void> _openGoogleChrome() async {
    const googleUrl = 'https://www.google.com';

    if (!kIsWeb) {
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: googleUrl,
          package: 'com.android.chrome',
        );

        await intent.launch();
        return;
      } catch (_) {
        // Chrome unavailable or native intent unsupported.
        // Continue with the default browser fallback.
      }
    }

    try {
      final uri = Uri.parse(googleUrl);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open browser.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Browser.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openService(String title) {
    switch (title) {
      case 'Social':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SocialFeedPage(),
          ),
        );
        break;

      case 'Profile':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('My Profile')),
              body: const ProfilePage(),
            ),
          ),
        );
        break;

      case 'Weather':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeatherPage(),
          ),
        );
        break;

      case 'Calendar':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CalendarPage(),
          ),
        );
        break;

      case 'To-Do & Tasks':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TaskPage(),
          ),
        );
        break;

      case 'Quick Notes':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotesPage(),
          ),
        );
        break;

      case 'Google Browser':
        _openGoogleChrome();
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$title module is coming in the next development steps.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = services.where((service) {
      return service['title'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6741D9),
                  Color(0xFF302078),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME TO NEXAURA',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Your Digital World,\nOne App.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Everything you need in one place.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // Search Bar
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search services...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFF1B1D2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Section Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Explore Services',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${filteredServices.length} Services",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          // Service Grid
          LayoutBuilder(
            builder: (context, constraints) {
              int columns;

              if (constraints.maxWidth >= 1000) {
                columns = 4;
              } else if (constraints.maxWidth >= 600) {
                columns = 3;
              } else {
                columns = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredServices.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final service = filteredServices[index];

                  return ServiceCard(
                    title: service['title'],
                    subtitle: service['subtitle'],
                    icon: service['icon'],
                    color: service['color'],
                    onTap: () {
                      _openService(
                        service['title'].toString(),
                      );
                    },
                  );
                },
              );
            },
          ),

          if (filteredServices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: Text('No services found.'),
              ),
            ),

          const SizedBox(height: 30),

          // AI Assistant Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D2A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.purpleAccent,
                  size: 35,
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXAURA AI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your intelligent digital companion.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}