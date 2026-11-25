import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('users').doc(_userId).collection('tasks');

  // Get all tasks
  Stream<QuerySnapshot<Map<String, dynamic>>> getTasks() {
    return _tasks.orderBy('createdAt', descending: true).snapshots();
  }

  // Add new task
  Future<void> addTask({
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    await _tasks.add({
      'title': title.trim(),
      'description': description.trim(),
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update task
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    await _tasks.doc(taskId).update({
      'title': title.trim(),
      'description': description.trim(),
      'dueDate': Timestamp.fromDate(dueDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update task completion status
  Future<void> toggleTaskStatus({
    required String taskId,
    required bool isCompleted,
  }) async {
    await _tasks.doc(taskId).update({
      'isCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }
}
