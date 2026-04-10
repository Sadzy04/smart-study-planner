import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/soft_text_field.dart';

class AddSubjectScreen extends StatefulWidget {
  const AddSubjectScreen({super.key});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _examDateController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  String _difficulty = 'Medium';
  String _confidence = 'Medium';
  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _examDateController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _examDateController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppColors.softPurple,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _saveSubject() async {
    FocusScope.of(context).unfocus();

    final subjectName = _subjectController.text.trim();
    final estimatedHours = int.tryParse(_hoursController.text.trim()) ?? 0;

    debugPrint('Save Subject clicked');
    debugPrint('Subject: $subjectName');
    debugPrint('Date: $_selectedDate');
    debugPrint('Hours: $estimatedHours');
    debugPrint('Difficulty: $_difficulty');
    debugPrint('Confidence: $_confidence');

    if (subjectName.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subject name.'),
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an exam date.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirestoreService().addSubject(
        subjectName: subjectName,
        examDate: _selectedDate!,
        estimatedHours: estimatedHours,
        difficultyLevel: _difficulty,
        confidenceLevel: _confidence,
      );

      debugPrint('Subject saved successfully');

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject saved to Firebase.'),
        ),
      );

      _subjectController.clear();
      _examDateController.clear();
      _hoursController.clear();

      setState(() {
        _selectedDate = null;
        _difficulty = 'Medium';
        _confidence = 'Medium';
        _isSaving = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Subject save failed: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save subject: $e'),
        ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopActionBar(
                    title: 'Add Subject',
                    subtitle: 'Create a subject with exam and confidence details',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.softYellow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white70,
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Subjects help the planner prioritize topics, exams, and revision blocks.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SoftTextField(
                    controller: _subjectController,
                    label: 'Subject Name',
                    hint: 'e.g. Data Mining',
                  ),
                  const SizedBox(height: 16),
                  SoftTextField(
                    controller: _examDateController,
                    label: 'Exam Date',
                    hint: 'Select exam date',
                    readOnly: true,
                    onTap: _pickDate,
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  const SizedBox(height: 16),
                  SoftTextField(
                    controller: _hoursController,
                    label: 'Estimated Total Hours',
                    hint: 'e.g. 18',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Difficulty Level',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: _dropdownDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _difficulty = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Confidence Level',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _confidence,
                    decoration: _dropdownDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _confidence = value);
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSubject,
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Subject'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TopActionBar({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}