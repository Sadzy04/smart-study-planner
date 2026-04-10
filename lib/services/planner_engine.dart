import 'package:cloud_firestore/cloud_firestore.dart';

class PlanItem {
  final String timeLabel;
  final String title;
  final String subjectName;
  final String subtitle;
  final String reason;
  final int score;
  final bool isBreak;
  final bool isTask;

  const PlanItem({
    required this.timeLabel,
    required this.title,
    required this.subjectName,
    required this.subtitle,
    required this.reason,
    required this.score,
    required this.isBreak,
    required this.isTask,
  });
}

class PlanResult {
  final List<PlanItem> items;
  final String summary;
  final int totalStudyMinutes;
  final int totalBreakMinutes;
  final int freeWindowCount;
  final String wakeTime;
  final String sleepTime;
  final int blockedCountToday;

  const PlanResult({
    required this.items,
    required this.summary,
    required this.totalStudyMinutes,
    required this.totalBreakMinutes,
    required this.freeWindowCount,
    required this.wakeTime,
    required this.sleepTime,
    required this.blockedCountToday,
  });
}

class _TimeWindow {
  final int startMinute;
  final int endMinute;

  const _TimeWindow({
    required this.startMinute,
    required this.endMinute,
  });

  int get duration => endMinute - startMinute;
}

class _PlanCandidate {
  final String title;
  final String subjectName;
  final String subtitle;
  final String reason;
  final int score;
  final int desiredMinutes;
  final bool isTask;

  const _PlanCandidate({
    required this.title,
    required this.subjectName,
    required this.subtitle,
    required this.reason,
    required this.score,
    required this.desiredMinutes,
    required this.isTask,
  });
}

class PlannerEngine {
  static PlanResult generate({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    required Map<String, dynamic> profile,
    DateTime? forDate,
  }) {
    final targetDate = forDate ?? DateTime.now();

    final wakeTime = (profile['wakeTime'] ?? '07:00').toString();
    final sleepTime = (profile['sleepTime'] ?? '23:00').toString();

    final preferredStudyHours =
        ((profile['preferredStudyHours'] ?? 4) as num).toInt().clamp(1, 16);
    final maxStudyBlockMinutes =
        ((profile['maxStudyBlockMinutes'] ?? 90) as num).toInt().clamp(30, 180);
    final preferredBreakMinutes =
        ((profile['preferredBreakMinutes'] ?? 15) as num).toInt().clamp(5, 60);

   int wakeMinute = _parseTimeToMinutes(wakeTime);
int sleepMinute = _parseTimeToMinutes(sleepTime);

// If sleep time is numerically earlier than wake time,
// treat it as the end of the same day / after midnight.
// Example: wake 9:00 AM, sleep 12:00 AM => sleep becomes 24:00.
if (sleepMinute <= wakeMinute) {
  sleepMinute += 24 * 60;
}

    final blockedWindows = _buildBlockedWindowsForDate(
      blockedSlotDocs: blockedSlotDocs,
      targetDate: targetDate,
      wakeMinute: wakeMinute,
      sleepMinute: sleepMinute,
    );

    final freeWindows = _buildFreeWindows(
      wakeMinute: wakeMinute,
      sleepMinute: sleepMinute,
      blockedWindows: blockedWindows,
    );

    final pyqBoostBySubject = _buildPyqSubjectBoost(pyqDocs);
    final pyqTopicNamesBySubject = _buildPyqTopicsBySubject(pyqDocs);

    final candidates = <_PlanCandidate>[
      ..._buildTaskCandidates(
        taskDocs: taskDocs,
        subjectDocs: subjectDocs,
        pyqBoostBySubject: pyqBoostBySubject,
        pyqTopicNamesBySubject: pyqTopicNamesBySubject,
        maxStudyBlockMinutes: maxStudyBlockMinutes,
        today: targetDate,
      ),
      ..._buildSubjectRevisionCandidates(
        subjectDocs: subjectDocs,
        pyqBoostBySubject: pyqBoostBySubject,
        maxStudyBlockMinutes: maxStudyBlockMinutes,
        today: targetDate,
      ),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final totalGoalMinutes = preferredStudyHours * 60;
    final scheduledItems = <PlanItem>[];

    int remainingGoalMinutes = totalGoalMinutes;
    int totalStudyMinutes = 0;
    int totalBreakMinutes = 0;
    int candidateIndex = 0;

    for (final window in freeWindows) {
      if (remainingGoalMinutes <= 0 || candidateIndex >= candidates.length) {
        break;
      }

      int cursor = window.startMinute;

      while (cursor < window.endMinute &&
          remainingGoalMinutes > 0 &&
          candidateIndex < candidates.length) {
        final candidate = candidates[candidateIndex];

        int blockMinutes = candidate.desiredMinutes;
        blockMinutes = blockMinutes.clamp(25, maxStudyBlockMinutes);
        blockMinutes = blockMinutes > remainingGoalMinutes
            ? remainingGoalMinutes
            : blockMinutes;

        final availableInWindow = window.endMinute - cursor;
        if (availableInWindow < 25) {
          break;
        }

        if (blockMinutes > availableInWindow) {
          blockMinutes = availableInWindow;
        }

        if (blockMinutes < 25) {
          break;
        }

        final blockStart = cursor;
        final blockEnd = cursor + blockMinutes;

        scheduledItems.add(
          PlanItem(
            timeLabel:
                '${_formatMinutes(blockStart)} - ${_formatMinutes(blockEnd)}',
            title: candidate.title,
            subjectName: candidate.subjectName,
            subtitle: candidate.subtitle,
            reason: candidate.reason,
            score: candidate.score,
            isBreak: false,
            isTask: candidate.isTask,
          ),
        );

        totalStudyMinutes += blockMinutes;
        remainingGoalMinutes -= blockMinutes;
        cursor = blockEnd;
        candidateIndex++;

        final canAddBreak = candidateIndex < candidates.length &&
            remainingGoalMinutes > 0 &&
            (window.endMinute - cursor) >= preferredBreakMinutes + 25;

        if (canAddBreak) {
          final breakStart = cursor;
          final breakEnd = cursor + preferredBreakMinutes;

          scheduledItems.add(
            PlanItem(
              timeLabel:
                  '${_formatMinutes(breakStart)} - ${_formatMinutes(breakEnd)}',
              title: 'Break',
              subjectName: 'Recovery',
              subtitle: '$preferredBreakMinutes minute recovery break',
              reason: 'Inserted automatically between study blocks.',
              score: 0,
              isBreak: true,
              isTask: false,
            ),
          );

          totalBreakMinutes += preferredBreakMinutes;
          cursor = breakEnd;
        }
      }
    }

    final summary = _buildSummary(
      targetDate: targetDate,
      freeWindows: freeWindows,
      blockedCountToday: blockedWindows.length,
      totalStudyMinutes: totalStudyMinutes,
      totalBreakMinutes: totalBreakMinutes,
      preferredStudyHours: preferredStudyHours,
      scheduledCount:
          scheduledItems.where((item) => !item.isBreak).length,
    );

    return PlanResult(
      items: scheduledItems,
      summary: summary,
      totalStudyMinutes: totalStudyMinutes,
      totalBreakMinutes: totalBreakMinutes,
      freeWindowCount: freeWindows.length,
      wakeTime: wakeTime,
      sleepTime: sleepTime,
      blockedCountToday: blockedWindows.length,
    );
  }

  static List<_TimeWindow> _buildBlockedWindowsForDate({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
    required DateTime targetDate,
    required int wakeMinute,
    required int sleepMinute,
  }) {
    final rawWindows = <_TimeWindow>[];
    final targetDateString = _formatDateStorage(targetDate);

    for (final doc in blockedSlotDocs) {
      final data = doc.data();

      final isRecurring = data['isRecurring'] == true;
      final slotDate = data['date']?.toString() ?? '';
      final dayOfWeek = ((data['dayOfWeek'] ?? 0) as num).toInt();

      final appliesToday = isRecurring
          ? dayOfWeek == targetDate.weekday
          : slotDate == targetDateString;

      if (!appliesToday) continue;

      final startTime = data['startTime']?.toString() ?? '';
      final endTime = data['endTime']?.toString() ?? '';

      final startMinute = _parseTimeToMinutes(startTime);
      final endMinute = _parseTimeToMinutes(endTime);

      if (endMinute <= startMinute) continue;

      final clippedStart = startMinute < wakeMinute ? wakeMinute : startMinute;
      final clippedEnd = endMinute > sleepMinute ? sleepMinute : endMinute;

      if (clippedEnd <= clippedStart) continue;

      rawWindows.add(
        _TimeWindow(
          startMinute: clippedStart,
          endMinute: clippedEnd,
        ),
      );
    }

    rawWindows.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    if (rawWindows.isEmpty) return [];

    final merged = <_TimeWindow>[];
    _TimeWindow current = rawWindows.first;

    for (int i = 1; i < rawWindows.length; i++) {
      final next = rawWindows[i];

      if (next.startMinute <= current.endMinute) {
        current = _TimeWindow(
          startMinute: current.startMinute,
          endMinute: next.endMinute > current.endMinute
              ? next.endMinute
              : current.endMinute,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    return merged;
  }

  static List<_TimeWindow> _buildFreeWindows({
    required int wakeMinute,
    required int sleepMinute,
    required List<_TimeWindow> blockedWindows,
  }) {
    if (blockedWindows.isEmpty) {
      return [
        _TimeWindow(startMinute: wakeMinute, endMinute: sleepMinute),
      ];
    }

    final free = <_TimeWindow>[];
    int cursor = wakeMinute;

    for (final blocked in blockedWindows) {
      if (blocked.startMinute > cursor) {
        free.add(
          _TimeWindow(
            startMinute: cursor,
            endMinute: blocked.startMinute,
          ),
        );
      }

      if (blocked.endMinute > cursor) {
        cursor = blocked.endMinute;
      }
    }

    if (cursor < sleepMinute) {
      free.add(
        _TimeWindow(
          startMinute: cursor,
          endMinute: sleepMinute,
        ),
      );
    }

    return free.where((window) => window.duration >= 25).toList();
  }

  static Map<String, int> _buildPyqSubjectBoost(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
  ) {
    final boosts = <String, int>{};

    for (final doc in pyqDocs) {
      final data = doc.data();
      final subject = (data['subjectName'] ?? '').toString().trim();
      if (subject.isEmpty) continue;

      final frequency = ((data['frequencyCount'] ?? 0) as num).toInt();
      final marks = ((data['marksWeight'] ?? 0) as num).toInt();

      boosts[subject] = (boosts[subject] ?? 0) + frequency * 4 + marks * 2;
    }

    return boosts;
  }

  static Map<String, List<String>> _buildPyqTopicsBySubject(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
  ) {
    final map = <String, List<String>>{};

    for (final doc in pyqDocs) {
      final data = doc.data();
      final subject = (data['subjectName'] ?? '').toString().trim();
      final topic = (data['topicName'] ?? '').toString().trim().toLowerCase();

      if (subject.isEmpty || topic.isEmpty) continue;

      map.putIfAbsent(subject, () => []);
      if (!map[subject]!.contains(topic)) {
        map[subject]!.add(topic);
      }
    }

    return map;
  }

  static List<_PlanCandidate> _buildTaskCandidates({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required Map<String, int> pyqBoostBySubject,
    required Map<String, List<String>> pyqTopicNamesBySubject,
    required int maxStudyBlockMinutes,
    required DateTime today,
  }) {
    final subjectDataByName = <String, Map<String, dynamic>>{};
    for (final doc in subjectDocs) {
      final data = doc.data();
      final subjectName = (data['subjectName'] ?? '').toString();
      if (subjectName.isNotEmpty) {
        subjectDataByName[subjectName] = data;
      }
    }

    final candidates = <_PlanCandidate>[];

    for (final doc in taskDocs) {
      final data = doc.data();
      final status =
          _normalizeStatus((data['completionStatus'] ?? data['status'])?.toString());

      if (status == 'completed') continue;

      final title = (data['title'] ?? 'Task').toString();
      final subjectName = (data['subjectName'] ?? 'General').toString();
      final priority = (data['priority'] ?? 'Medium').toString();
      final notes = (data['notes'] ?? '').toString();
      final estimatedMinutes =
          ((data['estimatedMinutes'] ?? 60) as num).toInt().clamp(25, 180);

      final subjectData = subjectDataByName[subjectName] ?? {};
      final difficulty = (subjectData['difficultyLevel'] ?? 'Medium').toString();
      final confidence = (subjectData['confidenceLevel'] ?? 'Medium').toString();

      int score = 40;
      score += _taskPriorityScore(priority);
      score += _confidenceScore(confidence);
      score += _difficultyScore(difficulty);
      score += _dueDateUrgencyScore(data['dueDate']);
      score += (pyqBoostBySubject[subjectName] ?? 0) ~/ 5;

      final taskTitleLower = title.toLowerCase();
      final topics = pyqTopicNamesBySubject[subjectName] ?? [];
      for (final topic in topics) {
        if (taskTitleLower.contains(topic)) {
          score += 20;
          break;
        }
      }

      candidates.add(
        _PlanCandidate(
          title: title,
          subjectName: subjectName,
          subtitle: 'Task • $priority priority',
          reason:
              'Ranked using due date, priority, confidence, difficulty, and PYQ relevance.',
          score: score,
          desiredMinutes: estimatedMinutes > maxStudyBlockMinutes
              ? maxStudyBlockMinutes
              : estimatedMinutes,
          isTask: true,
        ),
      );
    }

    return candidates;
  }

  static List<_PlanCandidate> _buildSubjectRevisionCandidates({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required Map<String, int> pyqBoostBySubject,
    required int maxStudyBlockMinutes,
    required DateTime today,
  }) {
    final candidates = <_PlanCandidate>[];

    for (final doc in subjectDocs) {
      final data = doc.data();
      final subjectName = (data['subjectName'] ?? 'Subject').toString();
      final difficulty = (data['difficultyLevel'] ?? 'Medium').toString();
      final confidence = (data['confidenceLevel'] ?? 'Medium').toString();
      final estimatedHours = ((data['estimatedHours'] ?? 5) as num).toInt();

      int score = 20;
      score += _confidenceScore(confidence) + 10;
      score += _difficultyScore(difficulty);
      score += _examUrgencyScore(data['examDate'], today);
      score += (pyqBoostBySubject[subjectName] ?? 0) ~/ 4;
      score += estimatedHours.clamp(0, 10);

      int duration = 45;
      if (difficulty.toLowerCase() == 'hard') {
        duration = maxStudyBlockMinutes >= 90 ? 90 : maxStudyBlockMinutes;
      } else if (difficulty.toLowerCase() == 'medium') {
        duration = maxStudyBlockMinutes >= 60 ? 60 : maxStudyBlockMinutes;
      } else {
        duration = maxStudyBlockMinutes >= 45 ? 45 : maxStudyBlockMinutes;
      }

      candidates.add(
        _PlanCandidate(
          title: 'Revise $subjectName',
          subjectName: subjectName,
          subtitle: 'Revision block • $difficulty difficulty',
          reason:
              'Ranked using exam closeness, confidence, difficulty, estimated load, and PYQ weight.',
          score: score,
          desiredMinutes: duration.clamp(25, maxStudyBlockMinutes),
          isTask: false,
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    // Add one extra pass for the strongest subjects if the day has spare time.
    final extraCandidates = <_PlanCandidate>[];
    for (int i = 0; i < candidates.length && i < 3; i++) {
      final item = candidates[i];
      extraCandidates.add(
        _PlanCandidate(
          title: 'Practice more: ${item.subjectName}',
          subjectName: item.subjectName,
          subtitle: 'Extra focused revision',
          reason: 'Added because this subject remains one of the highest-risk areas.',
          score: item.score - 5,
          desiredMinutes: item.desiredMinutes >= 60 ? 45 : item.desiredMinutes,
          isTask: false,
        ),
      );
    }

    return [...candidates, ...extraCandidates];
  }

  static int _taskPriorityScore(String priority) {
    final value = priority.toLowerCase().trim();
    if (value == 'high') return 30;
    if (value == 'medium') return 18;
    if (value == 'low') return 8;
    return 12;
  }

  static int _confidenceScore(String confidence) {
    final value = confidence.toLowerCase().trim();
    if (value == 'low') return 30;
    if (value == 'medium') return 15;
    if (value == 'high') return 5;
    return 10;
  }

  static int _difficultyScore(String difficulty) {
    final value = difficulty.toLowerCase().trim();
    if (value == 'hard') return 18;
    if (value == 'medium') return 10;
    if (value == 'easy') return 4;
    return 8;
  }

  static int _dueDateUrgencyScore(dynamic dueDateField) {
    if (dueDateField == null) return 0;

    DateTime? dueDate;
    if (dueDateField is Timestamp) {
      dueDate = dueDateField.toDate();
    } else {
      dueDate = DateTime.tryParse(dueDateField.toString());
    }

    if (dueDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;

    if (days <= 0) return 35;
    if (days <= 1) return 28;
    if (days <= 3) return 22;
    if (days <= 7) return 15;
    return 6;
  }

  static int _examUrgencyScore(dynamic examDateField, DateTime today) {
    if (examDateField == null) return 0;

    DateTime? examDate;
    if (examDateField is Timestamp) {
      examDate = examDateField.toDate();
    } else {
      examDate = DateTime.tryParse(examDateField.toString());
    }

    if (examDate == null) return 0;

    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedExam =
        DateTime(examDate.year, examDate.month, examDate.day);
    final days = normalizedExam.difference(normalizedToday).inDays;

    if (days <= 0) return 32;
    if (days <= 2) return 26;
    if (days <= 5) return 20;
    if (days <= 10) return 14;
    return 6;
  }

  static String _normalizeStatus(String? status) {
    if (status == null) return 'pending';
    return status.toLowerCase().trim() == 'completed'
        ? 'completed'
        : 'pending';
  }

  static int _parseTimeToMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

static String _formatMinutes(int totalMinutes) {
  final normalized = totalMinutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

  static String _formatDateStorage(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _buildSummary({
    required DateTime targetDate,
    required List<_TimeWindow> freeWindows,
    required int blockedCountToday,
    required int totalStudyMinutes,
    required int totalBreakMinutes,
    required int preferredStudyHours,
    required int scheduledCount,
  }) {
    final dateLabel =
        '${targetDate.day}/${targetDate.month}/${targetDate.year}';

    if (freeWindows.isEmpty) {
      return 'No free study windows were found for $dateLabel. Your day appears fully blocked.';
    }

    final plannedHours = (totalStudyMinutes / 60).toStringAsFixed(1);

    return 'For $dateLabel, the planner found ${freeWindows.length} free window(s) after removing $blockedCountToday blocked slot(s). '
        'It scheduled $scheduledCount study block(s), covering about $plannedHours hour(s) of study with $totalBreakMinutes break minute(s). '
        'Your daily target was $preferredStudyHours hour(s).';
  }
}