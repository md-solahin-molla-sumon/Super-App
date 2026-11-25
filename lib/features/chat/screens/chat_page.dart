
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../social/services/cloudinary_service.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final ChatModel chat;
  final String receiverId;
  final String receiverName;
  final String receiverPhoto;

  const ChatPage({
    super.key,
    required this.chat,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _recordingTimer;
  Timer? _liveLocationTimer;
  Stopwatch? _recordingStopwatch;

  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color navy = Color(0xFF14213D);
  static const Color backgroundColor = Color(0xFFF8F7FC);

  bool _isSending = false;
  bool _isPickingVideo = false;
  bool _isRecording = false;
  bool _isPreviewPlaying = false;
  bool _isSharingLiveLocation = false;

  double _uploadProgress = 0;

  int _recordingDurationMs = 0;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String? _recordedAudioPath;
  String? _activeLiveLocationMessageId;

String get currentUserId =>
    FirebaseAuth.instance.currentUser?.uid ?? '';  bool get _hasPendingVoice =>
      _recordedAudioPath != null || _isRecording;

  bool get _canPickAttachment =>
      !_isSending &&
      !_isPickingVideo &&
      !_isRecording &&
      _recordedAudioPath == null &&
      _selectedImage == null;

  @override
  void initState() {
    super.initState();

    _restoreActiveLiveLocation();

    _playerStateSubscription =
        _previewPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPreviewPlaying = state.playing;
      });
    });
  }

  // Show information message.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Audio Call
  void _startAudioCall() {
    _showMessage('Online Audio Call will be added in a future update.');
  }

  // Video Call
  void _startVideoCall() {
    _showMessage('Online Video Call will be added in a future update.');
  }

  // Start Voice Recording
  Future<void> _startVoiceMessage() async {
    if (_isSending ||
        _isPickingVideo ||
        _isRecording ||
        _selectedImage != null ||
        _recordedAudioPath != null) {
      return;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        _showMessage('Microphone permission is required.');
        return;
      }

      final fileName =
          'nexaura_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

      final filePath = '${Directory.systemTemp.path}/$fileName';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      if (!mounted) {
        await _audioRecorder.cancel();
        return;
      }

      _recordingStopwatch = Stopwatch()..start();

      setState(() {
        _isRecording = true;
        _recordingDurationMs = 0;
      });

      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (!mounted || !_isRecording) return;

          setState(() {
            _recordingDurationMs =
                _recordingStopwatch?.elapsedMilliseconds ?? 0;
          });
        },
      );
    } catch (e) {
      _showMessage('Unable to start recording: $e');
    }
  }

  // Stop Voice Recording
  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;

    try {
      _recordingTimer?.cancel();
      _recordingStopwatch?.stop();

      final durationMs = _recordingStopwatch?.elapsedMilliseconds ?? 0;
      final recordedPath = await _audioRecorder.stop();

      if (!mounted) return;

      if (recordedPath == null || durationMs < 500) {
        if (recordedPath != null) {
          try {
            await File(recordedPath).delete();
          } catch (_) {}
        }

        setState(() {
          _isRecording = false;
          _recordingDurationMs = 0;
        });

        _showMessage('Recording is too short. Please record again.');
        return;
      }

      await _previewPlayer.stop();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _recordedAudioPath = recordedPath;
        _recordingDurationMs = durationMs;
      });

      await _previewPlayer.setFilePath(recordedPath);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      _showMessage('Unable to stop recording: $e');
    }
  }

  // Cancel Recording or Preview
  Future<void> _cancelVoiceMessage() async {
    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();

    if (_isRecording) {
      try {
        await _audioRecorder.cancel();
      } catch (_) {}
    }

    final oldPath = _recordedAudioPath;

    try {
      await _previewPlayer.stop();
    } catch (_) {}

    if (oldPath != null) {
      try {
        await File(oldPath).delete();
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _recordedAudioPath = null;
      _recordingDurationMs = 0;
      _isPreviewPlaying = false;
    });
  }

  // Play or Pause Voice Preview
  Future<void> _toggleVoicePreview() async {
    if (_recordedAudioPath == null) return;

    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      } else {
        if (_previewPlayer.processingState == ProcessingState.completed) {
          await _previewPlayer.seek(Duration.zero);
        }

        await _previewPlayer.play();
      }
    } catch (e) {
      _showMessage('Unable to play audio: $e');
    }
  }

  // Show a clean, bottom-sheet attachment menu instead of a popup that can
  // appear in an unexpected position on smaller screens.
  Future<void> _showAttachmentOptions() async {
    if (!_canPickAttachment) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Share with your contact',
                      style: TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _attachmentOption(
                    sheetContext,
                    value: 'video',
                    icon: Icons.video_library_outlined,
                    title: 'Video',
                    subtitle: 'Share a video from your gallery',
                  ),
                  _attachmentOption(
                    sheetContext,
                    value: 'document',
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Document',
                    subtitle: 'Share PDF, Word, Excel and other files',
                  ),
                  _attachmentOption(
                    sheetContext,
                    value: 'location',
                    icon: Icons.location_on_outlined,
                    title: 'Current location',
                    subtitle: 'Share your location once',
                  ),
                  if (!_isSharingLiveLocation)
                    _attachmentOption(
                      sheetContext,
                      value: 'live_location',
                      icon: Icons.my_location,
                      title: 'Share live location',
                      subtitle: 'Update your location while sharing',
                      iconColor: Colors.red,
                    )
                  else
                    _attachmentOption(
                      sheetContext,
                      value: 'stop_live_location',
                      icon: Icons.location_off_outlined,
                      title: 'Stop live location',
                      subtitle: 'Stop sharing your live location',
                      iconColor: Colors.red,
                    ),
                  _attachmentOption(
                    sheetContext,
                    value: 'audio',
                    icon: Icons.mic_none_rounded,
                    title: 'Voice message',
                    subtitle: 'Use the microphone button to record',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      await _handleAttachmentSelection(selected);
    }
  }

  Widget _attachmentOption(
    BuildContext sheetContext, {
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = primaryPurple,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(18),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
      ),
      onTap: () => Navigator.pop(sheetContext, value),
    );
  }

  // Attachment Menu Selection
  Future<void> _handleAttachmentSelection(String value) async {
    if (!_canPickAttachment) {
      _showMessage('Please finish your current attachment first.');
      return;
    }

    switch (value) {
      case 'video':
        await _pickAndSendVideo();
        break;

      case 'document':
        await _pickAndSendDocument();
        break;

      case 'location':
        await _shareCurrentLocation();
        break;

      case 'live_location':
        await _startLiveLocation();
        break;

      case 'stop_live_location':
        await _stopLiveLocation();
        break;

      case 'audio':
        _showMessage('Use the microphone button to record a voice message.');
        break;
    }
  }

  // Send Text, Image or Voice Message
  Future<void> _sendMessage() async {
    if (_isSending || _isRecording || _isPickingVideo) return;

    if (_selectedImage != null) {
      await _sendImageMessage();
      return;
    }

    if (_recordedAudioPath != null) {
      await _sendAudioMessage();
      return;
    }

    final message = _messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      await _chatService.sendTextMessage(
        receiverId: widget.receiverId,
        message: message,
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      _messageController.text = message;
      _showMessage('Message failed to send: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Pick Image
  Future<void> _pickImage() async {
    if (!_canPickAttachment) return;

    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (pickedImage == null) return;

      final Uint8List imageBytes = await pickedImage.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = pickedImage;
        _selectedImageBytes = imageBytes;
      });
    } catch (e) {
      _showMessage('Unable to select image: $e');
    }
  }

  // Remove Selected Image
  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // Upload and Send Image
  Future<void> _sendImageMessage() async {
    if (_isSending || _selectedImage == null || _selectedImageBytes == null) {
      return;
    }

    final XFile selectedImage = _selectedImage!;
    final Uint8List imageBytes = _selectedImageBytes!;

    setState(() {
      _isSending = true;
      _uploadProgress = 0;
    });

    try {
      final String imageUrl = await _cloudinaryService.uploadImage(
        imageBytes: imageBytes,
        fileName: selectedImage.name,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      await _chatService.sendImageMessage(
        receiverId: widget.receiverId,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
      });

      _scrollToBottom();
      _showMessage('Image sent successfully!');
    } catch (e) {
      _showMessage('Image sending failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  // Pick Video -> Preview -> Confirm -> Upload -> Send
  
Future<void> _pickAndSendVideo() async {
  if (!_canPickAttachment) return;

  setState(() {
    _isPickingVideo = true;
  });

  try {
    // Step 1: Pick video
    debugPrint('VIDEO: Opening gallery...');

    final XFile? pickedVideo = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedVideo == null || !mounted) return;

    debugPrint('VIDEO: Selected: ${pickedVideo.name}');

    // Step 2: Preview
    final bool? shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return VideoPreviewDialog(video: pickedVideo);
      },
    );

    if (shouldSend != true || !mounted) {
      debugPrint('VIDEO: Sending cancelled.');
      return;
    }

    // Step 3: Read bytes
    debugPrint('VIDEO: Reading video bytes...');

    final Uint8List videoBytes = await pickedVideo.readAsBytes();

    if (videoBytes.isEmpty) {
      throw Exception('Selected video is empty.');
    }

    debugPrint('VIDEO: Size = ${videoBytes.length} bytes');

    if (!mounted) return;

    // Step 4: Upload to Cloudinary
    setState(() {
      _isPickingVideo = false;
      _isSending = true;
      _uploadProgress = 0;
    });

    debugPrint('VIDEO: Uploading to Cloudinary...');

    final String videoUrl = await _cloudinaryService.uploadVideo(
      videoBytes: videoBytes,
      fileName: pickedVideo.name,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      },
    );

    debugPrint('VIDEO: Cloudinary upload completed.');
    debugPrint('VIDEO: URL = $videoUrl');

    if (videoUrl.trim().isEmpty) {
      throw Exception('Cloudinary returned an empty video URL.');
    }

    // Step 5: Save to Firestore
    debugPrint('VIDEO: Saving message to Firestore...');
    debugPrint('VIDEO: Receiver ID = ${widget.receiverId}');
    debugPrint('VIDEO: Chat ID = ${widget.chat.chatId}');

    await _chatService.sendVideoMessage(
      receiverId: widget.receiverId,
      videoUrl: videoUrl,
    );

    debugPrint('VIDEO: Firestore message saved successfully.');

    if (!mounted) return;

    _scrollToBottom();
    _showMessage('Video sent successfully!');

  } catch (e, stackTrace) {
    debugPrint('VIDEO SENDING ERROR: $e');
    debugPrint('VIDEO ERROR STACKTRACE: $stackTrace');

    _showMessage('Video sending failed: $e');

  } finally {
    if (mounted) {
      setState(() {
        _isPickingVideo = false;
        _isSending = false;
        _uploadProgress = 0;
      });
    }
  }
}


  // Pick, Upload and Send Document

// Pick, Upload and Send Document
Future<void> _pickAndSendDocument() async {
  if (!_canPickAttachment) return;

  try {
    // file_picker v12+ returns List<PlatformFile> directly.
    // File contents are read lazily using PlatformFile.readAsBytes().
    final List<PlatformFile> selectedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'zip',
      ],
    );

    // An empty list means the user cancelled the picker.
    if (selectedFiles.isEmpty) return;

    final PlatformFile selectedFile = selectedFiles.first;

    // Works with local files and providers that expose file bytes lazily.
    final Uint8List documentBytes = await selectedFile.readAsBytes();

    if (documentBytes.isEmpty) {
      _showMessage('Unable to read the selected document.');
      return;
    }

    // Use the actual number of bytes read. This is compatible with file_picker
    // v12+ where PlatformFile.size was removed.
    final int documentSize = documentBytes.length;

    if (!mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send document?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 42, color: primaryPurple),
          const SizedBox(height: 12),
          Text(selectedFile.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(documentSize >= 1024 * 1024
              ? '${(documentSize / (1024 * 1024)).toStringAsFixed(2)} MB'
              : '${(documentSize / 1024).toStringAsFixed(1)} KB'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
      _uploadProgress = 0;
    });

    debugPrint('DOCUMENT: Upload started.');
    debugPrint('DOCUMENT: Name = ${selectedFile.name}');
    debugPrint('DOCUMENT: Size = $documentSize bytes');

    final String documentUrl =
        await _cloudinaryService.uploadDocument(
      documentBytes: documentBytes,
      fileName: selectedFile.name,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      },
    );

    if (documentUrl.trim().isEmpty) {
      throw Exception('Document upload returned an empty URL.');
    }

    debugPrint('DOCUMENT: Upload completed.');
    debugPrint('DOCUMENT: Saving to Firestore...');

    await _chatService.sendDocumentMessage(
      receiverId: widget.receiverId,
      documentUrl: documentUrl,
      documentName: selectedFile.name,
      documentSize: documentSize,
    );

    debugPrint('DOCUMENT: Firestore message saved successfully.');

    if (!mounted) return;

    _scrollToBottom();
    _showMessage('Document sent successfully!');

  } catch (e, stackTrace) {
    debugPrint('DOCUMENT SENDING ERROR: $e');
    debugPrint('$stackTrace');

    _showMessage('Document sending failed: $e');

  } finally {
    if (mounted) {
      setState(() {
        _isSending = false;
        _uploadProgress = 0;
      });
    }
  }
}



  // Check GPS and Location Permission
  Future<bool> _checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Please turn on your device location/GPS.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission was denied.');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied. Enable it in settings.',
        );
        await Geolocator.openAppSettings();
        return false;
      }

      return true;
    } catch (e) {
      _showMessage('Unable to check location permission: $e');
      return false;
    }
  }

  // Get Current GPS Position
  Future<Position?> _getCurrentPosition() async {
    final hasPermission = await _checkLocationPermission();

    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      _showMessage('Unable to get current location: $e');
      return null;
    }
  }

  // Share One-Time Location
  Future<void> _shareCurrentLocation() async {
    if (!_canPickAttachment) return;

    final position = await _getCurrentPosition();

    if (position == null || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share current location?'),
        content: Text('Your current coordinates will be shared with ${widget.receiverName}.\n\n${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Share')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendLocationMessage(
        receiverId: widget.receiverId,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: 'Shared from Nexaura',
      );

      if (!mounted) return;

      _scrollToBottom();
      _showMessage('Location shared successfully!');
    } catch (e) {
      _showMessage('Location sharing failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Start Live Location Sharing
  Future<void> _startLiveLocation() async {
    if (!_canPickAttachment || _isSharingLiveLocation) return;

    final position = await _getCurrentPosition();

    if (position == null || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start live location?'),
        content: Text('Your live location will be shared with ${widget.receiverName} and updated every 10 seconds until you stop it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start sharing')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messageId = await _chatService.sendLiveLocationMessage(
        receiverId: widget.receiverId,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: 'Live location from Nexaura',
      );

      if (!mounted) {
        await _chatService.stopLiveLocation(
          chatId: widget.chat.chatId,
          messageId: messageId,
        );
        return;
      }

      setState(() {
        _activeLiveLocationMessageId = messageId;
        _isSharingLiveLocation = true;
      });

      _liveLocationTimer?.cancel();

      _liveLocationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) {
          _updateLiveLocation();
        },
      );

      _scrollToBottom();
      _showMessage('Live location sharing started.');
    } catch (e) {
      _showMessage('Unable to start live location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _restoreActiveLiveLocation() async {
    try {
      final active = await _chatService.getActiveLiveLocation(widget.chat.chatId);
      if (!mounted || active == null) return;
      setState(() {
        _activeLiveLocationMessageId = active.messageId;
        _isSharingLiveLocation = true;
      });
      _liveLocationTimer?.cancel();
      _liveLocationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _updateLiveLocation();
      });
    } catch (e) {
      debugPrint('Unable to restore live location state: $e');
    }
  }

  // Update Live Location Every 10 Seconds
  Future<void> _updateLiveLocation() async {
    final messageId = _activeLiveLocationMessageId;

    if (!_isSharingLiveLocation || messageId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted ||
          !_isSharingLiveLocation ||
          _activeLiveLocationMessageId != messageId) {
        return;
      }

      await _chatService.updateLiveLocation(
        chatId: widget.chat.chatId,
        messageId: messageId,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: 'Live location from Nexaura',
      );
    } catch (e) {
      debugPrint('Live location update failed: $e');
    }
  }

  // Stop Live Location Sharing
  Future<void> _stopLiveLocation() async {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;

    final messageId = _activeLiveLocationMessageId;

    if (messageId == null) {
      if (mounted) {
        setState(() {
          _isSharingLiveLocation = false;
        });
      }
      return;
    }

    try {
      await _chatService.stopLiveLocation(
        chatId: widget.chat.chatId,
        messageId: messageId,
      );

      if (!mounted) return;

      setState(() {
        _activeLiveLocationMessageId = null;
        _isSharingLiveLocation = false;
      });

      _showMessage('Live location sharing stopped.');
    } catch (e) {
      _showMessage('Unable to stop live location: $e');
    }
  }

  // Upload and Send Voice Message
  Future<void> _sendAudioMessage() async {
    final audioPath = _recordedAudioPath;

    if (_isSending || audioPath == null) return;

    if (_recordingDurationMs <= 0) return;

    final file = File(audioPath);

    if (!await file.exists()) {
      if (!mounted) return;

      _showMessage('Recorded audio file not found.');
      return;
    }

    setState(() {
      _isSending = true;
      _uploadProgress = 0;
    });

    try {
      final audioFileName = audioPath.split(Platform.pathSeparator).last;

      final audioUrl = await _cloudinaryService.uploadAudio(
        filePath: audioPath,
        fileName: audioFileName,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      await _chatService.sendAudioMessage(
        receiverId: widget.receiverId,
        audioUrl: audioUrl,
        audioDurationMs: _recordingDurationMs,
      );

      await _previewPlayer.stop();

      try {
        await file.delete();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _recordedAudioPath = null;
        _recordingDurationMs = 0;
        _isPreviewPlaying = false;
      });

      _scrollToBottom();
      _showMessage('Voice message sent successfully!');
    } catch (e) {
      _showMessage('Voice message sending failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  // Format Duration
  String _formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // Scroll to Bottom
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Mark Messages as Read
  Future<void> _markMessagesAsRead(List<MessageModel> messages) async {
    final unreadMessages = messages.where(
      (message) => message.receiverId == currentUserId && !message.isRead,
    );

    for (final message in unreadMessages) {
      try {
        await _chatService.markMessageAsRead(
          chatId: widget.chat.chatId,
          messageId: message.messageId,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();

    _liveLocationTimer?.cancel();

    _playerStateSubscription?.cancel();

    unawaited(_audioRecorder.dispose());
    unawaited(_previewPlayer.dispose());

    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Colors.white24,
              backgroundImage: widget.receiverPhoto.isNotEmpty
                  ? NetworkImage(widget.receiverPhoto)
                  : null,
              child: widget.receiverPhoto.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isSharingLiveLocation
                        ? 'Sharing live location'
                        : 'Nexaura Chat',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _startAudioCall,
            tooltip: 'Audio Call',
            icon: const Icon(
              Icons.call_outlined,
              color: Colors.white,
              size: 23,
            ),
          ),
          IconButton(
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
            icon: const Icon(
              Icons.videocam_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          // LIVE LOCATION STATUS
          if (_isSharingLiveLocation)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF1F2),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You are sharing your live location',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSending ? null : _stopLiveLocation,
                    child: const Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // MESSAGE LIST
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chat.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load messages.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: primaryPurple,
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.waving_hand,
                          size: 45,
                          color: primaryPurple,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Say hello!',
                          style: TextStyle(
                            color: navy,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Start your conversation here.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _markMessagesAsRead(messages);
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(
                      message: messages[index],
                      currentUserId: currentUserId,
                      onUnsend: (message, forBoth) async {
                        try {
                          await _chatService.unsendMessage(
                            chatId: widget.chat.chatId,
                            messageId: message.messageId,
                            forBoth: forBoth,
                          );
                          _showMessage(forBoth ? 'Message unsent for both.' : 'Message removed for you.');
                        } catch (e) {
                          _showMessage('Unable to unsend message: $e');
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),

          // MESSAGE INPUT AREA
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SELECTED IMAGE PREVIEW
                  if (_selectedImageBytes != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 75,
                              height: 75,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Image selected\nPress Send to upload',
                              style: TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isSending
                                ? null
                                : _removeSelectedImage,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // RECORDING STATUS
                  if (_isRecording)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Recording...',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(_recordingDurationMs),
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: _cancelVoiceMessage,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // VOICE PREVIEW
                  if (_recordedAudioPath != null && !_isRecording)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE9E1F7),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _toggleVoicePreview,
                            icon: Icon(
                              _isPreviewPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: primaryPurple,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Voice message preview',
                                  style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_recordingDurationMs),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isSending
                                ? null
                                : _cancelVoiceMessage,
                            tooltip: 'Delete recording',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // INPUT TOOLBAR
                  Row(
                    children: [
                      // VOICE MESSAGE BUTTON
                      IconButton(
                        onPressed: _isSending ||
                                _isPickingVideo ||
                                _recordedAudioPath != null
                            ? null
                            : _isRecording
                                ? _stopVoiceRecording
                                : _startVoiceMessage,
                        tooltip: _isRecording
                            ? 'Stop Recording'
                            : 'Voice Message',
                        icon: Icon(
                          _isRecording
                              ? Icons.stop_circle
                              : Icons.mic_none_rounded,
                          color: _isRecording
                              ? Colors.red
                              : primaryPurple,
                          size: 27,
                        ),
                      ),

                      // GALLERY BUTTON
                      IconButton(
                        onPressed: _canPickAttachment ? _pickImage : null,
                        tooltip: 'Gallery',
                        icon: const Icon(
                          Icons.image_outlined,
                          color: primaryPurple,
                          size: 25,
                        ),
                      ),

                      // CLEAN ATTACHMENT MENU
                      IconButton(
                        onPressed: _canPickAttachment ? _showAttachmentOptions : null,
                        tooltip: 'More attachments',
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: primaryPurple,
                          size: 27,
                        ),
                      ),

                      // MESSAGE TEXT FIELD
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textCapitalization:
                              TextCapitalization.sentences,
                          enabled: !_isSending &&
                              !_isPickingVideo &&
                              !_hasPendingVoice,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: primaryPurple,
                          decoration: InputDecoration(
                            hintText: _isSending
                                ? 'Please wait...'
                                : _isPickingVideo
                                    ? 'Preparing video preview...'
                                    : _isRecording
                                        ? 'Recording voice...'
                                        : _recordedAudioPath != null
                                            ? 'Voice preview ready'
                                            : 'Type a message...',
                            hintStyle: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: backgroundColor,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: Color(0xFFE9E1F7),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: primaryPurple,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // SEND BUTTON
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: primaryPurple,
                        child: IconButton(
                          onPressed: _isSending ||
                                  _isRecording ||
                                  _isPickingVideo
                              ? null
                              : _sendMessage,
                          icon: _isSending
                              ? SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    value: _uploadProgress > 0
                                        ? _uploadProgress
                                        : null,
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VIDEO PREVIEW DIALOG
// ============================================================

class VideoPreviewDialog extends StatefulWidget {
  final XFile video;

  const VideoPreviewDialog({
    super.key,
    required this.video,
  });

  @override
  State<VideoPreviewDialog> createState() =>
      _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  VideoPlayerController? _controller;

  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  // Initialize selected video.
  Future<void> _initializeVideo() async {
    VideoPlayerController? controller;

    try {
      if (kIsWeb) {
        // Web uses the browser video URL.
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.path),
        );
      } else {
        // Android / iOS uses the local video file.
        controller = VideoPlayerController.file(
          File(widget.video.path),
        );
      }

      _controller = controller;

      controller.addListener(_onVideoChanged);

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Video preview error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to preview this video.';
      });
    }
  }

  // Update Play/Pause icon.
  void _onVideoChanged() {
    final controller = _controller;

    if (!mounted || controller == null || !_isInitialized) {
      return;
    }

    final playing = controller.value.isPlaying;

    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  // Toggle Play/Pause.
  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (!_isInitialized || controller == null) return;

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        // Replay from beginning after video completes.
        if (controller.value.position >= controller.value.duration) {
          await controller.seekTo(Duration.zero);
        }

        await controller.play();
      }
    } catch (e) {
      debugPrint('Video playback error: $e');
    }
  }

  @override
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(
                children: [
                  const Icon(
                    Icons.video_library_outlined,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Video Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // VIDEO PLAYER
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxHeight: 320,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _errorMessage != null
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    : !_isInitialized || controller == null
                        ? const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio:
                                controller.value.aspectRatio > 0
                                    ? controller.value.aspectRatio
                                    : 16 / 9,
                            child: VideoPlayer(controller),
                          ),
              ),

              const SizedBox(height: 12),

              // PLAY / PAUSE BUTTON
              Row(
                children: [
                  IconButton(
                    onPressed:
                        _isInitialized ? _togglePlayback : null,
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 38,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Play or pause your selected video',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // VIDEO SEEK / PROGRESS SLIDER
              if (_isInitialized && controller != null)
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF7C3AED),
                    bufferedColor: Colors.grey,
                    backgroundColor: Color(0xFFE5E7EB),
                  ),
                ),

              const SizedBox(height: 16),

              // CANCEL AND SEND BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInitialized
                          ? () {
                              Navigator.pop(context, true);
                            }
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
