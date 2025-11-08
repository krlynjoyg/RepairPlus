import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  static Future<void> addTutorialToHistory({
    required String title,
    required String type,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    await FirebaseFirestore.instance.collection('history').add({
      'uid': user.uid,
      'title': title,
      'type': 'tutorial',
      'subtype': type,
      'status': status,
      'date': date,
      'time': time,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
