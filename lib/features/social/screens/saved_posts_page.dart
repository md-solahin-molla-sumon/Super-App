import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/social_service.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final SocialService _socialService = SocialService();

  final Color royalBlue = const Color(0xFF4169E1);

  Future<void> _unsavePost(String postId) async {
    try {
      await _socialService.toggleSavePost(postId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post removed from saved posts')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 85, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Saved Posts Yet!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts you save will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User information
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: royalBlue.withValues(alpha: 0.1),
                  backgroundImage: post.userPhoto.isNotEmpty
                      ? NetworkImage(post.userPhoto)
                      : null,
                  child: post.userPhoto.isEmpty
                      ? Icon(Icons.person, color: royalBlue)
                      : null,
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Unsave Post',
                  onPressed: () => _unsavePost(post.postId),
                  icon: const Icon(Icons.bookmark, color: Colors.orange),
                ),
              ],
            ),

            // Post content
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(post.content, style: const TextStyle(fontSize: 14)),
            ],

            // Post image
            if (post.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 45,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Likes information
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red.shade400, size: 18),
                const SizedBox(width: 5),
                Text(
                  '${post.likes.length} Likes',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Posts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: StreamBuilder<List<PostModel>>(
        stream: _socialService.getSavedPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: royalBlue));
          }

          final savedPosts = snapshot.data ?? [];

          if (savedPosts.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: savedPosts.length,
            itemBuilder: (context, index) {
              return _buildPostCard(savedPosts[index]);
            },
          );
        },
      ),
    );
  }
}
