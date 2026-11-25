import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create User Profile
  Future<void> createUserProfile({
    required String name,
    required String email,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': email,
      'photoUrl': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get User Profile
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore.collection('users').doc(user.uid).get();
  }

  // Update User Profile
  Future<void> updateUserProfile({
    required String name,
    required String bio,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final Map<String, dynamic> updateData = {
      'name': name,
      'bio': bio,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      updateData['photoUrl'] = photoUrl;
    }

    await _firestore.collection('users').doc(user.uid).update(updateData);
  }
}
