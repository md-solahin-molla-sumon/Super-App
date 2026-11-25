
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final String currentUserId;
  final Future<void> Function(MessageModel message, bool forBoth)? onUnsend;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onUnsend,
  });

  static const Color navy = Color(0xFF14213D);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color receivedColor = Color(0xFFF1F5F9);

  bool get isMe => message.senderId == currentUserId;

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : navy;

    return GestureDetector(
      onLongPress: () => _showMessageActions(context),
      child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? royalBlue : receivedColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessageContent(context, textColor),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.blueGrey.shade500,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 15,
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    if (onUnsend == null || message.isDeletedForBoth) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Message options',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (message.messageType == 'text' && message.message.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_rounded, color: royalBlue),
                    title: const Text('Copy message'),
                    onTap: () => Navigator.pop(sheetContext, 'copy'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded, color: navy),
                  title: const Text('Unsend for me'),
                  onTap: () => Navigator.pop(sheetContext, 'me'),
                ),
                if (isMe)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Unsend for everyone',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'both'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (choice == 'me') {
      await onUnsend!(message, false);
    } else if (choice == 'both') {
      await onUnsend!(message, true);
    }
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    if (message.isDeletedForBoth) {
      return Text('This message was deleted',
        style: TextStyle(color: textColor.withAlpha(190), fontStyle: FontStyle.italic));
    }
    switch (message.messageType) {
      case 'image':
        return _buildImage(context);

      case 'audio':
        return AudioMessagePlayer(
          audioUrl: message.audioUrl,
          audioDurationMs: message.audioDurationMs,
          isMe: isMe,
        );

      case 'video':
        return _buildVideo();

      case 'document':
        return _buildDocument(textColor);

      case 'location':
        return _buildLocation(textColor);

      default:
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            message.message,
            style: TextStyle(color: textColor, fontSize: 15),
          ),
        );
    }
  }

  // IMAGE MESSAGE
  Widget _buildImage(BuildContext context) {
    if (message.imageUrl.isEmpty) {
      return const Icon(Icons.broken_image);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: message.imageUrl,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.network(
              message.imageUrl,
              width: 210,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;

                return const SizedBox(
                  width: 210,
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  width: 210,
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image)),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 25,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VIDEO MESSAGE
  Widget _buildVideo() {
    if (message.videoUrl.isEmpty) {
      return const Text('Video unavailable');
    }

    return VideoMessagePlayer(videoUrl: message.videoUrl);
  }

  // DOCUMENT MESSAGE
  Widget _buildDocument(Color textColor) {
    if (message.documentUrl.isEmpty) {
      return Text(
        'Document unavailable',
        style: TextStyle(color: textColor),
      );
    }

    final size = message.documentSize;
    final sizeText = size >= 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(2)} MB'
        : '${(size / 1024).toStringAsFixed(1)} KB';

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            color: textColor,
            size: 35,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.documentName.isEmpty
                      ? 'Document'
                      : message.documentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sizeText,
                  style: TextStyle(
                    color: textColor.withAlpha(180),
                    fontSize: 11,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openUrl(message.documentUrl),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('Open Document'),
                  style: TextButton.styleFrom(
                    foregroundColor: textColor,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // LOCATION MESSAGE
  Widget _buildLocation(Color textColor) {
    final latitude = message.latitude;
    final longitude = message.longitude;

    if (latitude == null || longitude == null) {
      return Text(
        'Location unavailable',
        style: TextStyle(color: textColor),
      );
    }

    final mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: textColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.isLiveLocation
                      ? 'Live Location'
                      : 'Shared Location',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (message.isLiveLocation && message.liveLocationActive)
                const Icon(
                  Icons.circle,
                  color: Colors.red,
                  size: 10,
                ),
            ],
          ),
          if (message.locationName.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              message.locationName,
              style: TextStyle(color: textColor),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
            style: TextStyle(
              color: textColor.withAlpha(190),
              fontSize: 11,
            ),
          ),
          if (message.isLiveLocation) ...[
            const SizedBox(height: 5),
            Text(
              message.liveLocationActive
                  ? 'Live sharing active'
                  : 'Live sharing ended',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message.locationUpdatedAt != null)
              Text(
                'Updated: ${_formatTime(message.locationUpdatedAt)}',
                style: TextStyle(
                  color: textColor.withAlpha(180),
                  fontSize: 10,
                ),
              ),
          ],
          const SizedBox(height: 5),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              mapUrl,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Open in Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: textColor.withAlpha(120)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.hasScheme) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

// =====================================================
// FULL SCREEN IMAGE VIEWER
// =====================================================

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Image Viewer'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 60,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =====================================================
// VIDEO MESSAGE PLAYER
// =====================================================

class VideoMessagePlayer extends StatefulWidget {
  final String videoUrl;

  const VideoMessagePlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoMessagePlayer> createState() =>
      _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  late final VideoPlayerController _controller;

  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;

    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero);
      }

      await _controller.play();
    }
  }

  Future<void> _openFullScreen() async {
    if (!_controller.value.isInitialized) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoViewer(
          controller: _controller,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox(
        width: 220,
        height: 120,
        child: Center(
          child: Icon(Icons.error_outline, size: 35),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 220,
        height: 130,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      width: 220,
      child: Column(
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                if (!_controller.value.isPlaying)
                  const Icon(
                    Icons.play_circle_fill,
                    size: 55,
                    color: Colors.white,
                  ),
                const Positioned(
                  right: 7,
                  bottom: 7,
                  child: Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 27,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _togglePlayback,
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Full Screen',
                onPressed: _openFullScreen,
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(value.position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FULL SCREEN VIDEO VIEWER
// =====================================================

class FullScreenVideoViewer extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoViewer({
    super.key,
    required this.controller,
  });

  @override
  State<FullScreenVideoViewer> createState() =>
      _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  bool _showControls = true;

  VideoPlayerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    _controller.play();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero);
      }

      await _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            return GestureDetector(
              onTap: () {
                setState(() => _showControls = !_showControls);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  if (_showControls)
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _togglePlayback,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                              size: 75,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              15,
                              0,
                              15,
                              20,
                            ),
                            child: Column(
                              children: [
                                VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: Colors.white,
                                    bufferedColor: Colors.white54,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(value.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(value.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.fullscreen_exit,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// AUDIO MESSAGE PLAYER
// =====================================================

class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int audioDurationMs;
  final bool isMe;

  const AudioMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.audioDurationMs,
    required this.isMe,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  late final AudioPlayer _player;

  bool _isLoading = true;
  String? _errorMessage;

  Color get _foregroundColor =>
      widget.isMe ? Colors.white : const Color(0xFF14213D);

  Color get _secondaryColor =>
      widget.isMe ? Colors.white70 : Colors.blueGrey;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    if (widget.audioUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Audio unavailable';
      });
      return;
    }

    try {
      await _player.setUrl(widget.audioUrl);

      if (!mounted) return;

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load audio';
      });
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }

        await _player.play();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _errorMessage = 'Playback failed');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: 220,
        height: 45,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foregroundColor,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        width: 220,
        child: Row(
          children: [
            Icon(Icons.error_outline, color: _foregroundColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: _foregroundColor),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;

              return IconButton(
                onPressed: _togglePlayback,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 38,
                  color: _foregroundColor,
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, durationSnapshot) {
                    final totalDuration = durationSnapshot.data ??
                        Duration(milliseconds: widget.audioDurationMs);

                    final totalMs =
                        totalDuration.inMilliseconds.toDouble();
                    final maxValue = totalMs > 0 ? totalMs : 1.0;

                    return StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, positionSnapshot) {
                        final position =
                            positionSnapshot.data ?? Duration.zero;

                        final positionMs = position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxValue)
                            .toDouble();

                        return SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                          ),
                          child: Slider(
                            value: positionMs,
                            min: 0,
                            max: maxValue,
                            activeColor: _foregroundColor,
                            inactiveColor: _secondaryColor.withAlpha(90),
                            onChanged: (value) {
                              _player.seek(
                                Duration(milliseconds: value.round()),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position =
                        positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ??
                            Duration(
                              milliseconds: widget.audioDurationMs,
                            );

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: TextStyle(
                                  color: _secondaryColor,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: _secondaryColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
