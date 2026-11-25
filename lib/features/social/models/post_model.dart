import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String content;
  final String imageUrl;
  final List<String> likes;
  final DateTime createdAt;

  PostModel({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.content,
    required this.imageUrl,
    required this.likes,
    required this.createdAt,
  });

  // Convert Post Data into Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'imageUrl': imageUrl,
      'likes': likes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Convert Firestore Map into PostModel
  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'NEXAURA User',
      userPhoto: map['userPhoto'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
