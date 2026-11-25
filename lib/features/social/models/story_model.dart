import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String storyId;
  final String userId;
  final String userName;
  final String userPhoto;

  // Supported types:
  // image, video, text, audio, image_audio, text_audio
  final String mediaType;

  final String mediaUrl;
  final String audioUrl;
  final String text;
  final int backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final Map<String, int> reactionCounts;

  StoryModel({
    required this.storyId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.mediaType,
    required this.mediaUrl,
    this.audioUrl = '',
    required this.text,
    required this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
    this.reactionCounts = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool isViewedBy(String uid) => viewedBy.contains(uid);

  int get totalReactions => reactionCounts.values.fold(
        0,
        (total, reactionCount) => total + reactionCount,
      );

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    final rawCounts = Map<String, dynamic>.from(
      map['reactionCounts'] ?? {},
    );

    return StoryModel(
      storyId: map['storyId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Nexaura User',
      userPhoto: map['userPhoto'] ?? '',
      mediaType: map['mediaType'] ?? 'text',
      mediaUrl: map['mediaUrl'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      text: map['text'] ?? '',
      backgroundColor: map['backgroundColor'] ?? 0xFF6514E8,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : now,
      expiresAt: map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : now.add(const Duration(hours: 24)),
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
      reactionCounts: rawCounts.map(
        (key, value) => MapEntry(
          key,
          (value as num).toInt(),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storyId': storyId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'audioUrl': audioUrl,
      'text': text,
      'backgroundColor': backgroundColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
      'reactionCounts': reactionCounts,
    };
  }
}