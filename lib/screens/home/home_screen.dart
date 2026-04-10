import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/workload_engine.dart';
import '../../widgets/soft_stat_card.dart';
import '../../widgets/ui_empty_state.dart';
import '../../widgets/ui_page_shell.dart';
import '../../widgets/ui_section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  int _daysUntil(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _normalizeStatus(String? raw) {
    final value = (raw ?? 'pending').toLowerCase().trim();
    if (value == 'completed' || value == 'done') return 'completed';
    return 'pending';
  }

  Color _subjectCardColor(int index) {
    const colors = [
      AppColors.mint,
      AppColors.softPink,
      AppColors.softBlue,
      AppColors.lavender,
      AppColors.softYellow,
    ];
    return colors[index % colors.length];
  }

  Future<void> _toggleTaskStatus(
    BuildContext context, {
    required String taskId,
    required String currentStatus,
  }) async {
    final nextStatus =
        currentStatus == 'completed' ? 'pending' : 'completed';

    try {
      await FirestoreService().updateTaskStatus(
        taskId: taskId,
        newStatus: nextStatus,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'completed'
                ? 'Task marked as completed.'
                : 'Task moved back to pending.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    }
  }

  Future<void> _deleteTask(BuildContext context, String taskId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text('Are you sure you want to delete this task?'),
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
      await FirestoreService().deleteTask(taskId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete task: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs =
                subjectSnapshot.data?.docs ??
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

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs =
                    taskSnapshot.data?.docs ??
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

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        sessionDocs = sessionSnapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    final pendingTaskCount = taskDocs.where((doc) {
                      final status = _normalizeStatus(
                        (doc.data()['completionStatus'] ?? doc.data()['status'])
                            ?.toString(),
                      );
                      return status != 'completed';
                    }).length;

                    final completedCount = taskDocs.length - pendingTaskCount;

                    final workload = WorkloadEngine.build(
                      subjectDocs: subjectDocs,
                      taskDocs: taskDocs,
                      sessionDocs: sessionDocs,
                    );

                    final recentSessions = [...sessionDocs];
                    recentSessions.sort((a, b) {
                      final aTime = (a.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      final bTime = (b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      return bTime.compareTo(aTime);
                    });

                    return UiPageShell(
                      maxWidth: 980,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _TopBar(),
                          const SizedBox(height: 24),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 185,
                                child: SoftStatCard(
                                  title: 'Subjects',
                                  value: '${subjectDocs.length}',
                                  subtitle: 'Tracked now',
                                  icon: Icons.menu_book_rounded,
                                  color: AppColors.lavender,
                                ),
                              ),
                              SizedBox(
                                width: 185,
                                child: SoftStatCard(
                                  title: 'Pending Tasks',
                                  value: '$pendingTaskCount',
                                  subtitle: 'Need attention',
                                  icon: Icons.pending_actions_rounded,
                                  color: AppColors.softYellow,
                                ),
                              ),
                              SizedBox(
                                width: 185,
                                child: SoftStatCard(
                                  title: 'Completed',
                                  value: '$completedCount',
                                  subtitle: 'Finished tasks',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppColors.mint,
                                ),
                              ),
                              SizedBox(
                                width: 185,
                                child: SoftStatCard(
                                  title: 'Study Today',
                                  value: '${workload.todayStudyMinutes}m',
                                  subtitle: 'Logged today',
                                  icon: Icons.timer_outlined,
                                  color: AppColors.softBlue,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _WorkloadCard(workload: workload),

                          const SizedBox(height: 28),

                          const _SectionHeading(title: 'Quick Actions'),
                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _QuickActionButton(
                                label: 'Add Subject',
                                icon: Icons.add_box_outlined,
                                color: AppColors.lavender,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/add-subject'),
                              ),
                              _QuickActionButton(
                                label: 'Add Task',
                                icon: Icons.playlist_add_circle_outlined,
                                color: AppColors.softBlue,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/add-task'),
                              ),
                              _QuickActionButton(
                                label: 'Log Session',
                                icon: Icons.timer_outlined,
                                color: AppColors.softYellow,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/log-session'),
                              ),
                              _QuickActionButton(
                                label: 'Planner',
                                icon: Icons.calendar_month_outlined,
                                color: AppColors.mint,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/planner'),
                              ),
                              _QuickActionButton(
                                label: 'PyQ Insights',
                                icon: Icons.light_mode_outlined,
                                color: AppColors.softPink,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/pyq-insights'),
                              ),
                              _QuickActionButton(
                                label: 'Preferences',
                                icon: Icons.settings_outlined,
                                color: const Color.fromARGB(255, 191, 158, 239),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/profile-settings',
                                ),
                              ),
                              _QuickActionButton(
                                label: 'Availability',
                                icon: Icons.event_busy_outlined,
                                color: const Color.fromARGB(255, 195, 240, 232),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/availability'),
                              ),
                              _QuickActionButton(
                                label: 'Analytics',
                                icon: Icons.bar_chart_rounded,
                                color: const Color(0xFFDCE9F9),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/analytics'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          _SectionHeading(
                            title: 'Latest Tasks',
                            trailing: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/all-tasks'),
                              child: const Text('View All'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (taskDocs.isEmpty)
                            const UiEmptyState(
                              icon: Icons.task_alt_outlined,
                              title: 'No tasks yet',
                              message:
                                  'Add a few tasks to start tracking deadlines and generate smarter study plans.',
                            )
                          else
                            ...taskDocs.take(3).map((doc) {
                              final data = doc.data();
                              final dueDate =
                                  (data['dueDate'] as Timestamp?)?.toDate();
                              final status = _normalizeStatus(
                                (data['completionStatus'] ?? data['status'])
                                    ?.toString(),
                              );

                              return _TaskCard(
                                title:
                                    data['title']?.toString() ?? 'Untitled Task',
                                subject: data['subjectName']?.toString() ??
                                    'No Subject',
                                dueText: dueDate != null
                                    ? _formatDate(dueDate)
                                    : 'No due date',
                                priority:
                                    data['priority']?.toString() ?? 'Medium',
                                status: status,
                                onToggle: () => _toggleTaskStatus(
                                  context,
                                  taskId: doc.id,
                                  currentStatus: status,
                                ),
                                onDelete: () => _deleteTask(context, doc.id),
                              );
                            }),

                          const SizedBox(height: 28),

                          const _SectionHeading(title: 'Recent Sessions'),
                          const SizedBox(height: 12),

                          if (recentSessions.isEmpty)
                            const _MessageCard(
                              message:
                                  'No study sessions yet. Log one to start tracking workload.',
                            )
                          else
                            ...recentSessions.take(3).map((doc) {
                              final data = doc.data();
                              final createdAt =
                                  (data['createdAt'] as Timestamp?)?.toDate();
                              final duration =
                                  ((data['durationMinutes'] ?? 0) as num)
                                      .toInt();
                              final energy =
                                  ((data['energyRating'] ?? 3) as num).toInt();
                              final focus =
                                  ((data['focusRating'] ?? 3) as num).toInt();

                              return _SessionCard(
                                subjectName:
                                    data['subjectName']?.toString() ?? 'General',
                                durationText: '$duration min',
                                energyText: 'Energy $energy/5',
                                focusText: 'Focus $focus/5',
                                dateText: createdAt != null
                                    ? _formatDate(createdAt)
                                    : 'Unknown date',
                              );
                            }),

                          const SizedBox(height: 28),

                          _SectionHeading(
                            title: 'Your Subjects',
                            trailing: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/all-subjects'),
                              child: const Text('View All'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (subjectDocs.isEmpty)
                            const UiEmptyState(
                              icon: Icons.menu_book_outlined,
                              title: 'No subjects yet',
                              message:
                                  'Add subjects with exam dates, difficulty, and confidence so the planner has real data to work with.',
                            )
                          else
                            ...List.generate(subjectDocs.length, (index) {
                              final data = subjectDocs[index].data();
                              final examDate =
                                  (data['examDate'] as Timestamp?)?.toDate();

                              final daysLeft =
                                  examDate != null ? _daysUntil(examDate) : null;

                              return _LiveSubjectCard(
                                subjectName: data['subjectName']?.toString() ??
                                    'Untitled Subject',
                                examText: examDate != null
                                    ? 'Exam: ${_formatDate(examDate)}'
                                    : 'Exam date not set',
                                estimatedHours:
                                    (data['estimatedHours'] ?? 0).toString(),
                                difficulty:
                                    data['difficultyLevel']?.toString() ??
                                        'Medium',
                                confidence:
                                    data['confidenceLevel']?.toString() ??
                                        'Medium',
                                daysLeft: daysLeft,
                                color: _subjectCardColor(index),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log Out'),
            content: const Text('Do you want to log out now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      await AuthService().signOut();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello there',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Smart Study Planner',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleLogout(context),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.logout_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkloadCard extends StatelessWidget {
  final WorkloadInsight workload;

  const _WorkloadCard({
    required this.workload,
  });

  Color _backgroundColor() {
    switch (workload.level) {
      case 'Very High':
        return AppColors.softPink;
      case 'High':
        return AppColors.softYellow;
      case 'Moderate':
        return AppColors.softBlue;
      default:
        return AppColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workload Risk • ${workload.score}/100',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            workload.headline,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            workload.subtitle,
            style: const TextStyle(
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...workload.recommendations.take(3).map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
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

class _SectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeading({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return UiSectionHeader(
      title: title,
      trailing: trailing,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1F2937)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSubjectCard extends StatelessWidget {
  final String subjectName;
  final String examText;
  final String estimatedHours;
  final String difficulty;
  final String confidence;
  final int? daysLeft;
  final Color color;

  const _LiveSubjectCard({
    required this.subjectName,
    required this.examText,
    required this.estimatedHours,
    required this.difficulty,
    required this.confidence,
    required this.daysLeft,
    required this.color,
  });

  String _daysLeftText() {
    if (daysLeft == null) return 'No exam countdown';
    if (daysLeft! < 0) return 'Exam passed';
    if (daysLeft == 0) return 'Exam today';
    return '$daysLeft days left';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 8),
          Text(
            examText,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _daysLeftText(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.schedule_outlined,
                  label: '$estimatedHours hrs',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChip(
                  icon: Icons.bolt_outlined,
                  label: difficulty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoChip(
            icon: Icons.psychology_alt_outlined,
            label: 'Confidence: $confidence',
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final String subject;
  final String dueText;
  final String priority;
  final String status;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.title,
    required this.subject,
    required this.dueText,
    required this.priority,
    required this.status,
    required this.onToggle,
    required this.onDelete,
  });

  Color _statusColor() {
    return status == 'completed' ? AppColors.mint : AppColors.softYellow;
  }

  String _statusLabel() {
    return status == 'completed' ? 'Completed' : 'Pending';
  }

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subject,
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
                label: dueText,
              ),
              _InfoChip(
                icon: Icons.flag_outlined,
                label: priority,
              ),
              _InfoChip(
                icon: Icons.pending_actions_outlined,
                label: _statusLabel(),
                bgColor: _statusColor(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    status == 'completed'
                        ? Icons.refresh_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(
                    status == 'completed'
                        ? 'Mark Pending'
                        : 'Mark Done',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String subjectName;
  final String durationText;
  final String energyText;
  final String focusText;
  final String dateText;

  const _SessionCard({
    required this.subjectName,
    required this.durationText,
    required this.energyText,
    required this.focusText,
    required this.dateText,
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
          Text(
            subjectName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateText,
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
                icon: Icons.schedule_outlined,
                label: durationText,
              ),
              _InfoChip(
                icon: Icons.battery_charging_full_rounded,
                label: energyText,
              ),
              _InfoChip(
                icon: Icons.center_focus_strong_rounded,
                label: focusText,
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
  final Color? bgColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withOpacity(0.65),
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
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}