import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final ProfileService _profileService = ProfileService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  final TextEditingController _preferredStudyHoursController =
      TextEditingController();
  final TextEditingController _maxStudyBlockController =
      TextEditingController();
  final TextEditingController _preferredBreakController =
      TextEditingController();

  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _semesterController.dispose();
    _preferredStudyHoursController.dispose();
    _maxStudyBlockController.dispose();
    _preferredBreakController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();

      _nameController.text = (profile['name'] ?? '').toString();
      _semesterController.text = (profile['semester'] ?? '').toString();
      _preferredStudyHoursController.text =
          ((profile['preferredStudyHours'] ?? 4) as num).toInt().toString();
      _maxStudyBlockController.text =
          ((profile['maxStudyBlockMinutes'] ?? 90) as num).toInt().toString();
      _preferredBreakController.text =
          ((profile['preferredBreakMinutes'] ?? 15) as num).toInt().toString();

      _wakeTime = _parseTime((profile['wakeTime'] ?? '07:00').toString());
      _sleepTime = _parseTime((profile['sleepTime'] ?? '23:00').toString());
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to load profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 7, minute: 0);
    }

    final hour = int.tryParse(parts[0]) ?? 7;
    final minute = int.tryParse(parts[1]) ?? 0;

    return TimeOfDay(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  String _formatTimeStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime,
    );

    if (picked != null) {
      setState(() => _wakeTime = picked);
    }
  }

  Future<void> _pickSleepTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sleepTime,
    );

    if (picked != null) {
      setState(() => _sleepTime = picked);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final semester = _semesterController.text.trim();
    final preferredStudyHours =
        int.tryParse(_preferredStudyHoursController.text.trim());
    final maxStudyBlock =
        int.tryParse(_maxStudyBlockController.text.trim());
    final preferredBreak =
        int.tryParse(_preferredBreakController.text.trim());

    if (name.isEmpty) {
      _showMessage('Please enter your name.');
      return;
    }

    if (preferredStudyHours == null || preferredStudyHours <= 0) {
      _showMessage('Preferred study hours must be a valid number.');
      return;
    }

    if (maxStudyBlock == null || maxStudyBlock <= 0) {
      _showMessage('Max study block minutes must be a valid number.');
      return;
    }

    if (preferredBreak == null || preferredBreak <= 0) {
      _showMessage('Preferred break minutes must be a valid number.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _profileService.updateProfile(
        name: name,
        semester: semester,
        wakeTime: _formatTimeStorage(_wakeTime),
        sleepTime: _formatTimeStorage(_sleepTime),
        preferredStudyHours: preferredStudyHours,
        maxStudyBlockMinutes: maxStudyBlock,
        preferredBreakMinutes: preferredBreak,
      );

      if (!mounted) return;
      _showMessage('Profile & preferences saved successfully.');
    } catch (e) {
      _showMessage('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _logout() async {
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

      if (!mounted) return;
      _showMessage('Logged out successfully.');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Logout failed: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF8E7CF6), width: 1.4),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTimeTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6DFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xFF6D5BD0)),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule_rounded, color: Color(0xFF6D5BD0)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        hint: hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6F3FB),
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Final account settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep this simple for demo: your identity, study preferences, and account control.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),

                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Basic Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                label: 'Name',
                                icon: Icons.person_outline_rounded,
                                hint: 'Enter your name',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _semesterController,
                              decoration: _inputDecoration(
                                label: 'Semester',
                                icon: Icons.school_outlined,
                                hint: 'Example: 6',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Study Preferences',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTimeTile(
                              label: 'Wake Time',
                              value: _formatTimeDisplay(_wakeTime),
                              icon: Icons.wb_sunny_outlined,
                              onTap: _pickWakeTime,
                            ),
                            const SizedBox(height: 12),
                            _buildTimeTile(
                              label: 'Sleep Time',
                              value: _formatTimeDisplay(_sleepTime),
                              icon: Icons.nightlight_round_outlined,
                              onTap: _pickSleepTime,
                            ),
                            const SizedBox(height: 14),
                            _buildNumberField(
                              controller: _preferredStudyHoursController,
                              label: 'Preferred Study Hours Per Day',
                              icon: Icons.timelapse_rounded,
                              hint: 'Example: 4',
                            ),
                            const SizedBox(height: 14),
                            _buildNumberField(
                              controller: _maxStudyBlockController,
                              label: 'Max Study Block Minutes',
                              icon: Icons.hourglass_bottom_rounded,
                              hint: 'Example: 90',
                            ),
                            const SizedBox(height: 14),
                            _buildNumberField(
                              controller: _preferredBreakController,
                              label: 'Preferred Break Minutes',
                              icon: Icons.free_breakfast_outlined,
                              hint: 'Example: 15',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Use logout here too so the settings page feels like a complete final screen.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Log Out'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7A3E54),
                                  side: const BorderSide(
                                    color: Color(0xFFE8B9C8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2A44),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Settings',
                            style: const TextStyle(
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
    );
  }
}