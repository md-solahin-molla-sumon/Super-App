
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color navy = Color(0xFF14213D);
  static const Color royalBlue = Color(0xFF2563EB);

  String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  final Map<String, Future<Map<String, dynamic>>> _userFutures = {};
  final Map<String, Future<int>> _unreadFutures = {};

  int _refreshKey = 0;

  // Get user information from Firestore.
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();

    if (!doc.exists) {
      return {
        'name': 'NEXAURA User',
        'photoUrl': '',
      };
    }

    final data = doc.data() ?? {};

    return {
      'name': data['name'] ?? 'NEXAURA User',
      'photoUrl': data['photoUrl'] ?? '',
    };
  }

  // Cache user information to avoid repeated Firestore requests.
  Future<Map<String, dynamic>> _getCachedUserInfo(String userId) {
    return _userFutures.putIfAbsent(
      userId,
      () => _getUserInfo(userId),
    );
  }

  // Get unread message count.
  Future<int> _getUnreadCount(String chatId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .get();

    return snapshot.docs.where((doc) {
      return doc.data()['isRead'] != true;
    }).length;
  }

  // Cache unread message count.
  Future<int> _getCachedUnreadCount(String chatId) {
    return _unreadFutures.putIfAbsent(
      chatId,
      () => _getUnreadCount(chatId),
    );
  }

  // Refresh chat list and cached information.
  void _refreshChats() {
    if (!mounted) return;

    setState(() {
      _userFutures.clear();
      _unreadFutures.clear();
      _refreshKey++;
    });
  }

  // Find the other participant.
  String _getOtherUserId(ChatModel chat) {
    return chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  // Open chat page.
  void _openChat(
    BuildContext context,
    ChatModel chat,
    String receiverId,
    String receiverName,
    String receiverPhoto,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chat: chat,
          receiverId: receiverId,
          receiverName: receiverName,
          receiverPhoto: receiverPhoto,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _unreadFutures.remove(chat.chatId);
        });
      }
    });
  }

  // Error screen.
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load conversations',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshChats,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // Empty chat list screen.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Start a conversation with someone.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Build individual chat item.
  Widget _buildChatItem(ChatModel chat) {
    final otherUserId = _getOtherUserId(chat);

    if (otherUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getCachedUserInfo(otherUserId),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: const Text('NEXAURA User'),
            subtitle: Text(
              'Profile error: ${userSnapshot.error}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.black12,
            ),
            title: Text('Loading user...'),
          );
        }

        final userInfo = userSnapshot.data ?? {};

        final userName =
            userInfo['name']?.toString() ?? 'NEXAURA User';

        final userPhoto =
            userInfo['photoUrl']?.toString() ?? '';

        return FutureBuilder<int>(
          future: _getCachedUnreadCount(chat.chatId),
          builder: (context, unreadSnapshot) {
            if (unreadSnapshot.hasError) {
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(userName),
                subtitle: Text(
                  'Unread count error: ${unreadSnapshot.error}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }

            final unreadCount = unreadSnapshot.data ?? 0;

            return ChatTile(
              chat: chat,
              userName: userName,
              userPhoto: userPhoto,
              currentUserId: currentUserId,
              unreadCount: unreadCount,
              isOnline: false,
              onTap: () {
                _openChat(
                  context,
                  chat,
                  otherUserId,
                  userName,
                  userPhoto,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view your chats.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshChats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        key: ValueKey(_refreshKey),
        stream: _chatService.getChats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: royalBlue,
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) {
              return const Divider(
                height: 1,
                indent: 80,
              );
            },
            itemBuilder: (context, index) {
              return _buildChatItem(chats[index]);
            },
          );
        },
      ),
    );
  }
}
