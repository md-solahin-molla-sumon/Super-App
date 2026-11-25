
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

import '../models/story_model.dart';
import '../services/social_service.dart';

class StoryViewerPage extends StatefulWidget {
  final List<StoryModel> stories;

  const StoryViewerPage({
    super.key,
    required this.stories,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  static const int _storyDuration = 12;

  final SocialService _socialService = SocialService();

  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  Timer? _timer;

  int _currentIndex = 0;
  int _elapsedMilliseconds = 0;

  bool _isPaused = false;
  bool _isLoadingMedia = false;
  bool _isChangingStory = false;
  bool _isClosing = false;

  final Set<String> _pendingReactions = {};

  double get _progress =>
      (_elapsedMilliseconds / (_storyDuration * 1000))
          .clamp(0.0, 1.0);

  StoryModel get _currentStory => widget.stories[_currentIndex];

  static const Map<String, String> _reactionEmojis = {
    'like': '👍',
    'love': '❤️',
    'haha': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😡',
  };

  @override
  void initState() {
    super.initState();

    if (widget.stories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
      return;
    }

    _loadStory();
  }

  // =====================================================
  // STORY LOADING
  // =====================================================

  Future<void> _loadStory() async {
    _timer?.cancel();

    await _disposeMedia();

    if (!mounted) return;

    final story = _currentStory;

    setState(() {
      _elapsedMilliseconds = 0;
      _isPaused = false;
      _isLoadingMedia = true;
      _pendingReactions.clear();
    });

    try {
      await _socialService.markStoryViewed(story.storyId);
    } catch (e) {
      debugPrint('Story view update error: $e');
    }

    if (!mounted) return;

    // VIDEO
    if (story.mediaType == 'video' &&
        story.mediaUrl.isNotEmpty) {
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(story.mediaUrl),
        );

        _videoController = controller;

        await controller.initialize();

        if (!mounted) return;

        await controller.setLooping(true);
        await controller.play();
      } catch (e) {
        debugPrint('Story video error: $e');
      }
    }

    // AUDIO
    if (story.audioUrl.isNotEmpty) {
      try {
        final player = AudioPlayer();

        _audioPlayer = player;

        await player.setUrl(story.audioUrl);

        if (!mounted) return;

        // Do not await play().
        // Audio playback should not block the story timer.
        unawaited(
          player.play().catchError((Object error) {
            debugPrint('Story audio playback error: $error');
          }),
        );
      } catch (e) {
        debugPrint('Story audio loading error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoadingMedia = false;
    });

    _startTimer();
  }

  // =====================================================
  // STORY TIMER
  // =====================================================

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted || _isPaused || _isClosing) {
          return;
        }

        _elapsedMilliseconds += 100;

        if (_elapsedMilliseconds >= _storyDuration * 1000) {
          _nextStory();
          return;
        }

        setState(() {});
      },
    );
  }

  // =====================================================
  // MEDIA DISPOSAL
  // =====================================================

  Future<void> _disposeMedia() async {
    final video = _videoController;
    final audio = _audioPlayer;

    _videoController = null;
    _audioPlayer = null;

    if (video != null) {
      try {
        await video.pause();
        await video.dispose();
      } catch (e) {
        debugPrint('Video dispose error: $e');
      }
    }

    if (audio != null) {
      try {
        await audio.stop();
        await audio.dispose();
      } catch (e) {
        debugPrint('Audio dispose error: $e');
      }
    }
  }

  // =====================================================
  // NEXT / PREVIOUS STORY
  // =====================================================

  Future<void> _nextStory() async {
    if (_isChangingStory || _isClosing) return;

    _isChangingStory = true;

    try {
      if (_currentIndex < widget.stories.length - 1) {
        if (!mounted) return;

        setState(() {
          _currentIndex++;
        });

        await _loadStory();
      } else {
        await _closeViewer();
      }
    } finally {
      _isChangingStory = false;
    }
  }

  Future<void> _previousStory() async {
    if (_isChangingStory || _isClosing) return;

    // Do not reload the first story unnecessarily.
    if (_currentIndex == 0) return;

    _isChangingStory = true;

    try {
      if (!mounted) return;

      setState(() {
        _currentIndex--;
      });

      await _loadStory();
    } finally {
      _isChangingStory = false;
    }
  }

  // =====================================================
  // PAUSE / RESUME
  // =====================================================

  Future<void> _togglePause() async {
    if (!mounted || _isClosing) return;

    setState(() {
      _isPaused = !_isPaused;
    });

    try {
      if (_isPaused) {
        await _videoController?.pause();
        await _audioPlayer?.pause();
      } else {
        await _videoController?.play();

        final audio = _audioPlayer;

        if (audio != null) {
          unawaited(
            audio.play().catchError((Object error) {
              debugPrint('Audio resume error: $error');
            }),
          );
        }
      }
    } catch (e) {
      debugPrint('Story pause/resume error: $e');
    }
  }

  // =====================================================
  // CLOSE VIEWER
  // =====================================================

  Future<void> _closeViewer() async {
    if (_isClosing) return;

    _isClosing = true;

    _timer?.cancel();

    await _disposeMedia();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // =====================================================
  // MULTIPLE STORY REACTIONS
  // =====================================================

  Future<void> _handleReaction(String reaction) async {
    if (_pendingReactions.contains(reaction)) return;

    setState(() {
      _pendingReactions.add(reaction);
    });

    try {
      // Adds the reaction if absent.
      // Removes only this reaction if already selected.
      await _socialService.toggleStoryReaction(
        storyId: _currentStory.storyId,
        reaction: reaction,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reaction failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingReactions.remove(reaction);
        });
      }
    }
  }

  // =====================================================
  // REACTION USER INFORMATION
  // =====================================================

  Future<Map<String, dynamic>> _getReactionUser(
    String uid,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return snapshot.data() ?? <String, dynamic>{};
  }

  // =====================================================
  // SHOW REACTION USERS
  // =====================================================

  Future<void> _showReactionUsers() async {
    final storyId = _currentStory.storyId;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF20102F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const SizedBox(height: 15),

                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Story Reactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: _socialService.getStoryReactions(
                      storyId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Unable to load reactions',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No reactions yet',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      // Group multiple reactions by user.
                      final Map<String, List<String>>
                          groupedReactions = {};

                      for (final doc in docs) {
                        final data = doc.data();

                        final uid =
                            data['userId']?.toString() ?? '';

                        final reaction =
                            data['reaction']?.toString() ?? '';

                        if (uid.isEmpty ||
                            !_reactionEmojis.containsKey(reaction)) {
                          continue;
                        }

                        groupedReactions.putIfAbsent(
                          uid,
                          () => [],
                        );

                        if (!groupedReactions[uid]!
                            .contains(reaction)) {
                          groupedReactions[uid]!.add(reaction);
                        }
                      }

                      final users = groupedReactions.entries.toList();

                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'No reactions yet',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final entry = users[index];

                          return FutureBuilder<
                              Map<String, dynamic>>(
                            future: _getReactionUser(entry.key),
                            builder: (context, userSnapshot) {
                              final userData =
                                  userSnapshot.data ?? {};

                              final name =
                                  userData['name'] ??
                                  userData['userName'] ??
                                  'Nexaura User';

                              final photo =
                                  userData['photoUrl'] ??
                                  userData['photo'] ??
                                  '';

                              final emojis = entry.value
                                  .map(
                                    (reaction) =>
                                        _reactionEmojis[reaction]!,
                                  )
                                  .join(' ');

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.deepPurple,
                                  backgroundImage:
                                      photo.toString().isNotEmpty
                                          ? NetworkImage(
                                              photo.toString(),
                                            )
                                          : null,
                                  child: photo.toString().isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Text(
                                  emojis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // STORY CONTENT
  // =====================================================

  Color _storyBackground() {
    return Color(_currentStory.backgroundColor);
  }

  Widget _buildStoryContent() {
    final story = _currentStory;

    switch (story.mediaType) {
      case 'video':
        if (_videoController != null &&
            _videoController!.value.isInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio:
                  _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          );
        }

        return _buildLoadingOrError();

      case 'image':
      case 'image_audio':
        if (story.mediaUrl.isEmpty) {
          return _buildLoadingOrError();
        }

        return Center(
          child: Image.network(
            story.mediaUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildLoadingOrError();
            },
          ),
        );

      case 'audio':
        return _buildAudioStory();

      case 'text_audio':
      case 'text':
        return _buildTextStory();

      default:
        return _buildLoadingOrError();
    }
  }

  // =====================================================
  // AUDIO STORY
  // =====================================================

  Widget _buildAudioStory() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _storyBackground(),
            const Color(0xFF210078),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.graphic_eq,
              color: Colors.white,
              size: 100,
            ),

            const SizedBox(height: 20),

            const Text(
              'Audio Story',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Icon(
              _isPaused
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: Colors.white,
              size: 55,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TEXT STORY
  // =====================================================

  Widget _buildTextStory() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _storyBackground(),
            const Color(0xFF210078),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _currentStory.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white70,
        size: 65,
      ),
    );
  }

  // =====================================================
  // STORY PROGRESS
  // =====================================================

  Widget _buildProgressBars() {
    return Row(
      children: List.generate(
        widget.stories.length,
        (index) {
          double value;

          if (index < _currentIndex) {
            value = 1;
          } else if (index == _currentIndex) {
            value = _progress;
          } else {
            value = 0;
          }

          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // STORY HEADER
  // =====================================================

  Widget _buildHeader() {
    final story = _currentStory;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white24,
          backgroundImage: story.userPhoto.isNotEmpty
              ? NetworkImage(story.userPhoto)
              : null,
          child: story.userPhoto.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                )
              : null,
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            story.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        IconButton(
          onPressed: _togglePause,
          icon: Icon(
            _isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
          ),
        ),

        IconButton(
          onPressed: _closeViewer,
          icon: const Icon(
            Icons.close,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // MULTIPLE REACTION BAR
  // =====================================================

  Widget _buildReactionBar() {
    final storyId = _currentStory.storyId;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: StreamBuilder<Set<String>>(
        stream: _socialService.getMyStoryReactions(
          storyId,
        ),
        builder: (context, snapshot) {
          final myReactions = snapshot.data ?? <String>{};

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: _reactionEmojis.entries.map((entry) {
              final isSelected =
                  myReactions.contains(entry.key);

              final isPending =
                  _pendingReactions.contains(entry.key);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isPending
                    ? null
                    : () => _handleReaction(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurpleAccent.withValues(
                            alpha: 0.65,
                          )
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Colors.white,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isPending ? 0.4 : 1,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 25,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // =====================================================
  // REACTION COUNTS
  // =====================================================

  Widget _buildReactionCount() {
    return StreamBuilder<Map<String, int>>(
      stream: _socialService.getStoryReactionCounts(
        _currentStory.storyId,
      ),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? {};

        final total = counts.values.fold<int>(
          0,
          (totalCount, value) => totalCount + value,
        );

        if (total == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: _showReactionUsers,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('❤️'),
                const SizedBox(width: 5),
                Text(
                  '$total reactions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: _buildStoryContent(),
              ),
            ),

            // Story navigation touch area.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final width =
                      MediaQuery.of(context).size.width;

                  final dx = details.globalPosition.dx;

                  if (dx < width * 0.30) {
                    _previousStory();
                  } else if (dx > width * 0.70) {
                    _nextStory();
                  } else {
                    _togglePause();
                  }
                },
              ),
            ),

            // Header and progress.
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  _buildProgressBars(),
                  const SizedBox(height: 12),
                  _buildHeader(),
                ],
              ),
            ),

            // Reactions.
            Positioned(
              bottom: 25,
              left: 10,
              right: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReactionCount(),
                  const SizedBox(height: 12),
                  _buildReactionBar(),
                ],
              ),
            ),

            if (_isLoadingMedia)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            if (_isPaused && !_isLoadingMedia)
              const Center(
                child: Icon(
                  Icons.pause_circle_filled,
                  color: Colors.white70,
                  size: 75,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _timer?.cancel();

    _videoController?.dispose();
    _audioPlayer?.dispose();

    super.dispose();
  }
}
