import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../services/social_service.dart';
import '../services/cloudinary_service.dart';
import '../../profile/services/profile_service.dart';

class CreatePostPage extends StatefulWidget {
  final PostModel? post;

  const CreatePostPage({
    super.key,
    this.post,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final SocialService _socialService = SocialService();
  final ProfileService _profileService = ProfileService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  final TextEditingController _postController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;

  String _existingImageUrl = '';
  bool _removeExistingImage = false;
  bool _isLoading = false;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _postController.text = widget.post!.content;
      _existingImageUrl = widget.post!.imageUrl;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _removeExistingImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null) return '';

    final imageBytes = await _selectedImage!.readAsBytes();

    return _cloudinaryService.uploadImage(
      imageBytes: imageBytes,
      fileName: _selectedImage!.name,
      onProgress: (_) {},
    );
  }

  void _removeImage() {
    setState(() {
      if (_selectedImage != null) {
        _selectedImage = null;
      } else {
        _removeExistingImage = true;
      }
    });
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb
            ? Image.network(
                _selectedImage!.path,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(_selectedImage!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      );
    }

    if (_existingImageUrl.isNotEmpty && !_removeExistingImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _existingImageUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              alignment: Alignment.center,
              color: Colors.black12,
              child: const Text('Unable to load existing image'),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _savePost() async {
    if (_isLoading) return;

    final hasNewImage = _selectedImage != null;
    final hasExistingImage =
        _existingImageUrl.isNotEmpty && !_removeExistingImage;

    if (_postController.text.trim().isEmpty &&
        !hasNewImage &&
        !hasExistingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write something or select an image!'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _socialService.currentUser;

      if (user == null) {
        throw Exception('Please login first');
      }

      String imageUrl = '';

      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      } else if (!_removeExistingImage) {
        imageUrl = _existingImageUrl;
      }

      if (_isEditing) {
        await _socialService.updatePost(
          postId: widget.post!.postId,
          content: _postController.text.trim(),
          imageUrl: imageUrl,
        );
      } else {
        final profile = await _profileService.getUserProfile();
        final userData = profile.data() as Map<String, dynamic>;

        await _socialService.createPost(
          content: _postController.text.trim(),
          imageUrl: imageUrl,
          userName: userData['name'] ?? 'User',
          userPhoto: userData['photoUrl'] ?? '',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Post updated successfully!'
                : 'Post created successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Failed to update post: $e'
                : 'Failed to create post: $e',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _selectedImage != null ||
        (_existingImageUrl.isNotEmpty && !_removeExistingImage);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Post' : 'Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePost,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditing ? 'UPDATE' : 'POST',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _postController,
              maxLines: 8,
              maxLength: 1000,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),

            if (_isLoading && _selectedImage != null) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading image...'),
            ],

            if (hasImage) ...[
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  _buildImagePreview(),
                  IconButton(
                    onPressed: _isLoading ? null : _removeImage,
                    icon: const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            Row(
              children: [
                IconButton(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(
                    Icons.image_outlined,
                    color: Colors.green,
                    size: 30,
                  ),
                ),
                const Text(
                  'Add Photo',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}