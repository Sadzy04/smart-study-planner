import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _subjects =>
      _db.collection('subjects');

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _studySessions =>
      _db.collection('study_sessions');

  CollectionReference<Map<String, dynamic>> get _pyqTopics =>
      _db.collection('pyq_topics');

  CollectionReference<Map<String, dynamic>> get _blockedSlots =>
    _db.collection('blocked_slots');

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'You must be logged in to access data.',
      );
    }
    return user.uid;
  }

  Future<void> addSubject({
    required String subjectName,
    required DateTime examDate,
    required int estimatedHours,
    required String difficultyLevel,
    required String confidenceLevel,
  }) async {
    await _subjects.add({
      'userId': _currentUserId,
      'subjectName': subjectName,
      'examDate': Timestamp.fromDate(examDate),
      'estimatedHours': estimatedHours,
      'difficultyLevel': difficultyLevel,
      'confidenceLevel': confidenceLevel,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTask({
    required String title,
    required String subjectName,
    required DateTime dueDate,
    required String priority,
    required int estimatedMinutes,
    required String notes,
  }) async {
    await _tasks.add({
      'userId': _currentUserId,
      'title': title,
      'subjectName': subjectName,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'notes': notes,
      'completionStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addBlockedSlot({
  required String title,
  required String date,
  required String startTime,
  required String endTime,
  required String type,
  required bool isRecurring,
  int? dayOfWeek,
}) async {
  await _blockedSlots.add({
    'userId': _currentUserId,
    'title': title.trim(),
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'type': type,
    'isRecurring': isRecurring,
    'dayOfWeek': isRecurring ? dayOfWeek : null,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Stream<QuerySnapshot<Map<String, dynamic>>> getBlockedSlotsStream() {
  return _blockedSlots
      .where('userId', isEqualTo: _currentUserId)
      .snapshots();
}

Future<void> deleteBlockedSlot(String slotId) async {
  await _blockedSlots.doc(slotId).delete();
}

  Future<void> addStudySession({
    required String subjectName,
    required int durationMinutes,
    required int energyRating,
    required int focusRating,
    required String notes,
  }) async {
    await _studySessions.add({
      'userId': _currentUserId,
      'subjectName': subjectName,
      'durationMinutes': durationMinutes,
      'energyRating': energyRating,
      'focusRating': focusRating,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPyqTopic({
    required String subjectName,
    required String topicName,
    required int year,
    required int frequencyCount,
    required int marksWeight,
    required String questionText,
  }) async {
    await _pyqTopics.add({
      'userId': _currentUserId,
      'subjectName': subjectName,
      'topicName': topicName,
      'year': year,
      'frequencyCount': frequencyCount,
      'marksWeight': marksWeight,
      'questionText': questionText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSubjectsStream() {
    return _subjects
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasksStream() {
    return _tasks
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudySessionsStream() {
    return _studySessions
        .where('userId', isEqualTo: _currentUserId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPyqTopicsStream() {
    return _pyqTopics
        .where('userId', isEqualTo: _currentUserId)
        .snapshots();
  }

  

  Future<void> updateTaskStatus({
    required String taskId,
    required String newStatus,
  }) async {
    await _tasks.doc(taskId).update({
      'completionStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  Future<void> deleteSubject(String subjectId) async {
    await _subjects.doc(subjectId).delete();
  }

  Future<void> deletePyqTopic(String pyqId) async {
    await _pyqTopics.doc(pyqId).delete();
  }
}