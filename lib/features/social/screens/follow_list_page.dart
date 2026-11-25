import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';
import 'other_user_profile_page.dart';

class FollowListPage extends StatelessWidget {
  final String userId;
  final bool showFollowers;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  static const Color royalBlue = Color(0xFF4169E1);

  static final SocialService _socialService = SocialService();

  void _openProfile(BuildContext context, String targetUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == targetUserId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This is your own profile')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(userId: targetUserId),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, String targetUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFFE8EEFF),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: royalBlue,
              ),
            ),
            title: Text('Loading...', style: TextStyle(color: Colors.black87)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;

        final name = data['name'] ?? 'Nexaura User';
        final photoUrl = data['photoUrl'] ?? '';

        final isOwnAccount = currentUserId == targetUserId;

        return Container(
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 7,
            ),

            leading: GestureDetector(
              onTap: () => _openProfile(context, targetUserId),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE8EEFF),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'N',
                        style: const TextStyle(
                          color: royalBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),

            title: GestureDetector(
              onTap: () => _openProfile(context, targetUserId),
              child: Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF172B4D),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            trailing: isOwnAccount
                ? const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : StreamBuilder<bool>(
                    stream: _socialService.isFollowing(targetUserId),
                    builder: (context, followSnapshot) {
                      final isFollowing = followSnapshot.data ?? false;

                      return ElevatedButton(
                        onPressed:
                            followSnapshot.connectionState ==
                                ConnectionState.waiting
                            ? null
                            : () async {
                                try {
                                  await _socialService.toggleFollow(
                                    targetUserId,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Action failed: $e'),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? const Color(0xFFE9EDF2)
                              : royalBlue,
                          foregroundColor: isFollowing
                              ? const Color(0xFF344054)
                              : Colors.white,
                          disabledBackgroundColor: const Color(0xFFE9EDF2),
                          disabledForegroundColor: Colors.grey,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(isFollowing ? 'Following' : 'Follow'),
                      );
                    },
                  ),

            onTap: () => _openProfile(context, targetUserId),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = showFollowers ? 'followers' : 'following';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          showFollowers ? 'Followers' : 'Following',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(collectionName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: royalBlue),
            );
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showFollowers
                        ? Icons.people_outline
                        : Icons.person_add_alt_1,
                    size: 65,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    showFollowers
                        ? 'No Followers Yet'
                        : 'Not Following Anyone Yet',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: users.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 5);
            },
            itemBuilder: (context, index) {
              final targetUserId = users[index].id;

              return Card(
                color: Colors.white,
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildUserTile(context, targetUserId),
              );
            },
          );
        },
      ),
    );
  }
}
