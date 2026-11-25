import 'package:flutter/material.dart';

import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../../profile/services/profile_service.dart';

class CommentPage extends StatefulWidget {
  final String postId;

  const CommentPage({super.key, required this.postId});

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final CommentService _commentService = CommentService();
  final ProfileService _profileService = ProfileService();

  final TextEditingController _commentController = TextEditingController();

  late Future<dynamic> _profileFuture;

  bool _isSending = false;

  static const Color navy = Color(0xFF101D36);
  static const Color royalBlue = Color(0xFF1D3557);
  static const Color gold = Color(0xFFD4AF37);
  static const Color softWhite = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getUserProfile();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Send Comment
  Future<void> _sendComment(String userName, String userPhoto) async {
    final content = _commentController.text.trim();

    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _commentService.addComment(
        postId: widget.postId,
        content: content,
        userName: userName,
        userPhoto: userPhoto,
      );

      _commentController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Delete Comment
  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _commentService.deleteComment(
        postId: widget.postId,
        commentId: commentId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // Format Comment Date
  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: royalBlue)),
          );
        }

        if (profileSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comments')),
            body: Center(
              child: Text('Unable to load profile: ${profileSnapshot.error}'),
            ),
          );
        }

        final profileData = profileSnapshot.data?.data() ?? <String, dynamic>{};

        final userName = profileData['name']?.toString() ?? 'NEXAURA User';

        final userPhoto = profileData['photoUrl']?.toString() ?? '';

        final currentUserId = _commentService.currentUser?.uid;

        return Scaffold(
          backgroundColor: softWhite,

          appBar: AppBar(
            title: const Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: navy,
            iconTheme: const IconThemeData(color: Colors.white),
          ),

          body: Column(
            children: [
              // Comments List
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: _commentService.getComments(widget.postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: royalBlue),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading comments: ${snapshot.error}',
                        ),
                      );
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: royalBlue,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No Comments Yet!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Be the first to comment.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];

                        final isMyComment =
                            currentUserId != null &&
                            comment.userId == currentUserId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: royalBlue,
                                  backgroundImage: comment.userPhoto.isNotEmpty
                                      ? NetworkImage(comment.userPhoto)
                                      : null,
                                  child: comment.userPhoto.isEmpty
                                      ? Text(
                                          comment.userName.isNotEmpty
                                              ? comment.userName[0]
                                                    .toUpperCase()
                                              : 'N',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: navy,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment.content,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        _formatDate(comment.createdAt),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (isMyComment)
                                  IconButton(
                                    onPressed: () {
                                      _deleteComment(comment.commentId);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 21,
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
              ),

              // Comment Input
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // User Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: gold,
                        backgroundImage: userPhoto.isNotEmpty
                            ? NetworkImage(userPhoto)
                            : null,
                        child: userPhoto.isEmpty
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'N',
                                style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(width: 10),

                      // Comment TextField
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _commentController,
                            enabled: !_isSending,
                            minLines: 1,
                            maxLines: 1,
                            cursorColor: royalBlue,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFE8EDF5),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Send Button
                      IconButton(
                        onPressed: _isSending
                            ? null
                            : () => _sendComment(userName, userPhoto),
                        icon: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: royalBlue,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: royalBlue,
                                size: 27,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
