
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  String _generateChatId(String userId1, String userId2) {
    final users = [userId1, userId2]..sort();
    return '${users[0]}_${users[1]}';
  }

  void _validateReceiver(String receiverId, String userId) {
    if (receiverId.isEmpty || receiverId == userId) {
      throw Exception('Invalid receiver ID');
    }
  }

  void _validateLocation(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw Exception('Invalid location coordinates');
    }
  }

  // ============================================================
  // CREATE OR GET CHAT
  // ============================================================

  Future<String> getOrCreateChat(String receiverId) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    _validateReceiver(receiverId, userId);

    final chatId = _generateChatId(userId, receiverId);
    final chatRef = _chatsCollection.doc(chatId);
    final chatSnapshot = await chatRef.get();

    if (!chatSnapshot.exists) {
      final chat = ChatModel(
        chatId: chatId,
        participants: [userId, receiverId],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await chatRef.set({
        ...chat.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  // ============================================================
  // GET ALL CHATS
  // Only one declaration - no duplicate method
  // ============================================================

  Stream<List<ChatModel>> getChats() {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value([]);
    }

    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs.map((doc) {
        return ChatModel.fromMap(doc.id, doc.data());
      }).toList();

      final oldestDate = DateTime.fromMillisecondsSinceEpoch(0);

      chats.sort((a, b) {
        final dateA = a.updatedAt ?? oldestDate;
        final dateB = b.updatedAt ?? oldestDate;
        return dateB.compareTo(dateA);
      });

      return chats;
    });
  }

  // ============================================================
  // GET MESSAGES
  // ============================================================

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final userId = currentUserId;

      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
          .where((message) =>
              !message.deletedFor.contains(userId) ||
              message.isDeletedForBoth)
          .toList();
    });
  }

  // ============================================================
  // COMMON MESSAGE SENDER
  // ============================================================

  Future<String> _sendMessage({
    required String receiverId,
    required MessageModel Function(
      String messageId,
      String chatId,
      String userId,
    ) createMessage,
    required String lastMessage,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    _validateReceiver(receiverId, userId);

    final chatId = await getOrCreateChat(receiverId);
    final chatRef = _chatsCollection.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final newMessage = createMessage(
      messageRef.id,
      chatId,
      userId,
    );

    final batch = _firestore.batch();

    batch.set(messageRef, newMessage.toMap());

    batch.update(chatRef, {
      'lastMessage': lastMessage,
      'lastMessageSenderId': userId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return messageRef.id;
  }

  // ============================================================
  // SEND TEXT MESSAGE
  // ============================================================

  Future<void> sendTextMessage({
    required String receiverId,
    required String message,
  }) async {
    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: trimmedMessage,
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          message: trimmedMessage,
          messageType: 'text',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND IMAGE MESSAGE
  // ============================================================

  Future<void> sendImageMessage({
    required String receiverId,
    required String imageUrl,
  }) async {
    if (imageUrl.trim().isEmpty) {
      throw Exception('Image URL cannot be empty');
    }

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: '📷 Photo',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          imageUrl: imageUrl,
          messageType: 'image',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND AUDIO / VOICE MESSAGE
  // ============================================================

  Future<void> sendAudioMessage({
    required String receiverId,
    required String audioUrl,
    required int audioDurationMs,
  }) async {
    if (audioUrl.trim().isEmpty) {
      throw Exception('Audio URL cannot be empty');
    }

    if (audioDurationMs <= 0) {
      throw Exception('Invalid audio duration');
    }

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: '🎤 Voice Message',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          audioUrl: audioUrl,
          audioDurationMs: audioDurationMs,
          messageType: 'audio',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND VIDEO MESSAGE
  // ============================================================

  Future<void> sendVideoMessage({
    required String receiverId,
    required String videoUrl,
  }) async {
    if (videoUrl.trim().isEmpty) {
      throw Exception('Video URL cannot be empty');
    }

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: '🎥 Video',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          videoUrl: videoUrl,
          messageType: 'video',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND DOCUMENT MESSAGE
  // ============================================================

  Future<void> sendDocumentMessage({
    required String receiverId,
    required String documentUrl,
    required String documentName,
    required int documentSize,
  }) async {
    if (documentUrl.trim().isEmpty) {
      throw Exception('Document URL cannot be empty');
    }

    if (documentName.trim().isEmpty) {
      throw Exception('Document name cannot be empty');
    }

    if (documentSize < 0) {
      throw Exception('Invalid document size');
    }

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: '📄 $documentName',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          documentUrl: documentUrl,
          documentName: documentName,
          documentSize: documentSize,
          messageType: 'document',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND LOCATION MESSAGE
  // ============================================================

  Future<void> sendLocationMessage({
    required String receiverId,
    required double latitude,
    required double longitude,
    String locationName = '',
  }) async {
    _validateLocation(latitude, longitude);

    await _sendMessage(
      receiverId: receiverId,
      lastMessage: '📍 Location',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          messageType: 'location',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // SEND LIVE LOCATION
  // ============================================================

  Future<String> sendLiveLocationMessage({
    required String receiverId,
    required double latitude,
    required double longitude,
    String locationName = '',
  }) async {
    _validateLocation(latitude, longitude);

    return _sendMessage(
      receiverId: receiverId,
      lastMessage: '🔴 Live Location',
      createMessage: (messageId, chatId, userId) {
        return MessageModel(
          messageId: messageId,
          chatId: chatId,
          senderId: userId,
          receiverId: receiverId,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          isLiveLocation: true,
          liveLocationActive: true,
          locationUpdatedAt: DateTime.now(),
          messageType: 'location',
          isRead: false,
        );
      },
    );
  }

  // ============================================================
  // UPDATE LIVE LOCATION
  // ============================================================

  Future<void> updateLiveLocation({
    required String chatId,
    required String messageId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    _validateLocation(latitude, longitude);

    final messageRef = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snapshot = await messageRef.get();

    if (!snapshot.exists) {
      throw Exception('Live location message not found');
    }

    final data = snapshot.data();

    if (data == null ||
        data['senderId'] != userId ||
        data['isLiveLocation'] != true ||
        data['liveLocationActive'] != true) {
      throw Exception('Live location is not active or not owned by you');
    }

    final updateData = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (locationName != null) {
      updateData['locationName'] = locationName;
    }

    await messageRef.update(updateData);
  }

  // ============================================================
  // STOP LIVE LOCATION
  // ============================================================

  Future<void> stopLiveLocation({
    required String chatId,
    required String messageId,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    final messageRef = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snapshot = await messageRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data();

    if (data == null || data['senderId'] != userId) {
      throw Exception('You cannot stop this live location');
    }

    if (data['isLiveLocation'] != true ||
        data['liveLocationActive'] != true) {
      return;
    }

    await messageRef.update({
      'liveLocationActive': false,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UNSEND / DELETE MESSAGE
  // ============================================================

  Future<void> unsendMessage({
    required String chatId,
    required String messageId,
    required bool forBoth,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    final ref = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snapshot = await ref.get();

    if (!snapshot.exists) return;

    final data = snapshot.data();

    if (data == null) return;

    final senderId = data['senderId'] as String? ?? '';
    final receiverId = data['receiverId'] as String? ?? '';

    if (userId != senderId && userId != receiverId) {
      throw Exception('You are not a participant in this message');
    }

    if (forBoth && userId != senderId) {
      throw Exception('Only the sender can unsend for both');
    }

    if (forBoth) {
      await ref.update({
        'isDeletedForBoth': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'message': 'This message was deleted',
        'imageUrl': '',
        'audioUrl': '',
        'videoUrl': '',
        'documentUrl': '',
        'documentName': '',
        'documentSize': 0,
        'latitude': null,
        'longitude': null,
        'locationName': '',
        'liveLocationActive': false,
      });
    } else {
      await ref.update({
        'deletedFor': FieldValue.arrayUnion([userId]),
      });
    }
  }

  // ============================================================
  // GET ACTIVE LIVE LOCATION
  // ============================================================

  Future<MessageModel?> getActiveLiveLocation(String chatId) async {
    final userId = currentUserId;

    if (userId == null) return null;

    final snapshot = await _chatsCollection
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs.reversed) {
      final message = MessageModel.fromMap(doc.id, doc.data());

      if (message.isLiveLocation &&
          message.liveLocationActive &&
          !message.isDeletedForBoth) {
        return message;
      }
    }

    return null;
  }

  // ============================================================
  // MARK SINGLE MESSAGE AS READ
  // ============================================================

  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    final messageRef = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snapshot = await messageRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data();

    if (data == null ||
        data['receiverId'] != userId ||
        data['isRead'] == true) {
      return;
    }

    await messageRef.update({'isRead': true});
  }

  // ============================================================
  // MARK ALL MESSAGES AS READ
  // Avoid compound Firestore query/index requirement
  // ============================================================

  Future<void> markAllMessagesAsRead(String chatId) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('User is not logged in');
    }

    final messagesSnapshot = await _chatsCollection
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .get();

    final unreadDocs = messagesSnapshot.docs.where((doc) {
      return doc.data()['isRead'] != true;
    }).toList();

    if (unreadDocs.isEmpty) return;

    // Firestore batch limit is 500 operations.
    // Use 450 to keep a safe margin.
    for (var i = 0; i < unreadDocs.length; i += 450) {
      final batch = _firestore.batch();

      final end = (i + 450 < unreadDocs.length)
          ? i + 450
          : unreadDocs.length;

      for (final doc in unreadDocs.sublist(i, end)) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    }
  }
}
