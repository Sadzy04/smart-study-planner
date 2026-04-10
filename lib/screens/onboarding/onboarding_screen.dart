import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 360,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.lavender,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Stack(
                              children: const [
                                Positioned(
                                  top: 28,
                                  left: 26,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  top: 70,
                                  right: 45,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                                Positioned(
                                  top: 100,
                                  left: 70,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                Center(
                                  child: _HeroGraphic(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Plan Smarter.\nStudy Better.',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Organize subjects, track progress, view PYQ insights, '
                                  'and generate an optimized study plan with a calm, focused workflow.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/home',
                                          );
                                        },
                                        child: const Text('Get Started'),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      height: 52,
                                      width: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.softPurple,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.darkButton,
                                          width: 1.1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroGraphic extends StatelessWidget {
  const _HeroGraphic();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            size: 90,
            color: Color(0xFF9CB7E8),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Smart Study Planner',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}