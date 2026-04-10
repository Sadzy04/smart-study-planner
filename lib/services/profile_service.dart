import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'You must be logged in to access profile data.',
      );
    }
    return user.uid;
  }

  User get _currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'You must be logged in to access profile data.',
      );
    }
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);

  Map<String, dynamic> _defaultProfile(User user) {
    return {
      'name': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Student',
      'email': user.email ?? '',
      'semester': '',
      'wakeTime': '07:00',
      'sleepTime': '23:00',
      'preferredStudyHours': 4,
      'maxStudyBlockMinutes': 90,
      'preferredBreakMinutes': 15,
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final user = _currentUser;
    final defaults = _defaultProfile(user);
    final snapshot = await _userDoc.get();

    if (!snapshot.exists) {
      await _userDoc.set({
        ...defaults,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return defaults;
    }

    final data = snapshot.data() ?? {};
    final merged = {
      ...defaults,
      ...data,
    };

    // Make sure older user docs also receive the new fields.
    await _userDoc.set({
      ...merged,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return merged;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileStream() {
    return _userDoc.snapshots();
  }

  Future<void> updateProfile({
    required String name,
    required String semester,
    required String wakeTime,
    required String sleepTime,
    required int preferredStudyHours,
    required int maxStudyBlockMinutes,
    required int preferredBreakMinutes,
  }) async {
    final user = _currentUser;

    await _userDoc.set({
      'name': name.trim(),
      'email': user.email ?? '',
      'semester': semester.trim(),
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'preferredStudyHours': preferredStudyHours,
      'maxStudyBlockMinutes': maxStudyBlockMinutes,
      'preferredBreakMinutes': preferredBreakMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}