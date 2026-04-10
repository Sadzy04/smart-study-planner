import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';

class AllTasksScreen extends StatelessWidget {
  const AllTasksScreen({super.key});

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _normalizeStatus(String? status) {
    if (status == null) return 'pending';
    final value = status.toLowerCase().trim();
    if (value == 'completed') return 'completed';
    return 'pending';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService().getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading tasks: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                final pendingTasks = docs.where((doc) {
                  final data = doc.data();
                  return _normalizeStatus(
                        data['completionStatus']?.toString(),
                      ) !=
                      'completed';
                }).toList();

                final completedTasks = docs.where((doc) {
                  final data = doc.data();
                  return _normalizeStatus(
                        data['completionStatus']?.toString(),
                      ) ==
                      'completed';
                }).toList();

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
                              'All Tasks',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _SectionTitle(
                        title: 'Pending Tasks',
                        count: pendingTasks.length,
                      ),
                      const SizedBox(height: 12),

                      if (pendingTasks.isEmpty)
                        const _EmptyStateCard(
                          message: 'No pending tasks yet.',
                        )
                      else
                        ...pendingTasks.map((doc) {
                          final data = doc.data();
                          final dueDate =
                              (data['dueDate'] as Timestamp?)?.toDate();
                          final status = _normalizeStatus(
                            data['completionStatus']?.toString(),
                          );

                          return _TaskTile(
                            title: data['title']?.toString() ?? 'Untitled Task',
                            subject:
                                data['subjectName']?.toString() ?? 'No Subject',
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

                      _SectionTitle(
                        title: 'Completed Tasks',
                        count: completedTasks.length,
                      ),
                      const SizedBox(height: 12),

                      if (completedTasks.isEmpty)
                        const _EmptyStateCard(
                          message: 'No completed tasks yet.',
                        )
                      else
                        ...completedTasks.map((doc) {
                          final data = doc.data();
                          final dueDate =
                              (data['dueDate'] as Timestamp?)?.toDate();
                          final status = _normalizeStatus(
                            data['completionStatus']?.toString(),
                          );

                          return _TaskTile(
                            title: data['title']?.toString() ?? 'Untitled Task',
                            subject:
                                data['subjectName']?.toString() ?? 'No Subject',
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String title;
  final String subject;
  final String dueText;
  final String priority;
  final String status;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
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
              fontSize: 14,
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
        color: bgColor ?? Colors.white.withOpacity(0.7),
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

class _EmptyStateCard extends StatelessWidget {
  final String message;

  const _EmptyStateCard({
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