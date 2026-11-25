import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageTime,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Firestore Timestamp to DateTime
  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // Convert ChatModel to Map
  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create ChatModel from Firestore Map
  factory ChatModel.fromMap(String chatId, Map<String, dynamic> map) {
    return ChatModel(
      chatId: chatId,

      participants: List<String>.from(map['participants'] ?? []),

      lastMessage: map['lastMessage'] ?? '',

      lastMessageSenderId: map['lastMessageSenderId'] ?? '',

      lastMessageTime: _parseDate(map['lastMessageTime']),

      createdAt: _parseDate(map['createdAt']),

      updatedAt: _parseDate(map['updatedAt']),
    );
  }
}
