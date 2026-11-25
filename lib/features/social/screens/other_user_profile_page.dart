
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/social_service.dart';
import '../../chat/models/chat_model.dart';
import '../../chat/screens/chat_page.dart';
import '../../chat/services/chat_service.dart';
import 'follow_list_page.dart';

class OtherUserProfilePage extends StatelessWidget {
  final String userId;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
  });

  static const Color royalBlue = Color(0xFF4169E1);

  Widget _countItem(
    String title,
    int count,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFollowList(
    BuildContext context,
    bool showFollowers,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListPage(
          userId: userId,
          showFollowers: showFollowers,
        ),
      ),
    );
  }

  
Future<void> _openChat(
  BuildContext context, {
  required String receiverName,
  required String receiverPhoto,
}) async {
  try {
    final chatService = ChatService();

    // Step 1: Get or create chat ID.
    final String chatId =
        await chatService.getOrCreateChat(userId);

    // Step 2: Fetch chat document from Firestore.
    final chatSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();

    if (!chatSnapshot.exists || chatSnapshot.data() == null) {
      throw Exception('Chat could not be found');
    }

    // Step 3: Convert Firestore document into ChatModel.
    final ChatModel chat = ChatModel.fromMap(
      chatSnapshot.id,
      chatSnapshot.data()!,
    );

    if (!context.mounted) return;

    // Step 4: Open ChatPage.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chat: chat,
          receiverId: userId,
          receiverName: receiverName,
          receiverPhoto: receiverPhoto,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to open chat: $e'),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final socialService = SocialService();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login first'),
        ),
      );
    }

    if (currentUser.uid == userId) {
      return const Scaffold(
        body: Center(
          child: Text('This is your own profile'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load profile'),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('User profile not found'),
            );
          }

          final data = snapshot.data!.data()!;

          final String name =
              (data['name'] ?? 'NEXAURA User').toString();
          final String bio =
              (data['bio'] ?? '').toString();
          final String photoUrl =
              (data['photoUrl'] ?? '').toString();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: royalBlue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
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

                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        bio.isNotEmpty
                            ? bio
                            : 'No bio added yet',
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
                            stream: socialService
                                .getFollowersCount(userId),
                            builder: (context, countSnapshot) {
                              return _countItem(
                                'Followers',
                                countSnapshot.data ?? 0,
                                () {
                                  _openFollowList(context, true);
                                },
                              );
                            },
                          ),

                          const SizedBox(width: 30),

                          StreamBuilder<int>(
                            stream: socialService
                                .getFollowingCount(userId),
                            builder: (context, countSnapshot) {
                              return _countItem(
                                'Following',
                                countSnapshot.data ?? 0,
                                () {
                                  _openFollowList(context, false);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Follow / Unfollow and Message
                      StreamBuilder<bool>(
                        stream: socialService.isFollowing(userId),
                        builder: (context, followSnapshot) {
                          final isFollowing =
                              followSnapshot.data ?? false;

                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: 145,
                                child: ElevatedButton.icon(
                                  onPressed: followSnapshot
                                              .connectionState ==
                                          ConnectionState.waiting
                                      ? null
                                      : () async {
                                          try {
                                            await socialService
                                                .toggleFollow(userId);
                                          } catch (e) {
                                            if (!context.mounted) {
                                              return;
                                            }

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Follow action failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  icon: Icon(
                                    isFollowing
                                        ? Icons.person_remove
                                        : Icons.person_add,
                                  ),
                                  label: Text(
                                    isFollowing
                                        ? 'Unfollow'
                                        : 'Follow',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: royalBlue,
                                    disabledBackgroundColor:
                                        Colors.white70,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(
                                width: 145,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openChat(
                                      context,
                                      receiverName: name,
                                      receiverPhoto: photoUrl,
                                    );
                                  },
                                  icon: const Icon(Icons.message),
                                  label: const Text('Message'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: royalBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // User Posts
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, postSnapshot) {
                    if (postSnapshot.hasError) {
                      return const Center(
                        child: Text('Failed to load posts'),
                      );
                    }

                    if (postSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final posts = postSnapshot.data!.docs.map((doc) {
                      return PostModel.fromMap(doc.data());
                    }).toList();

                    posts.sort(
                      (a, b) => b.createdAt.compareTo(a.createdAt),
                    );

                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(35),
                        child: Center(
                          child: Text('No Posts Yet'),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                if (post.content.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(post.content),
                                ],

                                if (post.imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: Image.network(
                                      post.imageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 10),

                                Text(
                                  '${post.likes.length} Likes',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
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
