
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/social_service.dart';

class CreateStoryPage extends StatefulWidget {
  const CreateStoryPage({super.key});

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final SocialService _socialService = SocialService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  static const Color _purple = Color(0xFF6514E8);
  static const Color _darkPurple = Color(0xFF210078);

  String _selectedType = 'text';

  Uint8List? _mediaBytes;
  Uint8List? _audioBytes;

  String _mediaFileName = '';
  String _audioFileName = '';

  bool _isUploading = false;
  double _uploadProgress = 0;

  int _backgroundColor = 0xFF6514E8;

  final List<Map<String, dynamic>> _storyTypes = [
    {
      'type': 'video',
      'title': 'Video',
      'icon': Icons.video_library_rounded,
    },
    {
      'type': 'image_audio',
      'title': 'Image + Audio',
      'icon': Icons.image_rounded,
    },
    {
      'type': 'audio',
      'title': 'Audio Only',
      'icon': Icons.headphones_rounded,
    },
    {
      'type': 'text_audio',
      'title': 'Text + Audio',
      'icon': Icons.music_note_rounded,
    },
    {
      'type': 'text',
      'title': 'Text Only',
      'icon': Icons.text_fields_rounded,
    },
  ];

  bool get _needsMedia =>
      _selectedType == 'video' ||
      _selectedType == 'image_audio';

  bool get _needsAudio =>
      _selectedType == 'audio' ||
      _selectedType == 'image_audio' ||
      _selectedType == 'text_audio';

  bool get _needsText =>
      _selectedType == 'text' ||
      _selectedType == 'text_audio';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _changeStoryType(String type) {
    setState(() {
      _selectedType = type;
      _mediaBytes = null;
      _audioBytes = null;
      _mediaFileName = '';
      _audioFileName = '';
      _textController.clear();
    });
  }

  Future<void> _pickMedia() async {
    try {
      XFile? file;

      if (_selectedType == 'video') {
        file = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
      } else {
        file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
      }

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _mediaBytes = bytes;
        _mediaFileName = file!.name;
      });
    } catch (e) {
      _showMessage('Unable to select media: $e');
    }
  }

  
Future<void> _pickAudio() async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.audio,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      _showMessage('Unable to read the selected audio file.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _audioBytes = bytes;
      _audioFileName = file.name;
    });
  } catch (e) {
    _showMessage('Unable to select audio: $e');
  }
}


  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, String>> _getUserInformation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snapshot.data() ?? {};

    return {
      'name': (data['name'] ??
              user.displayName ??
              'Nexaura User')
          .toString(),
      'photo': (data['photoUrl'] ??
              user.photoURL ??
              '')
          .toString(),
    };
  }

  Future<void> _publishStory() async {
    if (_isUploading) return;

    if (_needsMedia && _mediaBytes == null) {
      _showMessage(
        _selectedType == 'video'
            ? 'Please select a video first.'
            : 'Please select an image first.',
      );
      return;
    }

    if (_needsAudio && _audioBytes == null) {
      _showMessage('Please select an audio file first.');
      return;
    }

    if (_needsText && _textController.text.trim().isEmpty) {
      _showMessage('Please enter your story text.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final userInfo = await _getUserInformation();

      await _socialService.createStory(
        userName: userInfo['name']!,
        userPhoto: userInfo['photo']!,
        mediaType: _selectedType,
        mediaBytes: _mediaBytes,
        fileName: _mediaFileName,
        audioBytes: _audioBytes,
        audioFileName: _audioFileName,
        text: _textController.text.trim(),
        backgroundColor: _backgroundColor,
        onProgress: (progress) {
          if (!mounted) return;

          setState(() {
            _uploadProgress = progress.clamp(0.0, 1.0);
          });
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your story was published successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Story upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 9,
      runSpacing: 10,
      children: _storyTypes.map((item) {
        final selected = _selectedType == item['type'];

        return InkWell(
          onTap: _isUploading
              ? null
              : () => _changeStoryType(item['type'] as String),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? _purple.withValues(alpha: 0.13)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _purple : Colors.grey.withValues(alpha: 0.3),
                width: selected ? 1.7 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 19,
                  color: selected ? _purple : Colors.grey,
                ),
                const SizedBox(width: 7),
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? _purple : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaPicker() {
    final isVideo = _selectedType == 'video';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          isVideo ? 'Select Video' : 'Select Image',
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _isUploading ? null : _pickMedia,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 210,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _purple.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: _mediaBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: isVideo
                        ? _buildVideoPlaceholder()
                        : Image.memory(
                            _mediaBytes!,
                            fit: BoxFit.contain,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVideo
                            ? Icons.video_library_rounded
                            : Icons.add_photo_alternate_rounded,
                        size: 48,
                        color: _purple,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to select ${isVideo ? 'video' : 'image'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Choose from your gallery',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_mediaFileName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _mediaFileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _purple,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 65,
          ),
          SizedBox(height: 8),
          Text(
            'Video selected',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Select Audio'),
        const SizedBox(height: 10),
        InkWell(
          onTap: _isUploading ? null : _pickAudio,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _purple.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: _purple,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _audioFileName.isEmpty
                            ? 'Choose Audio File'
                            : _audioFileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _audioFileName.isEmpty
                            ? 'Tap to browse audio files'
                            : 'Audio selected successfully',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.folder_open_rounded,
                  color: _purple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Your Story Text'),
        const SizedBox(height: 10),
        TextField(
          controller: _textController,
          enabled: !_isUploading,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Write something...',
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: _purple,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (_selectedType == 'text') ...[
          const SizedBox(height: 8),
          _buildBackgroundSelector(),
        ],
      ],
    );
  }

  Widget _buildBackgroundSelector() {
    const colors = [
      0xFF6514E8,
      0xFF1565C0,
      0xFF00897B,
      0xFFE65100,
      0xFFC2185B,
      0xFF263238,
      0xFF4527A0,
      0xFF00695C,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Background Color',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: colors.map((color) {
            final selected = _backgroundColor == color;

            return GestureDetector(
              onTap: _isUploading
                  ? null
                  : () {
                      setState(() {
                        _backgroundColor = color;
                      });
                    },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          width: 2.5,
                        )
                      : null,
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPreview() {
    if (_selectedType != 'text' ||
        _textController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(_backgroundColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _textController.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : _publishStory,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isUploading
            ? const SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.publish_rounded),
        label: Text(
          _isUploading ? 'Publishing Story...' : 'Publish Story',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: _darkPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Choose Story Type'),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 24),

              if (_needsMedia) ...[
                _buildMediaPicker(),
                const SizedBox(height: 22),
              ],

              if (_needsAudio) ...[
                _buildAudioPicker(),
                const SizedBox(height: 22),
              ],

              if (_needsText) ...[
                _buildTextEditor(),
                const SizedBox(height: 15),
              ],

              if (_selectedType == 'text') ...[
                _buildPreview(),
                const SizedBox(height: 18),
              ],

              if (_isUploading) ...[
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: _uploadProgress > 0
                      ? _uploadProgress
                      : null,
                  color: _purple,
                  backgroundColor: isDark
                      ? Colors.white12
                      : Colors.black12,
                ),
                const SizedBox(height: 8),
                Text(
                  _uploadProgress > 0
                      ? 'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                      : 'Preparing upload...',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 15),
              ],

              _buildPublishButton(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}
