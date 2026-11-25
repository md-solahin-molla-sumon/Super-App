import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _bioController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  static const Color royalBlue = Color(0xFF1D3557);
  static const Color pageBackground = Color(0xFFF5F7FA);
  static const Color textColor = Color(0xFF202124);
  static const Color hintColor = Color(0xFF757575);

  XFile? _selectedImage;
  String _currentPhotoUrl = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _dataInitialized = false;

  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please login first');
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        throw Exception('User profile not found');
      }

      final data = document.data()!;

      _nameController.text = data['name'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _currentPhotoUrl = data['photoUrl'] ?? '';

      if (mounted) {
        setState(() {
          _dataInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile loading failed: $e')));
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0;
    });

    try {
      String photoUrl = _currentPhotoUrl;

      if (_selectedImage != null) {
        final imageBytes = await _selectedImage!.readAsBytes();

        photoUrl = await _cloudinaryService.uploadImage(
          imageBytes: imageBytes,
          fileName: 'profile_${user.uid}_${_selectedImage!.name}',
          onProgress: (progress) {
            if (!mounted) return;

            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name': _nameController.text.trim(),
            'bio': _bioController.text.trim(),
            'photoUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: hintColor, fontSize: 14),
      prefixIcon: Icon(icon, color: royalBlue),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCED4DA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCED4DA), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: royalBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: pageBackground,
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: textColor),
          hintStyle: TextStyle(color: hintColor),
        ),
      ),
      child: Scaffold(
        backgroundColor: pageBackground,

        appBar: AppBar(
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),

        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: royalBlue))
            : !_dataInitialized
            ? const Center(
                child: Text(
                  'Unable to load profile',
                  style: TextStyle(color: textColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Profile Picture
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage:
                                  _selectedImage == null &&
                                      _currentPhotoUrl.isNotEmpty
                                  ? NetworkImage(_currentPhotoUrl)
                                  : null,
                              child: _selectedImage != null
                                  ? FutureBuilder<Uint8List>(
                                      future: _selectedImage!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return ClipOval(
                                            child: Image.memory(
                                              snapshot.data!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        }

                                        return const CircularProgressIndicator(
                                          color: royalBlue,
                                        );
                                      },
                                    )
                                  : _currentPhotoUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),

                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isSaving ? null : _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: royalBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Center(
                        child: Text(
                          'Change Profile Picture',
                          style: TextStyle(
                            color: royalBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // Name
                      _fieldLabel('Full Name'),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _nameController,
                        enabled: !_isSaving,
                        style: const TextStyle(color: textColor, fontSize: 15),
                        cursorColor: royalBlue,
                        decoration: _fieldDecoration(
                          hint: 'Enter your name',
                          icon: Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name cannot be empty';
                          }

                          if (value.trim().length < 2) {
                            return 'Name must have at least 2 characters';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 22),

                      // Bio
                      _fieldLabel('Bio'),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _bioController,
                        enabled: !_isSaving,
                        maxLines: 4,
                        maxLength: 150,
                        style: const TextStyle(color: textColor, fontSize: 15),
                        cursorColor: royalBlue,
                        decoration:
                            _fieldDecoration(
                              hint: 'Write something about yourself...',
                              icon: Icons.info_outline,
                            ).copyWith(
                              alignLabelWithHint: true,
                              counterStyle: const TextStyle(color: hintColor),
                            ),
                      ),

                      const SizedBox(height: 25),

                      // Upload Progress
                      if (_isSaving && _selectedImage != null) ...[
                        LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          color: royalBlue,
                          backgroundColor: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Uploading profile picture...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor),
                        ),
                        const SizedBox(height: 15),
                      ],

                      // Save Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Changes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: royalBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
