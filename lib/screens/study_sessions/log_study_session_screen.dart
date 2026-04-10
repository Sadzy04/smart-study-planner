import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/soft_text_field.dart';

class LogStudySessionScreen extends StatefulWidget {
  const LogStudySessionScreen({super.key});

  @override
  State<LogStudySessionScreen> createState() => _LogStudySessionScreenState();
}

class _LogStudySessionScreenState extends State<LogStudySessionScreen> {
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedSubject;
  int _energyRating = 3;
  int _focusRating = 3;
  bool _isSaving = false;

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject.')),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text.trim());
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid duration in minutes.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirestoreService().addStudySession(
        subjectName: _selectedSubject!,
        durationMinutes: duration,
        energyRating: _energyRating,
        focusRating: _focusRating,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study session logged successfully.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save session: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _ratingSelector({
    required String label,
    required int currentValue,
    required ValueChanged<int> onChanged,
    required Color activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = value == currentValue;

            return GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
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
              stream: FirestoreService().getSubjectsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading subjects: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final subjects = snapshot.data?.docs ?? [];

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
                              'Log Study Session',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Manual session logging is the best fit for this stage of your project.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (subjects.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'No subjects found yet. Add a subject before logging study sessions.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        )
                      else ...[
                        const Text(
                          'Subject',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubject,
                              isExpanded: true,
                              hint: const Text('Select subject'),
                              items: subjects.map((doc) {
                                final subject =
                                    doc.data()['subjectName']?.toString() ??
                                        'Untitled Subject';
                                return DropdownMenuItem<String>(
                                  value: subject,
                                  child: Text(subject),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubject = value;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _durationController,
                          label: 'Duration (minutes)',
                          hint: 'Example: 90',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 18),
                        _ratingSelector(
                          label: 'Energy Rating',
                          currentValue: _energyRating,
                          onChanged: (value) {
                            setState(() => _energyRating = value);
                          },
                          activeColor: AppColors.softYellow,
                        ),
                        const SizedBox(height: 18),
                        _ratingSelector(
                          label: 'Focus Rating',
                          currentValue: _focusRating,
                          onChanged: (value) {
                            setState(() => _focusRating = value);
                          },
                          activeColor: AppColors.softBlue,
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _notesController,
                          label: 'Notes (optional)',
                          hint: 'What did you study? Any issue?',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSession,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_alt_rounded),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Study Session',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkButton,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
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