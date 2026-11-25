import 'package:flutter/material.dart';

import '../models/chat_model.dart';

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String userName;
  final String userPhoto;
  final String currentUserId;
  final int unreadCount;
  final VoidCallback onTap;
  final bool isOnline;

  const ChatTile({
    super.key,
    required this.chat,
    required this.userName,
    required this.userPhoto,
    required this.currentUserId,
    required this.onTap,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  static const Color navy = Color(0xFF101D36);
  static const Color royalBlue = Color(0xFF1D3557);

  // Format Message Time
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();

    if (now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;

      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    final difference = now.difference(dateTime);

    if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return days[dateTime.weekday - 1];
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Last Message Preview
  String _getLastMessage() {
    if (chat.lastMessage.isEmpty) {
      return 'Start a conversation';
    }

    if (chat.lastMessageSenderId == currentUserId) {
      return 'You: ${chat.lastMessage}';
    }

    return chat.lastMessage;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        child: Row(
          children: [
            // User Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: royalBlue,

                  backgroundImage: userPhoto.isNotEmpty
                      ? NetworkImage(userPhoto)
                      : null,

                  child: userPhoto.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'N',

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),

                // Online Indicator
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,

                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 13),

            // User Name and Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: navy,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _getLastMessage(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: unreadCount > 0 ? navy : Colors.grey.shade600,

                      fontSize: 13,

                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Time and Unread Count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(chat.lastMessageTime),

                  style: TextStyle(
                    color: unreadCount > 0 ? royalBlue : Colors.grey.shade500,

                    fontSize: 11,
                  ),
                ),

                if (unreadCount > 0) ...[
                  const SizedBox(height: 7),

                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),

                    decoration: const BoxDecoration(
                      color: royalBlue,
                      shape: BoxShape.circle,
                    ),

                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
