
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/module_theme.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../services/social_service.dart';
import '../widgets/story_section.dart';
import 'comment_page.dart';
import 'create_post_page.dart';
import 'create_story_page.dart';
import 'story_viewer_page.dart';
import 'saved_posts_page.dart';
import 'user_profile_page.dart';
import 'other_user_profile_page.dart';
import 'notification_page.dart';
import '../../chat/screens/chat_list_page.dart';

class SocialFeedPage extends StatefulWidget {
  final String? initialPostId;

  const SocialFeedPage({super.key, this.initialPostId});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

enum _MoreAction {
  liveStream,
  createPost,
  createStory,
  savedPosts,
}

enum _PostAction {
  edit,
  delete,
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final SocialService _socialService = SocialService();

  static const Color _likeColor = Color(0xFFEF4444);
  static const Color _savedColor = Color(0xFFF59E0B);

  static const Color _purpleStart = Color(0xFF6514E8);
  static const Color _purpleMiddle = Color(0xFF3700A8);
  static const Color _purpleEnd = Color(0xFF210078);
  static const Color _purpleAccent = Color(0xFF8B35FF);

  // =========================================================
  // PROFILE, CHAT AND NOTIFICATION NAVIGATION
  // =========================================================

  void _openProfile(String userId) {
    final currentUserId = _socialService.currentUser?.uid;

    if (currentUserId == userId) {
      _openUserProfile();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(userId: userId),
      ),
    );
  }

  void _openChats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatListPage()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationPage()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature is coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // MORE MENU ACTIONS
  // =========================================================

  void _handleMoreAction(_MoreAction action) {
    switch (action) {
      case _MoreAction.liveStream:
        _showComingSoon('Live Stream');
        break;

      case _MoreAction.createPost:
        _openCreatePost();
        break;

      case _MoreAction.createStory:
        _openCreateStory();
        break;

      case _MoreAction.savedPosts:
        _openSavedPosts();
        break;
    }
  }

  // =========================================================
  // STORY NAVIGATION
  // =========================================================

  Future<void> _openCreateStory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateStoryPage(),
      ),
    );
  }

  Future<void> _openStoryViewer(List<StoryModel> stories) async {
    final activeStories = stories
        .where((story) => !story.isExpired)
        .toList();

    if (activeStories.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active stories available.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: activeStories,
        ),
      ),
    );
  }

  // =========================================================
  // POST ACTIONS
  // =========================================================

  Future<void> _toggleLike(String postId) async {
    try {
      await _socialService.toggleLike(postId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like failed: $e')),
      );
    }
  }

  Future<void> _toggleSavePost(String postId) async {
    try {
      await _socialService.toggleSavePost(postId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark updated successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookmark failed: $e')),
      );
    }
  }

  Future<void> _sharePost(PostModel post) async {
    try {
      final String shareText = '''
${post.userName} shared a post on Nexaura:

${post.content}

${post.imageUrl.isNotEmpty ? post.imageUrl : ''}

Join Nexaura and connect with others!
''';

      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Post from Nexaura',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _editPost(PostModel post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(post: post),
      ),
    );
  }

  Future<void> _deletePost(PostModel post) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete Post?'),
          content: const Text(
            'Are you sure you want to delete this post? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _socialService.deletePost(post.postId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete post: $e'),
        ),
      );
    }
  }

  Widget _buildPostOptions(
    PostModel post,
    Color secondaryText,
  ) {
    final currentUserId = _socialService.currentUser?.uid;

    if (currentUserId == null || currentUserId != post.userId) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_PostAction>(
      tooltip: 'Post Options',
      icon: Icon(Icons.more_horiz, color: secondaryText),
      color: const Color(0xFF2B1160),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (action) {
        switch (action) {
          case _PostAction.edit:
            _editPost(post);
            break;

          case _PostAction.delete:
            _deletePost(post);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<_PostAction>(
          value: _PostAction.edit,
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: Color(0xFFC4A2FF),
                size: 21,
              ),
              SizedBox(width: 10),
              Text(
                'Edit Post',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuItem<_PostAction>(
          value: _PostAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 21,
              ),
              SizedBox(width: 10),
              Text(
                'Delete Post',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) return 'Just now';

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

  // =========================================================
  // PAGE NAVIGATION
  // =========================================================

  Future<void> _openCreatePost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostPage(),
      ),
    );
  }

  void _openSavedPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedPostsPage(),
      ),
    );
  }

  void _openUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserProfilePage(),
      ),
    );
  }

  // =========================================================
  // SD LOGO
  // =========================================================

  Widget _buildSDLogo(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'S',
            style: TextStyle(
              fontSize: size * 0.92,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
              shadows: const [
                Shadow(
                  color: Color(0xFF9C65FF),
                  blurRadius: 8,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
          Positioned(
            right: -1,
            child: Text(
              'D',
              style: TextStyle(
                fontSize: size * 0.72,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFB98AFF),
                height: 1,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.38,
            child: Container(
              width: size * 1.05,
              height: size * 0.16,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandAction({
    required bool compact,
    required double logoSize,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildSDLogo(logoSize),
                SizedBox(width: compact ? 2 : 5),
                Flexible(
                  child: Text(
                    'NEXAURA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 7.5 : 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: compact ? 0 : 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 4 : 5,
            horizontal: 1,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 27 : 35,
                height: compact ? 27 : 35,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: compact ? 17 : 21,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu({bool compact = false}) {
    return Expanded(
      child: PopupMenuButton<_MoreAction>(
        tooltip: 'More Options',
        onSelected: _handleMoreAction,
        color: const Color(0xFF2B1160),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        offset: const Offset(0, 10),
        itemBuilder: (context) => [
          _buildPopupItem(
            value: _MoreAction.liveStream,
            icon: Icons.live_tv_rounded,
            title: 'Live Stream',
          ),
          _buildPopupItem(
            value: _MoreAction.createPost,
            icon: Icons.post_add_rounded,
            title: 'Create Post / Feed',
          ),
          _buildPopupItem(
            value: _MoreAction.createStory,
            icon: Icons.add_circle_outline_rounded,
            title: 'Create Story',
          ),
          const PopupMenuDivider(),
          _buildPopupItem(
            value: _MoreAction.savedPosts,
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved Posts',
          ),
        ],
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 4 : 5,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 27 : 35,
                  height: compact ? 27 : 35,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: compact ? 20 : 24,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'More',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_MoreAction> _buildPopupItem({
    required _MoreAction value,
    required IconData icon,
    required String title,
  }) {
    return PopupMenuItem<_MoreAction>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFC4A2FF),
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationAction() {
    return Expanded(
      child: StreamBuilder<int>(
        stream: _socialService.getUnreadNotificationCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return IconButton(
            tooltip: 'Notifications',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 25,
              minHeight: 36,
            ),
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -8,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3030),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99
                            ? '99+'
                            : unreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageAction() {
    return Expanded(
      child: IconButton(
        tooltip: 'Messages',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 25,
          minHeight: 36,
        ),
        onPressed: _openChats,
        icon: const Icon(
          Icons.messenger_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildProfileAction() {
    return Expanded(
      child: IconButton(
        tooltip: 'My Profile',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 25,
          minHeight: 36,
        ),
        onPressed: _openUserProfile,
        icon: const Icon(
          Icons.account_circle_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // =========================================================
  // SOCIAL APP BAR
  // =========================================================

  PreferredSizeWidget _buildSocialAppBar(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 700;
    final logoSize = compact ? 19.0 : 34.0;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      backgroundColor: _purpleEnd,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: _purpleEnd,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _purpleStart,
              _purpleMiddle,
              _purpleEnd,
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -55,
              bottom: -85,
              child: Container(
                width: 175,
                height: 175,
                decoration: BoxDecoration(
                  color: _purpleAccent.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -70,
              top: -110,
              child: Container(
                width: 210,
                height: 180,
                decoration: BoxDecoration(
                  color: _purpleAccent.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildBrandAction(
            compact: compact,
            logoSize: logoSize,
          ),
          _buildHeaderAction(
            icon: Icons.movie_creation_outlined,
            label: 'Reels',
            compact: compact,
            onTap: () => _showComingSoon('Reels'),
          ),
          _buildHeaderAction(
            icon: Icons.people_alt_rounded,
            label: 'Find Friends',
            compact: compact,
            onTap: () => _showComingSoon('Find Friends'),
          ),
          _buildNotificationAction(),
          _buildMessageAction(),
          _buildMoreMenu(compact: compact),
          _buildProfileAction(),
        ],
      ),
      actions: const [],
    );
  }

  // =========================================================
  // EMPTY FEED
  // =========================================================

  Widget _buildEmptyFeed({
    required bool isSpecificPost,
    required Color primary,
    required Color textColor,
    required Color secondaryText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSpecificPost
                  ? Icons.article_outlined
                  : Icons.dynamic_feed_rounded,
              size: 65,
              color: primary,
            ),
            const SizedBox(height: 15),
            Text(
              isSpecificPost ? 'Post Not Found' : 'No Posts Yet!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSpecificPost
                  ? 'This post may have been deleted.'
                  : 'Be the first to share something.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // POST ACTION BUTTON
  // =========================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // POST IMAGE
  // =========================================================

  Widget _buildPostImage({
    required String imageUrl,
    required bool isDark,
    required Color secondaryText,
  }) {
    return Container(
      width: double.infinity,
      color: isDark
          ? const Color(0xFF171326)
          : const Color(0xFFF1EDF7),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        alignment: Alignment.center,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? const Color(0xFFC4A2FF)
                    : const Color(0xFF6514E8),
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 38,
                    color: secondaryText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load image',
                    style: TextStyle(color: secondaryText),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // POST CARD
  // =========================================================

  Widget _buildPostCard({
    required PostModel post,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color secondaryText,
    required Color primary,
    required Color accent,
    required String? currentUserId,
  }) {
    final isLiked = currentUserId != null &&
        post.likes.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      elevation: isDark ? 0 : 1,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _openProfile(post.userId),
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: primary,
                    backgroundImage: post.userPhoto.isNotEmpty
                        ? NetworkImage(post.userPhoto)
                        : null,
                    child: post.userPhoto.isEmpty
                        ? Text(
                            post.userName.isNotEmpty
                                ? post.userName[0].toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openProfile(post.userId),
                        child: Text(
                          post.userName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPostOptions(post, secondaryText),
              ],
            ),
          ),

          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                post.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),

          if (post.imageUrl.isNotEmpty)
            _buildPostImage(
              imageUrl: post.imageUrl,
              isDark: isDark,
              secondaryText: secondaryText,
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Column(
              children: [
                Divider(
                  color: isDark
                      ? const Color(0xFF49365F)
                      : accent,
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: 'Like (${post.likes.length})',
                      color: isLiked ? _likeColor : primary,
                      onTap: () => _toggleLike(post.postId),
                    ),
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      label: 'Comment',
                      color: primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentPage(
                              postId: post.postId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: primary,
                      onTap: () => _sharePost(post),
                    ),
                    Expanded(
                      child: StreamBuilder<List<String>>(
                        stream: _socialService.getSavedPostIds(),
                        builder: (context, savedSnapshot) {
                          final isSaved = savedSnapshot.data
                                  ?.contains(post.postId) ??
                              false;

                          return _buildActionButton(
                            icon: isSaved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: isSaved ? 'Saved' : 'Save',
                            color: isSaved ? _savedColor : primary,
                            onTap: () => _toggleSavePost(post.postId),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAIN BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final palette = ModulePalette.forModule(ModuleType.social);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF171326)
        : palette.background;

    final cardColor = isDark
        ? const Color(0xFF261E38)
        : palette.surface;

    final textColor = isDark
        ? const Color(0xFFF5F3FF)
        : const Color(0xFF24143D);

    final secondaryText = isDark
        ? const Color(0xFFBDB4CC)
        : const Color(0xFF777083);

    final primary = palette.primary;
    final currentUserId = _socialService.currentUser?.uid;
    final isSpecificPost = widget.initialPostId != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildSocialAppBar(context),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        tooltip: 'Create Post',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: _socialService.getPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                StorySection(
                  onAddStory: _openCreateStory,
                  onStoryTap: _openStoryViewer,
                ),
                SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                StorySection(
                  onAddStory: _openCreateStory,
                  onStoryTap: _openStoryViewer,
                ),
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'Error loading posts: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ),
              ],
            );
          }

          final posts = snapshot.data ?? [];

          final visiblePosts = widget.initialPostId == null
              ? posts
              : posts
                  .where(
                    (post) => post.postId == widget.initialPostId,
                  )
                  .toList();

          if (visiblePosts.isEmpty) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                StorySection(
                  onAddStory: _openCreateStory,
                  onStoryTap: _openStoryViewer,
                ),
                SizedBox(
                  height: 300,
                  child: _buildEmptyFeed(
                    isSpecificPost: isSpecificPost,
                    primary: primary,
                    textColor: textColor,
                    secondaryText: secondaryText,
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: visiblePosts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return StorySection(
                  onAddStory: _openCreateStory,
                  onStoryTap: _openStoryViewer,
                );
              }

              final post = visiblePosts[index - 1];

              return _buildPostCard(
                post: post,
                isDark: isDark,
                cardColor: cardColor,
                textColor: textColor,
                secondaryText: secondaryText,
                primary: primary,
                accent: palette.accent,
                currentUserId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}
