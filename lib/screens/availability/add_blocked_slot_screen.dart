import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AddBlockedSlotScreen extends StatefulWidget {
  const AddBlockedSlotScreen({super.key});

  @override
  State<AddBlockedSlotScreen> createState() => _AddBlockedSlotScreenState();
}

class _AddBlockedSlotScreenState extends State<AddBlockedSlotScreen> {
  final TextEditingController _titleController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String _selectedType = 'class';
  bool _isRecurring = false;
  int _selectedDayOfWeek = 1;

  bool _isSaving = false;

  final List<String> _types = ['class', 'event', 'appointment', 'other'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateStorage(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$year-$month-$day';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _weekdayLabel(int day) {
    const days = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return days[day] ?? 'Monday';
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF8E7CF6), width: 1.3),
      ),
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6DFFF)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6D5BD0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined,
                color: Color(0xFF6D5BD0)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBlockedSlot() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a title.');
      return;
    }
    if (_selectedDate == null) {
      _showMessage('Please choose a date.');
      return;
    }
    if (_startTime == null) {
      _showMessage('Please choose a start time.');
      return;
    }
    if (_endTime == null) {
      _showMessage('Please choose an end time.');
      return;
    }
    if (_toMinutes(_endTime!) <= _toMinutes(_startTime!)) {
      _showMessage('End time must be after start time.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirestoreService().addBlockedSlot(
        title: title,
        date: _formatDateStorage(_selectedDate!),
        startTime: _formatTimeStorage(_startTime!),
        endTime: _formatTimeStorage(_endTime!),
        type: _selectedType,
        isRecurring: _isRecurring,
        dayOfWeek: _isRecurring ? _selectedDayOfWeek : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocked slot saved successfully.')),
      );

      Navigator.pop(context);
    } catch (e) {
      _showMessage('Failed to save blocked slot: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3FB),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Add Availability Block',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Save classes, events, or appointments',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These slots will later help the planner avoid unavailable times.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      label: 'Title',
                      hint: 'Example: Data Mining Class',
                      icon: Icons.event_note_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: _inputDecoration(
                      label: 'Type',
                      icon: Icons.category_outlined,
                    ),
                    items: _types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type[0].toUpperCase() + type.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _pickerTile(
                    label: 'Date',
                    value: _selectedDate == null
                        ? 'Choose a date'
                        : _formatDate(_selectedDate!),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _pickerTile(
                          label: 'Start Time',
                          value: _startTime == null
                              ? 'Choose start time'
                              : _formatTimeDisplay(_startTime!),
                          icon: Icons.access_time_outlined,
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pickerTile(
                          label: 'End Time',
                          value: _endTime == null
                              ? 'Choose end time'
                              : _formatTimeDisplay(_endTime!),
                          icon: Icons.schedule_outlined,
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile(
                    value: _isRecurring,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor: const Color(0xFFF8F6FF),
                    title: const Text(
                      'Recurring weekly slot',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Turn this on for weekly classes or repeated events.',
                    ),
                    onChanged: (value) {
                      setState(() => _isRecurring = value);
                    },
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedDayOfWeek,
                      decoration: _inputDecoration(
                        label: 'Day of Week',
                        icon: Icons.repeat_outlined,
                      ),
                      items: List.generate(7, (index) {
                        final day = index + 1;
                        return DropdownMenuItem<int>(
                          value: day,
                          child: Text(_weekdayLabel(day)),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDayOfWeek = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveBlockedSlot,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2A44),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Blocked Slot',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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