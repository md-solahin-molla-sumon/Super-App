
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../../settings/settings_page.dart';
import '../../social/services/social_service.dart';
import '../../social/models/post_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  final SocialService _socialService = SocialService();

  late Future<dynamic> _profileFuture;

  static const Color navy = Color(0xFF101D36);
  static const Color royalBlue = Color(0xFF1D3557);
  static const Color gold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = _profileService.getUserProfile();
  }

  Future<void> _editProfile(String name, String bio) async {
    final nameController = TextEditingController(text: name);
    final bioController = TextEditingController(text: bio);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: navy,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    try {
      if (result == true) {
        if (nameController.text.trim().isEmpty) {
          throw Exception('Name cannot be empty');
        }

        await _profileService.updateUserProfile(
          name: nameController.text.trim(),
          bio: bioController.text.trim(),
        );

        if (!mounted) return;

        setState(_loadProfile);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      nameController.dispose();
      bioController.dispose();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  // ==========================================
  // PROFILE STATISTICS - DYNAMIC FIREBASE DATA
  // ==========================================

  Widget _buildStatistics({
    required String? userId,
    required Color surfaceColor,
    required Color textColor,
  }) {
    if (userId == null) {
      return Row(
        children: [
          _statCard('Posts', '0', surfaceColor, textColor),
          const SizedBox(width: 10),
          _statCard('Followers', '0', surfaceColor, textColor),
          const SizedBox(width: 10),
          _statCard('Following', '0', surfaceColor, textColor),
        ],
      );
    }

    return StreamBuilder<List<PostModel>>(
      stream: _socialService.getMyPosts(),
      builder: (context, postSnapshot) {
        final postsCount = postSnapshot.hasError
            ? '—'
            : postSnapshot.connectionState == ConnectionState.waiting
                ? '...'
                : (postSnapshot.data?.length ?? 0).toString();

        return StreamBuilder<int>(
          stream: _socialService.getFollowersCount(userId),
          builder: (context, followersSnapshot) {
            final followersCount = followersSnapshot.hasError
                ? '—'
                : followersSnapshot.connectionState ==
                        ConnectionState.waiting
                    ? '...'
                    : (followersSnapshot.data ?? 0).toString();

            return StreamBuilder<int>(
              stream: _socialService.getFollowingCount(userId),
              builder: (context, followingSnapshot) {
                final followingCount = followingSnapshot.hasError
                    ? '—'
                    : followingSnapshot.connectionState ==
                            ConnectionState.waiting
                        ? '...'
                        : (followingSnapshot.data ?? 0).toString();

                return Row(
                  children: [
                    _statCard(
                      'Posts',
                      postsCount,
                      surfaceColor,
                      textColor,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Followers',
                      followersCount,
                      surfaceColor,
                      textColor,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Following',
                      followingCount,
                      surfaceColor,
                      textColor,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.cardColor;
    final textColor = colors.onSurface;
    final secondaryTextColor = colors.onSurfaceVariant;

    return Container(
      color: backgroundColor,
      child: FutureBuilder<dynamic>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: royalBlue,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load profile'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(_loadProfile);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Profile not found'),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          final name = data['name']?.toString() ?? 'NEXAURA User';
          final email = data['email']?.toString() ?? '';
          final bio = data['bio']?.toString() ?? '';
          final photoUrl = data['photoUrl']?.toString() ?? '';

          final userId = _socialService.currentUser?.uid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // PROFILE HEADER

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    24,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [navy, royalBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 53,
                        backgroundColor: gold,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'N',
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: navy,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'NEXAURA MEMBER',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // DYNAMIC PROFILE STATISTICS

                _buildStatistics(
                  userId: userId,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                ),

                const SizedBox(height: 20),

                // ABOUT ME

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: navy.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Me',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        bio.isEmpty
                            ? 'No bio added yet.'
                            : bio,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // EDIT PROFILE BUTTON

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _editProfile(name, bio),
                    icon: const Icon(Icons.edit),
                    label: const Text('EDIT PROFILE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // PROFILE MENU

                _menuItem(
                  Icons.shopping_bag_outlined,
                  'My Orders',
                  surfaceColor,
                  textColor,
                  secondaryTextColor,
                ),

                _menuItem(
                  Icons.settings_outlined,
                  'Settings',
                  surfaceColor,
                  textColor,
                  secondaryTextColor,
                  onTap: _openSettings,
                ),

                _menuItem(
                  Icons.help_outline,
                  'Help & Support',
                  surfaceColor,
                  textColor,
                  secondaryTextColor,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // STATISTICS CARD
  // ==========================================

  Widget _statCard(
    String title,
    String value,
    Color surfaceColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: royalBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PROFILE MENU ITEM
  // ==========================================

  Widget _menuItem(
    IconData icon,
    String title,
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor, {
    VoidCallback? onTap,
  }) {
    return Card(
      color: surfaceColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: royalBlue,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: secondaryTextColor,
        ),
      ),
    );
  }
}
