import 'package:cloud_firestore/cloud_firestore.dart';

class WorkloadInsight {
  final int score;
  final String level;
  final String headline;
  final String subtitle;
  final int pendingTaskCount;
  final int upcomingExamCount;
  final int lowConfidenceCount;
  final int todayStudyMinutes;
  final int recentStudyMinutes;
  final List<String> recommendations;

  const WorkloadInsight({
    required this.score,
    required this.level,
    required this.headline,
    required this.subtitle,
    required this.pendingTaskCount,
    required this.upcomingExamCount,
    required this.lowConfidenceCount,
    required this.todayStudyMinutes,
    required this.recentStudyMinutes,
    required this.recommendations,
  });
}

class WorkloadEngine {
  static WorkloadInsight build({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  }) {
    final pendingTaskCount = taskDocs.where((doc) {
      final data = doc.data();
      final rawStatus =
          (data['completionStatus'] ?? data['status'] ?? 'pending')
              .toString()
              .toLowerCase()
              .trim();
      return rawStatus != 'completed' && rawStatus != 'done';
    }).length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final threeDaysAgo = today.subtract(const Duration(days: 2));

    int upcomingExamCount = 0;
    int lowConfidenceCount = 0;
    int estimatedHoursLeft = 0;

    for (final doc in subjectDocs) {
      final data = doc.data();

      final confidence =
          (data['confidenceLevel'] ?? 'Medium').toString().toLowerCase().trim();
      if (confidence == 'low') {
        lowConfidenceCount += 1;
      }

      final examDate = (data['examDate'] as Timestamp?)?.toDate();
      if (examDate != null) {
        final exam =
            DateTime(examDate.year, examDate.month, examDate.day);
        final days = exam.difference(today).inDays;
        if (days <= 7) {
          upcomingExamCount += 1;
        }
      }

      estimatedHoursLeft += ((data['estimatedHours'] ?? 0) as num).toInt();
    }

    int todayStudyMinutes = 0;
    int recentStudyMinutes = 0;
    int lowEnergySessions = 0;
    int longSessionCount = 0;

    for (final doc in sessionDocs) {
      final data = doc.data();

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final duration = ((data['durationMinutes'] ?? 0) as num).toInt();
      final energy = ((data['energyRating'] ?? 3) as num).toInt();

      if (createdAt != null) {
        final sessionDay =
            DateTime(createdAt.year, createdAt.month, createdAt.day);

        if (sessionDay == today) {
          todayStudyMinutes += duration;
        }

        if (!sessionDay.isBefore(threeDaysAgo)) {
          recentStudyMinutes += duration;

          if (energy <= 2) {
            lowEnergySessions += 1;
          }

          if (duration >= 120) {
            longSessionCount += 1;
          }
        }
      }
    }

    int score = 0;

    score += (pendingTaskCount * 6).clamp(0, 30);
    score += (upcomingExamCount * 10).clamp(0, 30);
    score += (lowConfidenceCount * 7).clamp(0, 20);
    score += (estimatedHoursLeft ~/ 4).clamp(0, 15);

    if (recentStudyMinutes >= 720) {
      score += 22;
    } else if (recentStudyMinutes >= 480) {
      score += 16;
    } else if (recentStudyMinutes >= 300) {
      score += 10;
    }

    score += (lowEnergySessions * 5).clamp(0, 15);
    score += (longSessionCount * 4).clamp(0, 10);

    score = score.clamp(0, 100);

    String level;
    String headline;
    String subtitle;

    if (score >= 75) {
      level = 'Very High';
      headline = 'Workload is very high';
      subtitle =
          'Your upcoming work looks intense. Keep the plan realistic and protect recovery time.';
    } else if (score >= 55) {
      level = 'High';
      headline = 'Workload is high';
      subtitle =
          'You have a meaningful backlog or exam pressure building up this week.';
    } else if (score >= 30) {
      level = 'Moderate';
      headline = 'Workload is moderate';
      subtitle =
          'Your current schedule is manageable, but a few weak areas need attention.';
    } else {
      level = 'Low';
      headline = 'Workload is under control';
      subtitle =
          'Your current pressure looks manageable. Keep consistency strong.';
    }

    final recommendations = <String>[
      if (pendingTaskCount >= 5)
        'You have a high pending task backlog. Try clearing one urgent task first.',
      if (upcomingExamCount > 0)
        '$upcomingExamCount subject(s) have exams within the next 7 days.',
      if (lowConfidenceCount > 0)
        '$lowConfidenceCount low-confidence subject(s) need earlier revision.',
      if (lowEnergySessions >= 2)
        'Recent low-energy sessions suggest you should reduce overload and insert recovery breaks.',
      if (longSessionCount > 0)
        'At least one recent session was very long. Take a break after about 90 minutes.',
      if (todayStudyMinutes < 60)
        'Today’s study time is still low. Add one focused block to stay consistent.',
    ];

    if (recommendations.isEmpty) {
      recommendations.add(
        'Your workload looks stable. Continue with steady study blocks and short breaks.',
      );
    }

    return WorkloadInsight(
      score: score,
      level: level,
      headline: headline,
      subtitle: subtitle,
      pendingTaskCount: pendingTaskCount,
      upcomingExamCount: upcomingExamCount,
      lowConfidenceCount: lowConfidenceCount,
      todayStudyMinutes: todayStudyMinutes,
      recentStudyMinutes: recentStudyMinutes,
      recommendations: recommendations,
    );
  }
}