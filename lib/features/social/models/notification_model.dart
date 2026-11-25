import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type;
  final String senderId;
  final String senderName;
  final String senderPhoto;
  final String postId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderPhoto,
    required this.postId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];

    DateTime date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      date = DateTime.now();
    }

    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Nexaura User',
      senderPhoto: map['senderPhoto'] ?? '',
      postId: map['postId'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: date,
    );
  }
}
