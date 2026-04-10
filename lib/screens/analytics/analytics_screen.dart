import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  int _pendingTaskCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final data = doc.data();
      final status =
          (data['completionStatus'] ?? data['status'] ?? 'pending')
              .toString()
              .toLowerCase()
              .trim();
      return status != 'completed';
    }).length;
  }

  int _completedTaskCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final data = doc.data();
      final status =
          (data['completionStatus'] ?? data['status'] ?? 'pending')
              .toString()
              .toLowerCase()
              .trim();
      return status == 'completed';
    }).length;
  }

  List<_SubjectLoadPoint> _subjectLoadPoints(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
  ) {
    final points = subjectDocs.map((doc) {
      final data = doc.data();
      return _SubjectLoadPoint(
        subjectName: (data['subjectName'] ?? 'Subject').toString(),
        estimatedHours: ((data['estimatedHours'] ?? 0) as num).toDouble(),
      );
    }).toList();

    points.sort((a, b) => b.estimatedHours.compareTo(a.estimatedHours));

    return points.take(5).toList();
  }

  List<_DayStudyPoint> _weeklyStudyPoints(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<_DayStudyPoint> points = [];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      int totalMinutes = 0;

      for (final doc in sessionDocs) {
        final data = doc.data();
        final createdAt = data['createdAt'];

        if (createdAt is! Timestamp) continue;

        final dt = createdAt.toDate();
        final normalized = DateTime(dt.year, dt.month, dt.day);

        if (normalized == date) {
          totalMinutes += ((data['durationMinutes'] ?? 0) as num).toInt();
        }
      }

      points.add(
        _DayStudyPoint(
          label: _shortWeekday(date.weekday),
          minutes: totalMinutes.toDouble(),
        ),
      );
    }

    return points;
  }

  List<_TrendPoint> _workloadTrendPoints({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final points = <_TrendPoint>[];

    for (int i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      int score = 0;

      for (final taskDoc in taskDocs) {
        final data = taskDoc.data();
        final status =
            (data['completionStatus'] ?? data['status'] ?? 'pending')
                .toString()
                .toLowerCase()
                .trim();

        if (status == 'completed') continue;

        final dueDateRaw = data['dueDate'];
        DateTime? dueDate;

        if (dueDateRaw is Timestamp) {
          dueDate = dueDateRaw.toDate();
        } else {
          dueDate = DateTime.tryParse(dueDateRaw?.toString() ?? '');
        }

        if (dueDate == null) {
          score += 3;
          continue;
        }

        final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final days = due.difference(day).inDays;

        if (days <= 0) {
          score += 14;
        } else if (days <= 2) {
          score += 10;
        } else if (days <= 5) {
          score += 6;
        } else {
          score += 3;
        }
      }

      for (final subjectDoc in subjectDocs) {
        final data = subjectDoc.data();

        final confidence =
            (data['confidenceLevel'] ?? '').toString().toLowerCase().trim();
        if (confidence == 'low') {
          score += 6;
        }

        final examRaw = data['examDate'];
        if (examRaw is! Timestamp) continue;

        final examDate = examRaw.toDate();
        final exam = DateTime(examDate.year, examDate.month, examDate.day);
        final days = exam.difference(day).inDays;

        if (days <= 0) {
          score += 14;
        } else if (days <= 2) {
          score += 11;
        } else if (days <= 5) {
          score += 8;
        } else if (days <= 10) {
          score += 4;
        }
      }

      if (score > 100) score = 100;

      points.add(
        _TrendPoint(
          label: _shortWeekday(day.weekday),
          value: score.toDouble(),
        ),
      );
    }

    return points;
  }

  static String _shortWeekday(int weekday) {
    const labels = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return labels[weekday] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3FB),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().getSubjectsStream(),
        builder: (context, subjectSnapshot) {
          if (subjectSnapshot.hasError) {
            return _CenteredMessage(
              message: 'Error loading subjects: ${subjectSnapshot.error}',
            );
          }

          if (subjectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subjectDocs = subjectSnapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().getTasksStream(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.hasError) {
                return _CenteredMessage(
                  message: 'Error loading tasks: ${taskSnapshot.error}',
                );
              }

              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final taskDocs = taskSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService().getStudySessionsStream(),
                builder: (context, sessionSnapshot) {
                  if (sessionSnapshot.hasError) {
                    return _CenteredMessage(
                      message:
                          'Error loading study sessions: ${sessionSnapshot.error}',
                    );
                  }

                  if (sessionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sessionDocs = sessionSnapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  final pendingCount = _pendingTaskCount(taskDocs);
                  final completedCount = _completedTaskCount(taskDocs);
                  final subjectLoad = _subjectLoadPoints(subjectDocs);
                  final weeklyStudy = _weeklyStudyPoints(sessionDocs);
                  final workloadTrend = _workloadTrendPoints(
                    subjectDocs: subjectDocs,
                    taskDocs: taskDocs,
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project Analytics',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track task completion, subject load, weekly study effort, and workload pressure trends.',
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _TopStatCard(
                                  title: 'Subjects',
                                  value: '${subjectDocs.length}',
                                  color: const Color(0xFFE8DFF8),
                                ),
                                _TopStatCard(
                                  title: 'Pending Tasks',
                                  value: '$pendingCount',
                                  color: const Color(0xFFF4D7DD),
                                ),
                                _TopStatCard(
                                  title: 'Completed Tasks',
                                  value: '$completedCount',
                                  color: const Color(0xFFD9F3EC),
                                ),
                                _TopStatCard(
                                  title: 'Study Sessions',
                                  value: '${sessionDocs.length}',
                                  color: const Color(0xFFDCE9F9),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 900;

                                if (isWide) {
                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _AnalyticsCard(
                                              title: 'Pending vs Completed Tasks',
                                              child: SizedBox(
                                                height: 280,
                                                child: _TaskSplitChart(
                                                  pendingCount: pendingCount,
                                                  completedCount: completedCount,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _AnalyticsCard(
                                              title: 'Subject Load',
                                              child: SizedBox(
                                                height: 280,
                                                child: _SubjectLoadChart(
                                                  points: subjectLoad,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _AnalyticsCard(
                                              title: 'Weekly Study Trend',
                                              child: SizedBox(
                                                height: 280,
                                                child: _WeeklyStudyChart(
                                                  points: weeklyStudy,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _AnalyticsCard(
                                              title: 'Workload Score Trend',
                                              child: SizedBox(
                                                height: 280,
                                                child: _WorkloadTrendChart(
                                                  points: workloadTrend,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    _AnalyticsCard(
                                      title: 'Pending vs Completed Tasks',
                                      child: SizedBox(
                                        height: 280,
                                        child: _TaskSplitChart(
                                          pendingCount: pendingCount,
                                          completedCount: completedCount,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _AnalyticsCard(
                                      title: 'Subject Load',
                                      child: SizedBox(
                                        height: 280,
                                        child: _SubjectLoadChart(
                                          points: subjectLoad,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _AnalyticsCard(
                                      title: 'Weekly Study Trend',
                                      child: SizedBox(
                                        height: 280,
                                        child: _WeeklyStudyChart(
                                          points: weeklyStudy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _AnalyticsCard(
                                      title: 'Workload Score Trend',
                                      child: SizedBox(
                                        height: 280,
                                        child: _WorkloadTrendChart(
                                          points: workloadTrend,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TopStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _TopStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AnalyticsCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _TaskSplitChart extends StatelessWidget {
  final int pendingCount;
  final int completedCount;

  const _TaskSplitChart({
    required this.pendingCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = pendingCount + completedCount;

    if (total == 0) {
      return const _ChartEmptyState(message: 'No tasks available yet.');
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 50,
              sectionsSpace: 4,
              sections: [
                PieChartSectionData(
                  value: pendingCount.toDouble(),
                  title: '$pendingCount',
                  radius: 80,
                  color: const Color(0xFFF4A6B8),
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: completedCount.toDouble(),
                  title: '$completedCount',
                  radius: 80,
                  color: const Color(0xFF8FD5C0),
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _LegendDot(label: 'Pending', color: Color(0xFFF4A6B8)),
            _LegendDot(label: 'Completed', color: Color(0xFF8FD5C0)),
          ],
        ),
      ],
    );
  }
}

class _SubjectLoadChart extends StatelessWidget {
  final List<_SubjectLoadPoint> points;

  const _SubjectLoadChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _ChartEmptyState(message: 'No subjects available yet.');
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (points
                    .map((e) => e.estimatedHours)
                    .fold<double>(0, (a, b) => a > b ? a : b) +
                2)
            .clamp(4, 100),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final label = points[index].subjectName;
                final shortLabel =
                    label.length > 8 ? '${label.substring(0, 8)}…' : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    shortLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: points[index].estimatedHours,
                width: 20,
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF8E7CF6),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _WeeklyStudyChart extends StatelessWidget {
  final List<_DayStudyPoint> points;

  const _WeeklyStudyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.every((e) => e.minutes == 0)) {
      return const _ChartEmptyState(
        message: 'No study session data in the last 7 days.',
      );
    }

    final double maxY = ((points
                .map((e) => e.minutes)
                .fold<double>(0, (a, b) => a > b ? a : b) +
            30)
        .clamp(60, 500))
    .toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[index].label,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: const Color(0xFF6EA8FE),
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF6EA8FE).withOpacity(0.18),
            ),
            spots: List.generate(
              points.length,
              (index) => FlSpot(index.toDouble(), points[index].minutes),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkloadTrendChart extends StatelessWidget {
  final List<_TrendPoint> points;

  const _WorkloadTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _ChartEmptyState(message: 'No workload data available.');
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[index].label,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: const Color(0xFF8E7CF6),
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF8E7CF6).withOpacity(0.16),
            ),
            spots: List.generate(
              points.length,
              (index) => FlSpot(index.toDouble(), points[index].value),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final String message;

  const _ChartEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF1F2937)),
        ),
      ),
    );
  }
}

class _SubjectLoadPoint {
  final String subjectName;
  final double estimatedHours;

  _SubjectLoadPoint({
    required this.subjectName,
    required this.estimatedHours,
  });
}

class _DayStudyPoint {
  final String label;
  final double minutes;

  _DayStudyPoint({
    required this.label,
    required this.minutes,
  });
}

class _TrendPoint {
  final String label;
  final double value;

  _TrendPoint({
    required this.label,
    required this.value,
  });
}