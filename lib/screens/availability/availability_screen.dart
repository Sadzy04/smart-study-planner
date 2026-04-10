import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  String _formatDateDisplay(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$day/$month/$year';
  }

  String _formatTimeDisplay(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return raw;

    final hour24 = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  int _daySortValue(Map<String, dynamic> data) {
    final date = data['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return 999999999;
    return parsed.millisecondsSinceEpoch;
  }

  int _timeSortValue(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _weekdayLabel(int? day) {
    const labels = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return labels[day] ?? 'Unknown';
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'class':
        return const Color(0xFFE7F0FF);
      case 'event':
        return const Color(0xFFFFEAEF);
      case 'appointment':
        return const Color(0xFFEAFBF0);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String slotId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete blocked slot'),
            content: const Text(
              'Do you want to remove this blocked slot?',
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
      await FirestoreService().deleteBlockedSlot(slotId);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocked slot deleted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete blocked slot: $e')),
      );
    }
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 54,
            color: Color(0xFF8E7CF6),
          ),
          const SizedBox(height: 14),
          const Text(
            'No blocked slots yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add classes, events, or appointments so your planner can avoid unavailable times later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/add-blocked-slot');
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Slot'),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = data['title']?.toString() ?? 'Untitled';
    final type = data['type']?.toString() ?? 'other';
    final date = data['date']?.toString() ?? '';
    final startTime = data['startTime']?.toString() ?? '';
    final endTime = data['endTime']?.toString() ?? '';
    final isRecurring = data['isRecurring'] == true;
    final dayOfWeek = (data['dayOfWeek'] as num?)?.toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: _typeColor(type),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColor(type),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isRecurring)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EDFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Weekly • ${_weekdayLabel(dayOfWeek)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6D5BD0),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Date: ${_formatDateDisplay(date)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Time: ${_formatTimeDisplay(startTime)} - ${_formatTimeDisplay(endTime)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, doc.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
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
          'Availability & Events',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-blocked-slot'),
        label: const Text('Add Slot'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().getBlockedSlotsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading blocked slots: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...(snapshot.data?.docs ?? [])];

          docs.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final dateCompare =
                _daySortValue(aData).compareTo(_daySortValue(bData));
            if (dateCompare != 0) return dateCompare;

            final aStart = aData['startTime']?.toString() ?? '';
            final bStart = bData['startTime']?.toString() ?? '';
            return _timeSortValue(aStart).compareTo(_timeSortValue(bStart));
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your unavailable time blocks',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save classes, meetings, and events here. In the next step, the planner will use these slots to avoid impossible study timings.',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (docs.isEmpty)
                      _emptyState(context)
                    else
                      Column(
                        children: docs
                            .map((doc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _slotCard(context, doc),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}