import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';

class CrewTab extends StatelessWidget {
  const CrewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Accent-tinted background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.5,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.03),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  Text(
                    'Crew',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 4),

                  Text(
                    'You don\'t have to walk this path alone.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                  const SizedBox(height: 48),

                  // Coming soon illustration
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            color: AppColors.accent,
                            size: 56,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1, 1),
                              delay: 200.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutBack,
                            ),

                        const SizedBox(height: 24),

                        Text(
                          'Coming Soon',
                          style:
                              Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: AppColors.accent,
                                  ),
                        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

                        const SizedBox(height: 16),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Crews are small groups of 5-8 people matched by '
                            'conflict type. You\'ll share weekly check-ins, '
                            'support each other through challenges, and grow '
                            'together.',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.6,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Feature preview cards
                  _CrewFeatureCard(
                    icon: Icons.people_outline,
                    title: 'Matched Groups',
                    description:
                        'Paired with people who share your type of inner conflict. '
                        'They understand because they\'re on the same journey.',
                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  _CrewFeatureCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Weekly Check-ins',
                    description:
                        'Share how your week went. Celebrate wins. '
                        'Get support during hard days. Stay accountable.',
                  ).animate().fadeIn(delay: 900.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  _CrewFeatureCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Shared Challenges',
                    description:
                        'Take on peace missions together. When your crew '
                        'succeeds, everyone grows.',
                  ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _CrewFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
