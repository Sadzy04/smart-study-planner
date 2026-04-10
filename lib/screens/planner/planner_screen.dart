import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/fastapi_service.dart';
import '../../services/firestore_service.dart';
import '../../services/planner_engine.dart';
import '../../services/profile_service.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final ProfileService _profileService = ProfileService();
  final FastapiService _fastapiService = FastapiService();

  Map<String, dynamic>? _profile;
  bool _isProfileLoading = true;

  bool _isGeneratingLocal = false;
  bool _isGeneratingAi = false;

  PlanResult? _localPlanResult;
  Map<String, dynamic>? _aiPlanResult;
  Map<String, dynamic>? _aiWorkloadResult;
  Map<String, dynamic>? _aiBreaksResult;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProfileLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _generateLocalPlan({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _isGeneratingLocal = true);

    await Future.delayed(const Duration(milliseconds: 250));

    final result = PlannerEngine.generate(
      subjectDocs: subjectDocs,
      taskDocs: taskDocs,
      pyqDocs: pyqDocs,
      blockedSlotDocs: blockedSlotDocs,
      profile: profile,
    );

    if (!mounted) return;

    setState(() {
      _localPlanResult = result;
      _isGeneratingLocal = false;
    });
  }

  Future<void> _generateAiPlan({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pyqDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockedSlotDocs,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _isGeneratingAi = true);

    try {
      final health = await _fastapiService.health();
      if ((health['status'] ?? '') != 'ok') {
        throw Exception('Backend health check failed.');
      }

      final aiPlan = await _fastapiService.generateStudyPlan(
        profile: profile,
        subjectDocs: subjectDocs,
        taskDocs: taskDocs,
        pyqDocs: pyqDocs,
        blockedSlotDocs: blockedSlotDocs,
      );

      final workload = await _fastapiService.analyzeWorkload(
        profile: profile,
        subjectDocs: subjectDocs,
        taskDocs: taskDocs,
        pyqDocs: pyqDocs,
        blockedSlotDocs: blockedSlotDocs,
      );

      final breaks = await _fastapiService.recommendBreaks(
        profile: profile,
        subjectDocs: subjectDocs,
        taskDocs: taskDocs,
        pyqDocs: pyqDocs,
        blockedSlotDocs: blockedSlotDocs,
      );

      if (!mounted) return;

      setState(() {
        _aiPlanResult = aiPlan;
        _aiWorkloadResult = workload;
        _aiBreaksResult = breaks;
        _isGeneratingAi = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isGeneratingAi = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('FastAPI optimization failed: $e')),
      );
    }
  }

  int _countPendingTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> taskDocs,
  ) {
    return taskDocs.where((doc) {
      final data = doc.data();
      final status =
          (data['completionStatus'] ?? data['status'] ?? 'pending')
              .toString()
              .toLowerCase()
              .trim();
      return status != 'completed';
    }).length;
  }

  int _countLowConfidence(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
  ) {
    return subjectDocs.where((doc) {
      final confidence =
          (doc.data()['confidenceLevel'] ?? '').toString().toLowerCase().trim();
      return confidence == 'low';
    }).length;
  }

  int _countUpcomingExams(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> subjectDocs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return subjectDocs.where((doc) {
      final raw = doc.data()['examDate'];
      if (raw is! Timestamp) return false;
      final examDate = raw.toDate();
      final normalized = DateTime(examDate.year, examDate.month, examDate.day);
      final days = normalized.difference(today).inDays;
      return days >= 0 && days <= 10;
    }).length;
  }

  String _formatTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return raw;

    final hour24 = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F3FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile ?? {};
    final wakeTime = (profile['wakeTime'] ?? '07:00').toString();
    final sleepTime = (profile['sleepTime'] ?? '23:00').toString();
    final preferredStudyHours =
        ((profile['preferredStudyHours'] ?? 4) as num).toInt();
    final maxStudyBlockMinutes =
        ((profile['maxStudyBlockMinutes'] ?? 90) as num).toInt();
    final preferredBreakMinutes =
        ((profile['preferredBreakMinutes'] ?? 15) as num).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3FB),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Planner',
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

          final subjectDocs =
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

              final taskDocs =
                  taskSnapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService().getPyqTopicsStream(),
                builder: (context, pyqSnapshot) {
                  if (pyqSnapshot.hasError) {
                    return _CenteredMessage(
                      message: 'Error loading PYQ topics: ${pyqSnapshot.error}',
                    );
                  }

                  if (pyqSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final pyqDocs =
                      pyqSnapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirestoreService().getBlockedSlotsStream(),
                    builder: (context, blockedSnapshot) {
                      if (blockedSnapshot.hasError) {
                        return _CenteredMessage(
                          message:
                              'Error loading blocked slots: ${blockedSnapshot.error}',
                        );
                      }

                      if (blockedSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final blockedSlotDocs =
                          blockedSnapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                      final pendingTasks = _countPendingTasks(taskDocs);
                      final lowConfidence = _countLowConfidence(subjectDocs);
                      final upcomingExams = _countUpcomingExams(subjectDocs);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Local + AI Planning',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'First generate the local feasible plan. Then use FastAPI to optimize with the same subjects, tasks, PYQ topics, study preferences, and blocked slots.',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.4,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _MiniStatCard(
                                      title: 'Wake → Sleep',
                                      value:
                                          '${_formatTime(wakeTime)} - ${_formatTime(sleepTime)}',
                                      color: const Color(0xFFE8DFF8),
                                    ),
                                    _MiniStatCard(
                                      title: 'Study Target',
                                      value: '$preferredStudyHours hr/day',
                                      color: const Color(0xFFDCE9F9),
                                    ),
                                    _MiniStatCard(
                                      title: 'Max Block',
                                      value: '$maxStudyBlockMinutes min',
                                      color: const Color(0xFFD9F3EC),
                                    ),
                                    _MiniStatCard(
                                      title: 'Break',
                                      value: '$preferredBreakMinutes min',
                                      color: const Color(0xFFF6DEE8),
                                    ),
                                    _MiniStatCard(
                                      title: 'Pending Tasks',
                                      value: '$pendingTasks',
                                      color: const Color(0xFFF4D7DD),
                                    ),
                                    _MiniStatCard(
                                      title: 'Upcoming Exams',
                                      value: '$upcomingExams',
                                      color: const Color(0xFFF4E8B9),
                                    ),
                                    _MiniStatCard(
                                      title: 'Low Confidence',
                                      value: '$lowConfidence',
                                      color: const Color(0xFFE8DFF8),
                                    ),
                                    _MiniStatCard(
                                      title: 'Blocked Slots',
                                      value: '${blockedSlotDocs.length}',
                                      color: const Color(0xFFDCE9F9),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 22),

                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
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
                                      const Text(
                                        'Generate plans',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Use the local planner for your Flutter-side feasible schedule, or use FastAPI to optimize the same data server-side.',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          SizedBox(
                                            width: 280,
                                            child: ElevatedButton.icon(
                                              onPressed: _isGeneratingLocal
                                                  ? null
                                                  : () => _generateLocalPlan(
                                                        subjectDocs: subjectDocs,
                                                        taskDocs: taskDocs,
                                                        pyqDocs: pyqDocs,
                                                        blockedSlotDocs:
                                                            blockedSlotDocs,
                                                      ),
                                              icon: _isGeneratingLocal
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Icon(Icons.tune),
                                              label: Text(
                                                _isGeneratingLocal
                                                    ? 'Generating Local...'
                                                    : 'Generate Local Plan',
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 280,
                                            child: ElevatedButton.icon(
                                              onPressed: _isGeneratingAi
                                                  ? null
                                                  : () => _generateAiPlan(
                                                        subjectDocs: subjectDocs,
                                                        taskDocs: taskDocs,
                                                        pyqDocs: pyqDocs,
                                                        blockedSlotDocs:
                                                            blockedSlotDocs,
                                                      ),
                                              icon: _isGeneratingAi
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.auto_awesome_outlined),
                                              label: Text(
                                                _isGeneratingAi
                                                    ? 'Optimizing...'
                                                    : 'Optimize With FastAPI',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 22),

                                _SectionTitle(
                                  title: 'Local feasible plan',
                                  subtitle:
                                      'Flutter rule-based scheduling that respects real free windows.',
                                ),
                                const SizedBox(height: 12),

                                if (_localPlanResult == null)
                                  const _EmptyCard(
                                    message:
                                        'No local plan generated yet.',
                                  )
                                else ...[
                                  _LocalPlanSummaryCard(result: _localPlanResult!),
                                  const SizedBox(height: 14),
                                  if (_localPlanResult!.items.isEmpty)
                                    _EmptyCard(
                                      message: _localPlanResult!.summary,
                                    )
                                  else
                                    Column(
                                      children: _localPlanResult!.items
                                          .map((item) => Padding(
                                                padding:
                                                    const EdgeInsets.only(bottom: 12),
                                                child: _LocalPlanItemCard(
                                                  item: item,
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                ],

                                const SizedBox(height: 28),

                                _SectionTitle(
                                  title: 'FastAPI optimized plan',
                                  subtitle:
                                      'Server-side optimization using the same subjects, tasks, blocked slots, and preferences.',
                                ),
                                const SizedBox(height: 12),

                                if (_aiPlanResult == null)
                                  const _EmptyCard(
                                    message:
                                        'No FastAPI plan generated yet.',
                                  )
                                else ...[
                                  _AiSummaryCard(
                                    plan: _aiPlanResult!,
                                    workload: _aiWorkloadResult,
                                    breaks: _aiBreaksResult,
                                  ),
                                  const SizedBox(height: 14),
                                  _AiPlanItemsCard(plan: _aiPlanResult!),
                                ],
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
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MiniStatCard({
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
          Text(title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}

class _LocalPlanSummaryCard extends StatelessWidget {
  final PlanResult result;

  const _LocalPlanSummaryCard({required this.result});

  String _formatHours(int minutes) {
    return '${(minutes / 60).toStringAsFixed(1)} h';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local Plan Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.summary,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(label: 'Study', value: _formatHours(result.totalStudyMinutes)),
              _Chip(label: 'Break', value: '${result.totalBreakMinutes} min'),
              _Chip(label: 'Free windows', value: '${result.freeWindowCount}'),
              _Chip(label: 'Blocked today', value: '${result.blockedCountToday}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalPlanItemCard extends StatelessWidget {
  final PlanItem item;

  const _LocalPlanItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final bgColor = item.isBreak
        ? const Color(0xFFF9F7EC)
        : item.isTask
            ? const Color(0xFFF3F7FF)
            : const Color(0xFFF5F3FF);

    final icon = item.isBreak
        ? Icons.free_breakfast_outlined
        : item.isTask
            ? Icons.checklist_rtl_outlined
            : Icons.menu_book_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F2937)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.reason,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isBreak)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Score ${item.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? workload;
  final Map<String, dynamic>? breaks;

  const _AiSummaryCard({
    required this.plan,
    required this.workload,
    required this.breaks,
  });

  @override
  Widget build(BuildContext context) {
    final summary = (plan['summary'] ?? '').toString();
    final studyMinutes = ((plan['total_study_minutes'] ?? 0) as num).toInt();
    final breakMinutes = ((plan['total_break_minutes'] ?? 0) as num).toInt();
    final freeWindows = ((plan['free_window_count'] ?? 0) as num).toInt();
    final blockedToday = ((plan['blocked_count_today'] ?? 0) as num).toInt();

    final workloadHeadline = workload == null
        ? ''
        : '${workload!['headline']} (${workload!['level']})';

    final recommendations = workload == null
        ? <dynamic>[]
        : (workload!['recommendations'] as List<dynamic>? ?? []);

    final breakRecommendations = breaks == null
        ? <dynamic>[]
        : (breaks!['recommendations'] as List<dynamic>? ?? []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Plan Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                label: 'Study',
                value: '${(studyMinutes / 60).toStringAsFixed(1)} h',
              ),
              _Chip(label: 'Break', value: '$breakMinutes min'),
              _Chip(label: 'Free windows', value: '$freeWindows'),
              _Chip(label: 'Blocked today', value: '$blockedToday'),
            ],
          ),
          if (workloadHeadline.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              workloadHeadline,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...recommendations.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${item.toString()}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
          ],
          if (breakRecommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Break Recommendations',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            ...breakRecommendations.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${item.toString()}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AiPlanItemsCard extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _AiPlanItemsCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final items = (plan['items'] as List<dynamic>? ?? []);

    if (items.isEmpty) {
      return const _EmptyCard(message: 'No AI plan items were returned.');
    }

    return Column(
      children: items.map((raw) {
        final item = raw as Map<String, dynamic>;
        final isBreak = (item['type'] ?? '') == 'break';
        final bgColor =
            isBreak ? const Color(0xFFF9F7EC) : const Color(0xFFF3F7FF);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['time_label'] ?? '').toString(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (item['title'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (item['subtitle'] ?? '').toString(),
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (item['reason'] ?? '').toString(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
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