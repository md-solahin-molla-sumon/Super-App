import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Get Comments Collection
  CollectionReference<Map<String, dynamic>> _commentsCollection(String postId) {
    return _firestore.collection('posts').doc(postId).collection('comments');
  }

  // Add New Comment + Notification
  Future<void> addComment({
    required String postId,
    required String content,
    required String userName,
    String userPhoto = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    // Get Post Owner
    final postRef = _firestore.collection('posts').doc(postId);

    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) {
      throw Exception('Post not found');
    }

    final postOwnerId = postSnapshot.data()?['userId']?.toString() ?? '';

    if (postOwnerId.isEmpty) {
      throw Exception('Post owner not found');
    }

    // Create Comment
    final commentRef = _commentsCollection(postId).doc();

    final comment = CommentModel(
      commentId: commentRef.id,
      userId: user.uid,
      userName: userName,
      userPhoto: userPhoto,
      content: trimmedContent,
      createdAt: DateTime.now(),
    );

    final commentData = comment.toMap();

    commentData['createdAt'] = FieldValue.serverTimestamp();

    // Batch Write
    final batch = _firestore.batch();

    batch.set(commentRef, commentData);

    // Create Notification only for another user's post
    if (postOwnerId != user.uid) {
      final notificationRef = _firestore
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications')
          .doc();

      batch.set(notificationRef, {
        'type': 'comment',
        'senderId': user.uid,
        'senderName': userName,
        'senderPhoto': userPhoto,
        'postId': postId,
        'message': 'commented on your post: $trimmedContent',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get All Comments
  Stream<List<CommentModel>> getComments(String postId) {
    return _commentsCollection(
      postId,
    ).orderBy('createdAt', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommentModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Delete Comment
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    final commentRef = _commentsCollection(postId).doc(commentId);

    final snapshot = await commentRef.get();

    if (!snapshot.exists) {
      throw Exception('Comment not found');
    }

    if (snapshot.data()?['userId'] != user.uid) {
      throw Exception('You can delete only your comment');
    }

    await commentRef.delete();
  }
}
