import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/protected_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/availability/add_blocked_slot_screen.dart';
import 'screens/availability/availability_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/planner/planner_screen.dart';
import 'screens/profile/profile_settings_screen.dart';
import 'screens/pyq/add_pyq_topic_screen.dart';
import 'screens/pyq/pyq_insights_screen.dart';
import 'screens/study_sessions/log_study_session_screen.dart';
import 'screens/subjects/add_subject_screen.dart';
import 'screens/subjects/all_subjects_screen.dart';
import 'screens/tasks/add_task_screen.dart';
import 'screens/tasks/all_tasks_screen.dart';
class SmartStudyPlannerApp extends StatelessWidget {
  const SmartStudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Study Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const ProtectedScreen(child: HomeScreen()),
        '/add-subject': (context) =>
            const ProtectedScreen(child: AddSubjectScreen()),
        '/add-task': (context) =>
            const ProtectedScreen(child: AddTaskScreen()),
        '/planner': (context) =>
            const ProtectedScreen(child: PlannerScreen()),
        '/all-tasks': (context) =>
            const ProtectedScreen(child: AllTasksScreen()),
        '/all-subjects': (context) =>
            const ProtectedScreen(child: AllSubjectsScreen()),
        '/log-session': (context) =>
            const ProtectedScreen(child: LogStudySessionScreen()),
        '/pyq-insights': (context) =>
            const ProtectedScreen(child: PyqInsightsScreen()),
        '/add-pyq-topic': (context) =>
            const ProtectedScreen(child: AddPyqTopicScreen()),
        '/profile-settings': (context) =>
            const ProtectedScreen(child: ProfileSettingsScreen()),
        '/availability': (context) =>
            const ProtectedScreen(child: AvailabilityScreen()),

        '/add-blocked-slot': (context) =>
            const ProtectedScreen(child: AddBlockedSlotScreen()),
        '/analytics': (context) =>
            const ProtectedScreen(child: AnalyticsScreen()),
      },
    );
  }
}