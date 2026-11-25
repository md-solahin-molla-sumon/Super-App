import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('users').doc(_userId).collection('calendar_events');

  Stream<QuerySnapshot<Map<String, dynamic>>> getEvents() {
    return _events.orderBy('eventDate').snapshots();
  }

  Future<void> addEvent({
    required String title,
    required String description,
    required DateTime eventDate,
  }) async {
    await _events.add({
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': Timestamp.fromDate(eventDate),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime eventDate,
  }) async {
    await _events.doc(eventId).update({
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': Timestamp.fromDate(eventDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent(String eventId) async {
    await _events.doc(eventId).delete();
  }
}
