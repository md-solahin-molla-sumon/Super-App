import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.content,
    required this.createdAt,
  });

  // Convert Comment Data to Map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Convert Firestore Map to CommentModel
  factory CommentModel.fromMap(String commentId, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];

    return CommentModel(
      commentId: commentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      userPhoto: data['userPhoto'] ?? '',
      content: data['content'] ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}
