import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/social_service.dart';
import 'edit_profile_page.dart';
import 'follow_list_page.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  Widget _profileCount(
    BuildContext context,
    String title,
    int count,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _openFollowList(
    BuildContext context,
    String userId,
    bool showFollowers,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FollowListPage(userId: userId, showFollowers: showFollowers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final socialService = SocialService();

    const royalBlue = Color(0xFF4169E1);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view your profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(child: Text('Failed to load profile'));
          }

          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User profile not found'));
          }

          final userData = userSnapshot.data!.data()!;

          final name = userData['name'] ?? 'NEXAURA User';
          final email = userData['email'] ?? '';
          final bio = userData['bio'] ?? '';
          final photoUrl = userData['photoUrl'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: royalBlue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Profile Picture
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 65,
                                color: royalBlue,
                              )
                            : null,
                      ),

                      const SizedBox(height: 15),

                      // User Name
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Email
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bio
                      Text(
                        bio.isNotEmpty ? bio : 'No bio added yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Followers and Following
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StreamBuilder<int>(
                            stream: socialService.getFollowersCount(user.uid),
                            builder: (context, snapshot) {
                              return _profileCount(
                                context,
                                'Followers',
                                snapshot.data ?? 0,
                                () {
                                  _openFollowList(context, user.uid, true);
                                },
                              );
                            },
                          ),

                          const SizedBox(width: 30),

                          StreamBuilder<int>(
                            stream: socialService.getFollowingCount(user.uid),
                            builder: (context, snapshot) {
                              return _profileCount(
                                context,
                                'Following',
                                snapshot.data ?? 0,
                                () {
                                  _openFollowList(context, user.uid, false);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Edit Profile Button
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfilePage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // My Posts Heading
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'My Posts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                // My Posts List
                StreamBuilder<List<PostModel>>(
                  stream: socialService.getMyPosts(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('Failed to load posts')),
                      );
                    }

                    if (postSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final posts = postSnapshot.data ?? [];

                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(35),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.post_add,
                                size: 65,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No Posts Yet',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Your posts will appear here.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: royalBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: royalBlue,
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Text(
                                        post.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Text(
                                      '${post.likes.length} Likes',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                                if (post.content.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(post.content),
                                ],

                                if (post.imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      post.imageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const SizedBox(
                                              height: 150,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
