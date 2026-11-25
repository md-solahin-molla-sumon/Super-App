
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId;

  // Text message or media caption
  final String message;
  final String messageType;

  // Media
  final String imageUrl;
  final String audioUrl;
  final int audioDurationMs;
  final String videoUrl;
  final String documentUrl;
  final String documentName;
  final int documentSize;

  // Location
  final double? latitude;
  final double? longitude;
  final String locationName;
  final bool isLiveLocation;
  final bool liveLocationActive;
  final DateTime? locationUpdatedAt;

  // Message status
  final bool isDelivered;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  // Reply
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToMessage;
  final String? replyToMessageType;

  // Forward
  final bool isForwarded;
  final String? forwardedFromSenderId;
  final String? forwardedFromName;

  // Delete
  final bool isDeletedForBoth;
  final List<String> deletedFor;

  final DateTime? createdAt;

  const MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    this.message = '',
    this.messageType = 'text',
    this.imageUrl = '',
    this.audioUrl = '',
    this.audioDurationMs = 0,
    this.videoUrl = '',
    this.documentUrl = '',
    this.documentName = '',
    this.documentSize = 0,
    this.latitude,
    this.longitude,
    this.locationName = '',
    this.isLiveLocation = false,
    this.liveLocationActive = false,
    this.locationUpdatedAt,
    this.isDelivered = false,
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToMessage,
    this.replyToMessageType,
    this.isForwarded = false,
    this.forwardedFromSenderId,
    this.forwardedFromName,
    this.isDeletedForBoth = false,
    this.deletedFor = const [],
    this.createdAt,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,

      'message': message,
      'messageType': messageType,

      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDurationMs,
      'videoUrl': videoUrl,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'documentSize': documentSize,

      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'isLiveLocation': isLiveLocation,
      'liveLocationActive': liveLocationActive,
      'locationUpdatedAt': locationUpdatedAt != null
          ? Timestamp.fromDate(locationUpdatedAt!)
          : null,

      'isDelivered': isDelivered,
      'isRead': isRead,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'readAt': readAt != null
          ? Timestamp.fromDate(readAt!)
          : null,

      'replyToMessageId': replyToMessageId,
      'replyToSenderId': replyToSenderId,
      'replyToMessage': replyToMessage,
      'replyToMessageType': replyToMessageType,

      'isForwarded': isForwarded,
      'forwardedFromSenderId': forwardedFromSenderId,
      'forwardedFromName': forwardedFromName,

      'isDeletedForBoth': isDeletedForBoth,
      'deletedFor': deletedFor,

      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory MessageModel.fromMap(
    String messageId,
    Map<String, dynamic> map,
  ) {
    return MessageModel(
      messageId: messageId,
      chatId: map['chatId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',

      message: map['message']?.toString() ?? '',
      messageType: map['messageType']?.toString() ?? 'text',

      imageUrl: map['imageUrl']?.toString() ?? '',
      audioUrl: map['audioUrl']?.toString() ?? '',
      audioDurationMs: _parseInt(map['audioDurationMs']),
      videoUrl: map['videoUrl']?.toString() ?? '',
      documentUrl: map['documentUrl']?.toString() ?? '',
      documentName: map['documentName']?.toString() ?? '',
      documentSize: _parseInt(map['documentSize']),

      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      locationName: map['locationName']?.toString() ?? '',
      isLiveLocation: map['isLiveLocation'] == true,
      liveLocationActive: map['liveLocationActive'] == true,
      locationUpdatedAt: _parseDate(map['locationUpdatedAt']),

      isDelivered: map['isDelivered'] == true,
      isRead: map['isRead'] == true,
      deliveredAt: _parseDate(map['deliveredAt']),
      readAt: _parseDate(map['readAt']),

      replyToMessageId: map['replyToMessageId']?.toString(),
      replyToSenderId: map['replyToSenderId']?.toString(),
      replyToMessage: map['replyToMessage']?.toString(),
      replyToMessageType: map['replyToMessageType']?.toString(),

      isForwarded: map['isForwarded'] == true,
      forwardedFromSenderId:
          map['forwardedFromSenderId']?.toString(),
      forwardedFromName: map['forwardedFromName']?.toString(),

      isDeletedForBoth: map['isDeletedForBoth'] == true,
      deletedFor: List<String>.from(map['deletedFor'] ?? const []),

      createdAt: _parseDate(map['createdAt']),
    );
  }

  MessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? message,
    String? messageType,
    String? imageUrl,
    String? audioUrl,
    int? audioDurationMs,
    String? videoUrl,
    String? documentUrl,
    String? documentName,
    int? documentSize,
    double? latitude,
    double? longitude,
    String? locationName,
    bool? isLiveLocation,
    bool? liveLocationActive,
    DateTime? locationUpdatedAt,
    bool? isDelivered,
    bool? isRead,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToMessage,
    String? replyToMessageType,
    bool? isForwarded,
    String? forwardedFromSenderId,
    String? forwardedFromName,
    bool? isDeletedForBoth,
    List<String>? deletedFor,
    DateTime? createdAt,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      videoUrl: videoUrl ?? this.videoUrl,
      documentUrl: documentUrl ?? this.documentUrl,
      documentName: documentName ?? this.documentName,
      documentSize: documentSize ?? this.documentSize,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      isLiveLocation: isLiveLocation ?? this.isLiveLocation,
      liveLocationActive:
          liveLocationActive ?? this.liveLocationActive,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      replyToMessageType:
          replyToMessageType ?? this.replyToMessageType,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFromSenderId:
          forwardedFromSenderId ?? this.forwardedFromSenderId,
      forwardedFromName: forwardedFromName ?? this.forwardedFromName,
      isDeletedForBoth: isDeletedForBoth ?? this.isDeletedForBoth,
      deletedFor: deletedFor ?? this.deletedFor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
