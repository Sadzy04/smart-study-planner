import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';

class PyqInsightsScreen extends StatelessWidget {
  const PyqInsightsScreen({super.key});

  List<_AggregatedTopic> _aggregateTopics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, _AggregatedTopic> grouped = {};

    for (final doc in docs) {
      final data = doc.data();

      final subject = data['subjectName']?.toString() ?? 'General';
      final topic = data['topicName']?.toString() ?? 'Untitled Topic';
      final frequency = ((data['frequencyCount'] ?? 0) as num).toInt();
      final marks = ((data['marksWeight'] ?? 0) as num).toInt();

      final key = '${subject.toLowerCase()}|||${topic.toLowerCase()}';

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;
        grouped[key] = _AggregatedTopic(
          subjectName: existing.subjectName,
          topicName: existing.topicName,
          totalFrequency: existing.totalFrequency + frequency,
          totalMarks: existing.totalMarks + marks,
          entryCount: existing.entryCount + 1,
        );
      } else {
        grouped[key] = _AggregatedTopic(
          subjectName: subject,
          topicName: topic,
          totalFrequency: frequency,
          totalMarks: marks,
          entryCount: 1,
        );
      }
    }

    final topics = grouped.values.toList();
    topics.sort((a, b) {
      final frequencyCompare = b.totalFrequency.compareTo(a.totalFrequency);
      if (frequencyCompare != 0) return frequencyCompare;
      return b.totalMarks.compareTo(a.totalMarks);
    });

    return topics;
  }

  Map<String, List<_AggregatedTopic>> _groupBySubject(
    List<_AggregatedTopic> topics,
  ) {
    final map = <String, List<_AggregatedTopic>>{};
    for (final topic in topics) {
      map.putIfAbsent(topic.subjectName, () => []);
      map[topic.subjectName]!.add(topic);
    }

    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final frequencyCompare = b.totalFrequency.compareTo(a.totalFrequency);
        if (frequencyCompare != 0) return frequencyCompare;
        return b.totalMarks.compareTo(a.totalMarks);
      });
    }

    return map;
  }

  Future<void> _deletePyqEntry(BuildContext context, String pyqId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete PYQ Entry'),
            content: const Text(
              'Are you sure you want to delete this PYQ entry?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    try {
      await FirestoreService().deletePyqTopic(pyqId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PYQ entry deleted successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete PYQ entry: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService().getPyqTopicsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading PYQ topics: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                final recentEntries = [...docs];
                recentEntries.sort((a, b) {
                  final aTime = (a.data()['createdAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  final bTime = (b.data()['createdAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  return bTime.compareTo(aTime);
                });

                final aggregated = _aggregateTopics(docs);
                final bySubject = _groupBySubject(aggregated);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pop(context),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.arrow_back_ios_new_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'PYQ Insights',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Material(
                            color: AppColors.softPink,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  Navigator.pushNamed(context, '/add-pyq-topic'),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.add_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${docs.length} raw PYQ entr${docs.length == 1 ? 'y' : 'ies'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),

                      if (docs.isEmpty)
                        const _MessageCard(
                          message:
                              'No PYQ topics yet. Add your first PYQ topic to start building frequency-based insights.',
                        )
                      else ...[
                        const Text(
                          'Top Repeated Topics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...aggregated.take(5).map(
                          (topic) => _TopTopicCard(topic: topic),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Subject-wise Priority Topics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...bySubject.entries.map(
                          (entry) => _SubjectTopicCard(
                            subjectName: entry.key,
                            topics: entry.value.take(3).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Recent PYQ Entries',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recentEntries.take(6).map((doc) {
                          final data = doc.data();
                          return _RecentPyqEntryCard(
                            subjectName:
                                data['subjectName']?.toString() ?? 'General',
                            topicName:
                                data['topicName']?.toString() ?? 'Untitled Topic',
                            year: ((data['year'] ?? 0) as num).toInt(),
                            frequency:
                                ((data['frequencyCount'] ?? 0) as num).toInt(),
                            marks:
                                ((data['marksWeight'] ?? 0) as num).toInt(),
                            onDelete: () => _deletePyqEntry(context, doc.id),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AggregatedTopic {
  final String subjectName;
  final String topicName;
  final int totalFrequency;
  final int totalMarks;
  final int entryCount;

  const _AggregatedTopic({
    required this.subjectName,
    required this.topicName,
    required this.totalFrequency,
    required this.totalMarks,
    required this.entryCount,
  });
}

class _TopTopicCard extends StatelessWidget {
  final _AggregatedTopic topic;

  const _TopTopicCard({
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.topicName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            topic.subjectName,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.repeat_rounded,
                label: '${topic.totalFrequency} hits',
              ),
              _InfoChip(
                icon: Icons.grade_outlined,
                label: '${topic.totalMarks} marks',
              ),
              _InfoChip(
                icon: Icons.library_books_outlined,
                label: '${topic.entryCount} entries',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectTopicCard extends StatelessWidget {
  final String subjectName;
  final List<_AggregatedTopic> topics;

  const _SubjectTopicCard({
    required this.subjectName,
    required this.topics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subjectName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...topics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      topic.topicName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _InfoChip(
                    icon: Icons.repeat_rounded,
                    label: '${topic.totalFrequency}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPyqEntryCard extends StatelessWidget {
  final String subjectName;
  final String topicName;
  final int year;
  final int frequency;
  final int marks;
  final VoidCallback onDelete;

  const _RecentPyqEntryCard({
    required this.subjectName,
    required this.topicName,
    required this.year,
    required this.frequency,
    required this.marks,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topicName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Material(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subjectName,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: '$year',
              ),
              _InfoChip(
                icon: Icons.repeat_rounded,
                label: '$frequency hits',
              ),
              _InfoChip(
                icon: Icons.grade_outlined,
                label: '$marks marks',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          height: 1.45,
        ),
      ),
    );
  }
}