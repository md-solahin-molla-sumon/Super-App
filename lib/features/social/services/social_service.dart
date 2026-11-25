
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';
import '../models/story_model.dart';
import 'cloudinary_service.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  CollectionReference<Map<String, dynamic>> get _postsCollection {
    return _firestore.collection('posts');
  }

  CollectionReference<Map<String, dynamic>> get _storiesCollection {
    return _firestore.collection('stories');
  }

  User? get currentUser => _auth.currentUser;

  static const List<String> storyReactionTypes = [
    'like',
    'love',
    'haha',
    'wow',
    'sad',
    'angry',
  ];

  CollectionReference<Map<String, dynamic>> get _notificationsCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications');
  }

  Future<void> _createNotification({
    required String receiverId,
    required String type,
    required String message,
    String postId = '',
  }) async {
    final sender = _auth.currentUser;

    if (sender == null || sender.uid == receiverId) return;

    final senderSnapshot =
        await _firestore.collection('users').doc(sender.uid).get();

    final senderData = senderSnapshot.data() ?? {};

    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .add({
      'type': type,
      'senderId': sender.uid,
      'senderName': senderData['name'] ?? 'Nexaura User',
      'senderPhoto': senderData['photoUrl'] ?? '',
      'postId': postId,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== NOTIFICATION SYSTEM ====================

  Stream<QuerySnapshot<Map<String, dynamic>>> getNotifications() {
    return _notificationsCollection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    final snapshot = await _notificationsCollection
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Stream<int> getUnreadNotificationCount() {
    return _notificationsCollection
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ==================== SAVED POSTS ====================

  CollectionReference<Map<String, dynamic>> get _savedPostsCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPosts');
  }

  // ==================== POST SYSTEM ====================

  Future<void> createPost({
    required String content,
    String imageUrl = '',
    required String userName,
    String userPhoto = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    if (content.trim().isEmpty && imageUrl.trim().isEmpty) {
      throw Exception('Post cannot be empty');
    }

    final postRef = _postsCollection.doc();

    final post = PostModel(
      postId: postRef.id,
      userId: user.uid,
      userName: userName,
      userPhoto: userPhoto,
      content: content.trim(),
      imageUrl: imageUrl.trim(),
      likes: [],
      createdAt: DateTime.now(),
    );

    final postData = post.toMap();
    postData['createdAt'] = FieldValue.serverTimestamp();

    await postRef.set(postData);
  }

  Future<void> updatePost({
    required String postId,
    required String content,
    String imageUrl = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    if (content.trim().isEmpty && imageUrl.trim().isEmpty) {
      throw Exception('Post cannot be empty');
    }

    final postRef = _postsCollection.doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);

      if (!snapshot.exists) throw Exception('Post not found');

      final data = snapshot.data()!;

      if (data['userId'] != user.uid) {
        throw Exception('You are not allowed to edit this post');
      }

      transaction.update(postRef, {
        'content': content.trim(),
        'imageUrl': imageUrl.trim(),
      });
    });
  }

  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final postRef = _postsCollection.doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);

      if (!snapshot.exists) throw Exception('Post not found');

      if (snapshot.data()!['userId'] != user.uid) {
        throw Exception('You are not allowed to delete this post');
      }

      transaction.delete(postRef);
    });
  }

  Stream<List<PostModel>> getPosts() {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final postRef = _postsCollection.doc(postId);

    final result = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);

      if (!snapshot.exists) throw Exception('Post not found');

      final data = snapshot.data()!;
      final likes = List<String>.from(data['likes'] ?? []);
      final postOwnerId = data['userId'] as String;

      if (likes.contains(user.uid)) {
        transaction.update(postRef, {
          'likes': FieldValue.arrayRemove([user.uid]),
        });

        return {'liked': false, 'ownerId': postOwnerId};
      } else {
        transaction.update(postRef, {
          'likes': FieldValue.arrayUnion([user.uid]),
        });

        return {'liked': true, 'ownerId': postOwnerId};
      }
    });

    if (result['liked'] == true) {
      await _createNotification(
        receiverId: result['ownerId'] as String,
        type: 'like',
        message: 'liked your post',
        postId: postId,
      );
    }
  }

  Future<void> toggleSavePost(String postId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final savedPostRef = _savedPostsCollection.doc(postId);
    final snapshot = await savedPostRef.get();

    if (snapshot.exists) {
      await savedPostRef.delete();
    } else {
      await savedPostRef.set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> isPostSaved(String postId) async {
    if (_auth.currentUser == null) return false;

    final snapshot = await _savedPostsCollection.doc(postId).get();

    return snapshot.exists;
  }

  Stream<List<String>> getSavedPostIds() {
    return _savedPostsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Stream<List<PostModel>> getSavedPosts() {
    return getSavedPostIds().asyncExpand((savedPostIds) {
      if (savedPostIds.isEmpty) {
        return Stream.value(<PostModel>[]);
      }

      return _postsCollection
          .where(
            FieldPath.documentId,
            whereIn: savedPostIds.take(30).toList(),
          )
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data()))
            .toList();
      });
    });
  }

  Stream<List<PostModel>> getMyPosts() {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    return _postsCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data()))
          .toList();

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return posts;
    });
  }

  // ==================== FOLLOW SYSTEM ====================

  Future<void> toggleFollow(String targetUserId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    if (user.uid == targetUserId) {
      throw Exception('You cannot follow yourself');
    }

    final followerRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(user.uid);

    final followingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId);

    final isNowFollowing =
        await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(followerRef);

      if (snapshot.exists) {
        transaction.delete(followerRef);
        transaction.delete(followingRef);
        return false;
      } else {
        transaction.set(followerRef, {
          'uid': user.uid,
          'followedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(followingRef, {
          'uid': targetUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });

        return true;
      }
    });

    if (isNowFollowing) {
      await _createNotification(
        receiverId: targetUserId,
        type: 'follow',
        message: 'started following you',
      );
    }
  }

  Stream<bool> isFollowing(String targetUserId) {
    final user = _auth.currentUser;

    if (user == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<int> getFollowersCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getFollowingCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ==================== STORY SYSTEM ====================

  Future<void> createStory({
    required String userName,
    required String userPhoto,
    required String mediaType,
    Uint8List? mediaBytes,
    String fileName = '',
    String text = '',
    int backgroundColor = 0xFF6514E8,
    Uint8List? audioBytes,
    String audioFileName = '',
    String? audioFilePath,
    Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    const supportedTypes = [
      'image',
      'video',
      'image_audio',
      'audio',
      'text_audio',
      'text',
    ];

    if (!supportedTypes.contains(mediaType)) {
      throw Exception('Unsupported story type: $mediaType');
    }

    final needsImage =
        mediaType == 'image' || mediaType == 'image_audio';

    final needsVideo = mediaType == 'video';

    final needsAudio = mediaType == 'audio' ||
        mediaType == 'image_audio' ||
        mediaType == 'text_audio';

    final needsText =
        mediaType == 'text' || mediaType == 'text_audio';

    if (needsImage && (mediaBytes == null || mediaBytes.isEmpty)) {
      throw Exception('Please select an image');
    }

    if (needsVideo && (mediaBytes == null || mediaBytes.isEmpty)) {
      throw Exception('Please select a video');
    }

    if (needsAudio &&
        (audioBytes == null || audioBytes.isEmpty) &&
        (audioFilePath == null || audioFilePath.isEmpty)) {
      throw Exception('Please select an audio file');
    }

    if (needsText && text.trim().isEmpty) {
      throw Exception('Please enter your story text');
    }

    final storyRef = _storiesCollection.doc();
    final progressCallback = onProgress ?? (_) {};

    String mediaUrl = '';
    String audioUrl = '';

    if (needsImage) {
      mediaUrl = await _cloudinaryService.uploadImage(
        imageBytes: mediaBytes!,
        fileName: fileName.isEmpty ? '${storyRef.id}.jpg' : fileName,
        folder: 'nexaura/stories/images',
        onProgress: progressCallback,
      );
    } else if (needsVideo) {
      mediaUrl = await _cloudinaryService.uploadVideo(
        videoBytes: mediaBytes!,
        fileName: fileName.isEmpty ? '${storyRef.id}.mp4' : fileName,
        folder: 'nexaura/stories/videos',
        onProgress: progressCallback,
      );
    }

    if (needsAudio) {
      if (audioBytes != null && audioBytes.isNotEmpty) {
        audioUrl = await _cloudinaryService.uploadAudioBytes(
          audioBytes: audioBytes,
          fileName:
              audioFileName.isEmpty ? '${storyRef.id}.m4a' : audioFileName,
          folder: 'nexaura/stories/audio',
          onProgress: progressCallback,
        );
      } else {
        audioUrl = await _cloudinaryService.uploadAudio(
          filePath: audioFilePath!,
          fileName:
              audioFileName.isEmpty ? '${storyRef.id}.m4a' : audioFileName,
          onProgress: progressCallback,
        );
      }
    }

    final now = DateTime.now();

    await storyRef.set({
      'storyId': storyRef.id,
      'userId': user.uid,
      'userName': userName,
      'userPhoto': userPhoto,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'audioUrl': audioUrl,
      'text': text.trim(),
      'backgroundColor': backgroundColor,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        now.add(const Duration(hours: 24)),
      ),
      'viewedBy': <String>[],
      // Kept for compatibility with existing story documents/UI.
      // Live reaction counts are now calculated from the reactions
      // subcollection, not from this map.
      'reactionCounts': <String, int>{
        'like': 0,
        'love': 0,
        'haha': 0,
        'wow': 0,
        'sad': 0,
        'angry': 0,
      },
    });
  }

  Stream<List<StoryModel>> getStories() {
    return _storiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();

      return snapshot.docs
          .map((doc) => StoryModel.fromMap(doc.data()))
          .where((story) => story.expiresAt.isAfter(now))
          .toList();
    });
  }

  Stream<List<StoryModel>> getMyStories() {
    final user = _auth.currentUser;

    if (user == null) return Stream.value(<StoryModel>[]);

    return _storiesCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();

      final stories = snapshot.docs
          .map((doc) => StoryModel.fromMap(doc.data()))
          .where((story) => story.expiresAt.isAfter(now))
          .toList();

      stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return stories;
    });
  }

  Future<void> markStoryViewed(String storyId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final storyRef = _storiesCollection.doc(storyId);
    final viewRef = storyRef.collection('views').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(storyRef);

      if (!snapshot.exists) throw Exception('Story not found');

      final data = snapshot.data()!;

      if (data['userId'] == user.uid) return;

      final expiresAt = data['expiresAt'];

      if (expiresAt is Timestamp &&
          !expiresAt.toDate().isAfter(DateTime.now())) {
        throw Exception('This story has expired');
      }

      final viewSnapshot = await transaction.get(viewRef);

      if (viewSnapshot.exists) return;

      transaction.update(storyRef, {
        'viewedBy': FieldValue.arrayUnion([user.uid]),
      });

      transaction.set(viewRef, {
        'userId': user.uid,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStoryViews(
    String storyId,
  ) {
    return _storiesCollection
        .doc(storyId)
        .collection('views')
        .orderBy('viewedAt', descending: true)
        .snapshots();
  }

  // ==================== STORY REACTIONS ====================

  CollectionReference<Map<String, dynamic>> _storyReactionsCollection(
    String storyId,
  ) {
    return _storiesCollection.doc(storyId).collection('reactions');
  }

  String _storyReactionDocumentId(String userId, String reaction) {
    return '${userId}_$reaction';
  }

  void _validateStoryReaction(String reaction) {
    if (!storyReactionTypes.contains(reaction)) {
      throw Exception('Invalid story reaction');
    }
  }

  Future<void> _checkStoryCanBeReactedTo(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> storyRef,
  ) async {
    final storySnapshot = await transaction.get(storyRef);

    if (!storySnapshot.exists) {
      throw Exception('Story not found');
    }

    final expiresAt = storySnapshot.data()?['expiresAt'];

    if (expiresAt is Timestamp &&
        !expiresAt.toDate().isAfter(DateTime.now())) {
      throw Exception('This story has expired');
    }
  }

  /// Toggles one specific reaction.
  ///
  /// Returns true if the reaction was added.
  /// Returns false if the reaction was removed.
  ///
  /// A user can have multiple different reactions on one story.
  Future<bool> toggleStoryReaction({
    required String storyId,
    required String reaction,
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    _validateStoryReaction(reaction);

    final storyRef = _storiesCollection.doc(storyId);

    final reactionRef = _storyReactionsCollection(storyId).doc(
      _storyReactionDocumentId(user.uid, reaction),
    );

    return _firestore.runTransaction<bool>((transaction) async {
      await _checkStoryCanBeReactedTo(transaction, storyRef);

      final reactionSnapshot = await transaction.get(reactionRef);

      if (reactionSnapshot.exists) {
        transaction.delete(reactionRef);
        return false;
      }

      transaction.set(reactionRef, {
        'userId': user.uid,
        'reaction': reaction,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  /// Adds a reaction without removing an existing one.
  ///
  /// Kept for compatibility with older code that calls
  /// setStoryReaction().
  Future<void> setStoryReaction({
    required String storyId,
    required String reaction,
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    _validateStoryReaction(reaction);

    final storyRef = _storiesCollection.doc(storyId);

    final reactionRef = _storyReactionsCollection(storyId).doc(
      _storyReactionDocumentId(user.uid, reaction),
    );

    await _firestore.runTransaction((transaction) async {
      await _checkStoryCanBeReactedTo(transaction, storyRef);

      final reactionSnapshot = await transaction.get(reactionRef);

      if (reactionSnapshot.exists) return;

      transaction.set(reactionRef, {
        'userId': user.uid,
        'reaction': reaction,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Removes one reaction when [reaction] is supplied.
  ///
  /// If reaction is omitted, removes all reactions belonging
  /// to the current user on this story.
  ///
  /// The optional parameter preserves compatibility with
  /// older calls to removeStoryReaction(storyId).
  Future<void> removeStoryReaction(
    String storyId, {
    String? reaction,
  }) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final reactionsCollection = _storyReactionsCollection(storyId);

    if (reaction != null) {
      _validateStoryReaction(reaction);

      final reactionRef = reactionsCollection.doc(
        _storyReactionDocumentId(user.uid, reaction),
      );

      await reactionRef.delete();
      return;
    }

    final snapshot = await reactionsCollection
        .where('userId', isEqualTo: user.uid)
        .get();

    // Firestore batch supports at most 500 writes.
    for (var start = 0; start < snapshot.docs.length; start += 500) {
      final batch = _firestore.batch();

      final end = (start + 500 < snapshot.docs.length)
          ? start + 500
          : snapshot.docs.length;

      for (var i = start; i < end; i++) {
        batch.delete(snapshot.docs[i].reference);
      }

      await batch.commit();
    }
  }

  /// Live stream of all reactions on a story.
  ///
  /// Each document represents one user's one reaction.
  Stream<QuerySnapshot<Map<String, dynamic>>> getStoryReactions(
    String storyId,
  ) {
    return _storyReactionsCollection(storyId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Live counts grouped by reaction type.
  ///
  /// Counts are calculated from the reaction documents.
  /// No parent story document update is required.
  Stream<Map<String, int>> getStoryReactionCounts(String storyId) {
    return _storyReactionsCollection(storyId).snapshots().map((snapshot) {
      final counts = <String, int>{
        'like': 0,
        'love': 0,
        'haha': 0,
        'wow': 0,
        'sad': 0,
        'angry': 0,
      };

      for (final doc in snapshot.docs) {
        final reaction = doc.data()['reaction'];

        if (reaction is String && counts.containsKey(reaction)) {
          counts[reaction] = counts[reaction]! + 1;
        }
      }

      return counts;
    });
  }

  /// Live stream of all reactions made by the current user.
  Stream<Set<String>> getMyStoryReactions(String storyId) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(<String>{});
    }

    return _storyReactionsCollection(storyId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final reactions = <String>{};

      for (final doc in snapshot.docs) {
        final reaction = doc.data()['reaction'];

        if (reaction is String &&
            storyReactionTypes.contains(reaction)) {
          reactions.add(reaction);
        }
      }

      return reactions;
    });
  }

  /// Legacy single-reaction stream.
  ///
  /// Kept so older UI code using getMyStoryReaction()
  /// does not immediately break.
  ///
  /// For the new multiple-reaction UI, use getMyStoryReactions().
  Stream<String?> getMyStoryReaction(String storyId) {
    return getMyStoryReactions(storyId).map((reactions) {
      if (reactions.isEmpty) return null;

      return reactions.first;
    });
  }

  // ==================== DELETE STORY ====================

  Future<void> deleteStory(String storyId) async {
    final user = _auth.currentUser;

    if (user == null) throw Exception('Please login first');

    final storyRef = _storiesCollection.doc(storyId);
    final snapshot = await storyRef.get();

    if (!snapshot.exists) throw Exception('Story not found');

    final data = snapshot.data()!;

    if (data['userId'] != user.uid) {
      throw Exception('You are not allowed to delete this story');
    }

    // Firestore does not automatically delete subcollections.
    // Cloudinary deletion requires a secure server-side endpoint.
    await storyRef.delete();
  }
}
