import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class FastapiService {
  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(_uri('/health'));

    if (response.statusCode != 200) {
      throw Exception('Health check failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateStudyPlan({
    required Map<String, dynamic> profile,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    DateTime? forDate,
  }) async {
    final payload = _buildPayload(
      profile: profile,
      subjectDocs: subjectDocs,
      taskDocs: taskDocs,
      pyqDocs: pyqDocs,
      blockedSlotDocs: blockedSlotDocs,
      forDate: forDate,
    );

    final response = await http.post(
      _uri('/generate-study-plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Generate plan failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeWorkload({
    required Map<String, dynamic> profile,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    DateTime? forDate,
  }) async {
    final payload = _buildPayload(
      profile: profile,
      subjectDocs: subjectDocs,
      taskDocs: taskDocs,
      pyqDocs: pyqDocs,
      blockedSlotDocs: blockedSlotDocs,
      forDate: forDate,
    );

    final response = await http.post(
      _uri('/analyze-workload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Analyze workload failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recommendBreaks({
    required Map<String, dynamic> profile,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    DateTime? forDate,
  }) async {
    final payload = _buildPayload(
      profile: profile,
      subjectDocs: subjectDocs,
      taskDocs: taskDocs,
      pyqDocs: pyqDocs,
      blockedSlotDocs: blockedSlotDocs,
      forDate: forDate,
    );

    final response = await http.post(
      _uri('/recommend-breaks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Recommend breaks failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _buildPayload({
    required Map<String, dynamic> profile,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    DateTime? forDate,
  }) {
    return {
      'profile': {
        'name': (profile['name'] ?? '').toString(),
        'semester': (profile['semester'] ?? '').toString(),
        'wakeTime': (profile['wakeTime'] ?? '07:00').toString(),
        'sleepTime': (profile['sleepTime'] ?? '23:00').toString(),
        'preferredStudyHours':
            ((profile['preferredStudyHours'] ?? 4) as num).toInt(),
        'maxStudyBlockMinutes':
            ((profile['maxStudyBlockMinutes'] ?? 90) as num).toInt(),
        'preferredBreakMinutes':
            ((profile['preferredBreakMinutes'] ?? 15) as num).toInt(),
      },
      'subjects': subjectDocs.map((doc) {
        final data = doc.data();
        return {
          'subjectName': (data['subjectName'] ?? '').toString(),
          'examDate': _toIsoDate(data['examDate']),
          'estimatedHours': ((data['estimatedHours'] ?? 0) as num).toInt(),
          'difficultyLevel': (data['difficultyLevel'] ?? 'Medium').toString(),
          'confidenceLevel': (data['confidenceLevel'] ?? 'Medium').toString(),
        };
      }).toList(),
      'tasks': taskDocs.map((doc) {
        final data = doc.data();
        return {
          'title': (data['title'] ?? '').toString(),
          'subjectName': (data['subjectName'] ?? 'General').toString(),
          'dueDate': _toIsoDate(data['dueDate']),
          'priority': (data['priority'] ?? 'Medium').toString(),
          'completionStatus': data['completionStatus']?.toString(),
          'status': data['status']?.toString(),
          'estimatedMinutes':
              ((data['estimatedMinutes'] ?? 60) as num).toInt(),
          'notes': (data['notes'] ?? '').toString(),
        };
      }).toList(),
      'pyqTopics': pyqDocs.map((doc) {
        final data = doc.data();
        return {
          'subjectName': (data['subjectName'] ?? '').toString(),
          'topicName': (data['topicName'] ?? '').toString(),
          'frequencyCount': ((data['frequencyCount'] ?? 0) as num).toInt(),
          'marksWeight': ((data['marksWeight'] ?? 0) as num).toInt(),
        };
      }).toList(),
      'blockedSlots': blockedSlotDocs.map((doc) {
        final data = doc.data();
        return {
          'title': (data['title'] ?? '').toString(),
          'date': data['date']?.toString(),
          'startTime': (data['startTime'] ?? '00:00').toString(),
          'endTime': (data['endTime'] ?? '00:00').toString(),
          'type': (data['type'] ?? 'other').toString(),
          'isRecurring': data['isRecurring'] == true,
          'dayOfWeek': data['dayOfWeek'] == null
              ? null
              : ((data['dayOfWeek'] as num).toInt()),
        };
      }).toList(),
      'forDate': (forDate ?? DateTime.now()).toIso8601String().split('T').first,
    };
  }

  String? _toIsoDate(dynamic raw) {
    if (raw == null) return null;

    if (raw is Timestamp) {
      return raw.toDate().toIso8601String().split('T').first;
    }

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed != null) {
      return parsed.toIso8601String().split('T').first;
    }

    return raw.toString();
  }
}