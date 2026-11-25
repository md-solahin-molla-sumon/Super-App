
import 'package:flutter/material.dart';

import '../models/story_model.dart';
import '../services/social_service.dart';

class StorySection extends StatelessWidget {
  final VoidCallback onAddStory;
  final Function(List<StoryModel> stories) onStoryTap;

  StorySection({
    super.key,
    required this.onAddStory,
    required this.onStoryTap,
  });

  final SocialService _socialService = SocialService();

  static const Color _purpleStart = Color(0xFF6514E8);
  static const Color _purpleEnd = Color(0xFF3700A8);

  Map<String, List<StoryModel>> _groupStories(
    List<StoryModel> stories,
  ) {
    final Map<String, List<StoryModel>> grouped = {};

    for (final story in stories) {
      grouped.putIfAbsent(story.userId, () => []);
      grouped[story.userId]!.add(story);
    }

    for (final group in grouped.values) {
      group.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _socialService.currentUser?.uid;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF171326)
        : Colors.white;

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 12,
      ),
      child: StreamBuilder<List<StoryModel>>(
        stream: _socialService.getStories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox(
              height: 112,
              child: Center(
                child: Text(
                  'Unable to load stories',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 112,
              child: Center(
                child: SizedBox(
                  height: 23,
                  width: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _purpleStart,
                  ),
                ),
              ),
            );
          }

          final allStories = snapshot.data ?? [];
          final groupedStories = _groupStories(allStories);

          final myStories =
              groupedStories.remove(currentUserId) ?? [];

          final otherUserGroups =
              groupedStories.values.toList();

          otherUserGroups.sort((a, b) {
            return b.last.createdAt.compareTo(
              a.last.createdAt,
            );
          });

          return SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              children: [
                _buildMyStory(
                  myStories,
                ),
                ...otherUserGroups.map(
                  (userStories) => _buildUserStory(
                    userStories,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // MY STORY RECTANGLE CARD
  Widget _buildMyStory(
    List<StoryModel> myStories,
  ) {
    final hasStory = myStories.isNotEmpty;
    final latestStory = hasStory ? myStories.last : null;

    return GestureDetector(
      onTap: hasStory
          ? () => onStoryTap(myStories)
          : onAddStory,
      child: Container(
        width: 76,
        height: 108,
        margin: const EdgeInsets.only(right: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _purpleStart,
              _purpleEnd,
            ],
          ),
          border: Border.all(
            color: _purpleStart,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (latestStory != null &&
                  latestStory.userPhoto.isNotEmpty)
                Image.network(
                  latestStory.userPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _defaultBackground();
                  },
                )
              else
                _defaultBackground(),

              if (!hasStory)
                const Center(
                  child: Icon(
                    Icons.add_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

              // Bottom gradient
              _buildBottomGradient(),

              Positioned(
                left: 5,
                right: 5,
                bottom: 7,
                child: Text(
                  hasStory ? 'Your Story' : 'Add Story',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),

              if (!hasStory)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: _purpleStart,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // OTHER USERS RECTANGLE STORY CARD
  Widget _buildUserStory(
    List<StoryModel> stories,
  ) {
    final latestStory = stories.last;
    final currentUserId = _socialService.currentUser?.uid;

    final hasViewed = stories.every(
      (story) => story.isViewedBy(currentUserId ?? ''),
    );

    return GestureDetector(
      onTap: () => onStoryTap(stories),
      child: Container(
        width: 76,
        height: 108,
        margin: const EdgeInsets.only(right: 9),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: hasViewed
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFC107),
                    _purpleStart,
                    Color(0xFFE91E63),
                  ],
                ),
          color: hasViewed ? Colors.grey.shade400 : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (latestStory.userPhoto.isNotEmpty)
                Image.network(
                  latestStory.userPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _defaultBackground();
                  },
                )
              else
                _defaultBackground(),

              _buildBottomGradient(),

              Positioned(
                left: 4,
                right: 4,
                bottom: 7,
                child: Text(
                  latestStory.userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
          stops: [0.35, 0.72, 1.0],
        ),
      ),
    );
  }

  Widget _defaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6514E8),
            Color(0xFF210078),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}
