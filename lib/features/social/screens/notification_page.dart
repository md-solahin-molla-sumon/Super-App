import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/social_service.dart';
import 'user_profile_page.dart';
import 'other_user_profile_page.dart';
import 'social_feed_page.dart';

class NotificationPage extends StatelessWidget {
  NotificationPage({super.key});

  final SocialService _socialService = SocialService();

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Open Sender Profile
  Future<void> _openSenderProfile(BuildContext context, String senderId) async {
    if (senderId.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) return;

    if (currentUserId == senderId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserProfilePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherUserProfilePage(userId: senderId),
        ),
      );
    }
  }

  // Open Notification Destination
  Future<void> _openNotificationDestination(
    BuildContext context,
    NotificationModel notification,
  ) async {
    // Mark notification as read
    if (!notification.isRead) {
      await _markAsRead(context, notification.id);
    }

    if (!context.mounted) return;

    // Follow notification opens sender profile
    if (notification.type == 'follow') {
      await _openSenderProfile(context, notification.senderId);
      return;
    }

    // Like and Comment notifications open target post
    if (notification.type == 'like' || notification.type == 'comment') {
      if (notification.postId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post ID not found')));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SocialFeedPage(initialPostId: notification.postId),
        ),
      );
    }
  }

  // Mark All Notifications as Read
  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      await _socialService.markAllNotificationsAsRead();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Mark Single Notification as Read
  Future<void> _markAsRead(BuildContext context, String notificationId) async {
    try {
      await _socialService.markNotificationAsRead(notificationId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Build Avatar
  Widget _buildAvatar(NotificationModel notification) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.blue.shade100,
      backgroundImage: notification.senderPhoto.isNotEmpty
          ? NetworkImage(notification.senderPhoto)
          : null,
      child: notification.senderPhoto.isEmpty
          ? const Icon(Icons.person, color: Colors.blue, size: 28)
          : null,
    );
  }

  // Notification Icon
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;

      case 'comment':
        return Icons.comment;

      case 'follow':
        return Icons.person_add;

      default:
        return Icons.notifications;
    }
  }

  // Notification Color
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;

      case 'comment':
        return Colors.green;

      case 'follow':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  // Notification Item
  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
  ) {
    final icon = _getNotificationIcon(notification.type);

    final iconColor = _getNotificationColor(notification.type);

    return InkWell(
      // Main notification click
      onTap: () {
        _openNotificationDestination(context, notification);
      },

      child: Container(
        color: notification.isRead
            ? Colors.white
            : Colors.blue.withValues(alpha: 0.07),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        child: Row(
          children: [
            // Clickable Profile Picture
            GestureDetector(
              onTap: () async {
                if (!notification.isRead) {
                  await _markAsRead(context, notification.id);
                }

                if (!context.mounted) return;

                await _openSenderProfile(context, notification.senderId);
              },
              child: _buildAvatar(notification),
            ),

            const SizedBox(width: 12),

            // Notification Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),

                      children: [
                        // Clickable Sender Name
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () async {
                              if (!notification.isRead) {
                                await _markAsRead(context, notification.id);
                              }

                              if (!context.mounted) return;

                              await _openSenderProfile(
                                context,
                                notification.senderId,
                              );
                            },

                            child: Text(
                              notification.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),

                        const TextSpan(text: ' '),

                        TextSpan(text: notification.message),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Notification Type Icon
            Icon(icon, color: iconColor, size: 23),

            // Unread Indicator
            if (!notification.isRead) ...[
              const SizedBox(width: 8),

              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,

        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context),

            child: const Text('Mark all as read'),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _socialService.getNotifications(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 75, color: Colors.grey),

                  SizedBox(height: 12),

                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs.map((doc) {
            return NotificationModel.fromMap(doc.id, doc.data());
          }).toList();

          return ListView.separated(
            itemCount: notifications.length,

            separatorBuilder: (context, index) {
              return const Divider(height: 1, indent: 75);
            },

            itemBuilder: (context, index) {
              return _buildNotificationItem(context, notifications[index]);
            },
          );
        },
      ),
    );
  }
}
