import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _notes =>
      _firestore.collection('users').doc(_userId).collection('notes');

  // Get all notes
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotes() {
    return _notes.orderBy('updatedAt', descending: true).snapshots();
  }

  // Add note
  Future<void> addNote({required String title, required String content}) async {
    await _notes.add({
      'title': title.trim(),
      'content': content.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update note
  Future<void> updateNote({
    required String noteId,
    required String title,
    required String content,
  }) async {
    await _notes.doc(noteId).update({
      'title': title.trim(),
      'content': content.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete note
  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }
}
