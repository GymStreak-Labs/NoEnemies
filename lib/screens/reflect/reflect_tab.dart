import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/stage_particles.dart';

class ReflectTab extends StatelessWidget {
  const ReflectTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final journalCount = userProvider.journalEntries.length;
    final bookmarkedCount =
        userProvider.journalEntries.where((e) => e.isBookmarked).length;
    final profile = userProvider.profile;
    final stage = profile?.currentTitle ?? UserTitle.warrior;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background tinted to match user's stage
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.4,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.04),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Stage-specific particles
          Positioned.fill(
            child: StageParticles(
              title: stage,
              particleCount: 18,
              opacity: 0.3,
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
                    'Reflect',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 4),

                  Text(
                    'Look inward. Find peace.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                  const SizedBox(height: 28),

                  _SectionLabel('DAILY PRACTICE'),
                  const SizedBox(height: 14),

                  _PracticeCard(
                    title: 'Morning Check-in',
                    subtitle: 'Set your intention for the day',
                    duration: '2 min',
                    icon: Icons.wb_sunny_outlined,
                    accentColor: AppColors.primary,
                    isCompleted: userProvider.hasMorningCheckInToday,
                    onTap: () => context.push('/morning-check-in'),
                  ),

                  const SizedBox(height: 12),

                  _PracticeCard(
                    title: 'Evening Reflection',
                    subtitle: 'Look back. Rate your peace.',
                    duration: '3-5 min',
                    icon: Icons.nights_stay_outlined,
                    accentColor: AppColors.accent,
                    isCompleted: userProvider.hasEveningReflectionToday,
                    onTap: () => context.push('/evening-reflection'),
                  ),

                  const SizedBox(height: 32),

                  _SectionLabel('WEEKLY INSIGHTS'),
                  const SizedBox(height: 14),

                  _PracticeCard(
                    title: 'Your Week of Peace',
                    subtitle: 'Card-stack report of the last 7 days',
                    duration: 'New',
                    icon: Icons.insights_rounded,
                    accentColor: AppColors.primary,
                    isCompleted: false,
                    onTap: () => context.push('/insights/weekly'),
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionLabel('JOURNAL'),
                      if (journalCount > 0)
                        GestureDetector(
                          onTap: () => context.push('/journal'),
                          child: Text(
                            'View all',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _JournalCard(
                    entryCount: journalCount,
                    onTap: () => context.push('/journal/new'),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 32),

                  _SectionLabel('BOOK OF PEACE'),
                  const SizedBox(height: 14),

                  _BookOfPeaceCard(
                    bookmarkedCount: bookmarkedCount,
                    onTap: bookmarkedCount > 0
                        ? () => context.push('/journal')
                        : null,
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        fontSize: 11,
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
  final Color accentColor;
  final bool isCompleted;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.accentColor,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted
                    ? AppColors.peace.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              duration,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Icon(Icons.check_circle, color: AppColors.peace, size: 24)
                else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textTertiary,
                    size: 14,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final int entryCount;
  final VoidCallback onTap;

  const _JournalCard({required this.entryCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.peace.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.peace.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.peace,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Write in your journal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entryCount == 0
                            ? 'Start your first entry'
                            : '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textTertiary,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookOfPeaceCard extends StatelessWidget {
  final int bookmarkedCount;
  final VoidCallback? onTap;

  const _BookOfPeaceCard({required this.bookmarkedCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.accent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFE8C87A),
                      Color(0xFFD4A853),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Your Book of Peace',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bookmarkedCount == 0
                      ? 'As you journey, your wisest reflections will be collected here — building your personal philosophy of peace.'
                      : 'Your collected wisdom: $bookmarkedCount ${bookmarkedCount == 1 ? "passage" : "passages"} saved.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (bookmarkedCount == 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Bookmark journal entries to add them here.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
