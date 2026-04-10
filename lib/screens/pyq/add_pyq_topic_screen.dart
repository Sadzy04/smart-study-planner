import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/soft_text_field.dart';

class AddPyqTopicScreen extends StatefulWidget {
  const AddPyqTopicScreen({super.key});

  @override
  State<AddPyqTopicScreen> createState() => _AddPyqTopicScreenState();
}

class _AddPyqTopicScreenState extends State<AddPyqTopicScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _questionTextController = TextEditingController();

  String? _selectedSubject;
  bool _isSaving = false;

  @override
  void dispose() {
    _topicController.dispose();
    _yearController.dispose();
    _frequencyController.dispose();
    _marksController.dispose();
    _questionTextController.dispose();
    super.dispose();
  }

  Future<void> _savePyqTopic() async {
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject.')),
      );
      return;
    }

    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic name.')),
      );
      return;
    }

    final year = int.tryParse(_yearController.text.trim());
    final frequency = int.tryParse(_frequencyController.text.trim());
    final marks = int.tryParse(_marksController.text.trim()) ?? 0;

    if (year == null || year < 2000 || year > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid year.')),
      );
      return;
    }

    if (frequency == null || frequency <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid frequency count.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirestoreService().addPyqTopic(
        subjectName: _selectedSubject!,
        topicName: _topicController.text.trim(),
        year: year,
        frequencyCount: frequency,
        marksWeight: marks,
        questionText: _questionTextController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PYQ topic saved successfully.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PYQ topic: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                              'Add PYQ Topic',
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
                        'Manual entry is the best fit here: topic, year, repeated occurrence, and marks weight.',
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
                            'No subjects found yet. Add a subject first before adding PYQ topics.',
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
                                setState(() => _selectedSubject = value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _topicController,
                          label: 'Topic Name',
                          hint: 'Example: Normalization',
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _yearController,
                          label: 'Year',
                          hint: 'Example: 2024',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _frequencyController,
                          label: 'Frequency Count',
                          hint: 'Example: 4',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _marksController,
                          label: 'Marks Weight (optional)',
                          hint: 'Example: 10',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 18),
                        SoftTextField(
                          controller: _questionTextController,
                          label: 'Question Text (optional)',
                          hint: 'Paste the PYQ text if you want',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _savePyqTopic,
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
                              _isSaving ? 'Saving...' : 'Save PYQ Topic',
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