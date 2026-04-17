import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/check_in.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/stage_particles.dart';

/// Card-stack style weekly insight report. Each card reveals one insight:
/// - Peace ratio for the week
/// - Best/hardest day
/// - Mood distribution
/// - Most-felt dimension
/// - Quote from a journal entry (if any)
/// - Encouragement / next week's focus
class WeeklyInsightsScreen extends StatefulWidget {
  const WeeklyInsightsScreen({super.key});

  @override
  State<WeeklyInsightsScreen> createState() => _WeeklyInsightsScreenState();
}

class _WeeklyInsightsScreenState extends State<WeeklyInsightsScreen> {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_InsightCard> _buildCards(UserProfile profile, List<CheckIn> checkIns) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekCheckIns = checkIns
        .where((c) => c.date.isAfter(weekAgo))
        .toList();

    // Compute mood distribution
    final moodCounts = <Mood, int>{};
    for (final c in weekCheckIns) {
      moodCounts[c.mood] = (moodCounts[c.mood] ?? 0) + 1;
    }
    final dominantMood = moodCounts.entries.isEmpty
        ? Mood.neutral
        : moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Peace days this week
    final peacefulDays = weekCheckIns
        .where((c) => c.mood == Mood.peaceful || c.mood == Mood.calm)
        .length;
    final ratio = weekCheckIns.isEmpty
        ? 0.0
        : peacefulDays / weekCheckIns.length;

    return [
      _InsightCard(
        kicker: 'WEEK ${(profile.daysSinceStart / 7).floor() + 1}',
        title: 'Your week of peace',
        subtitle:
            'Reflecting on the last 7 days of your journey toward becoming the ${_nextTitle(profile.currentTitle)}.',
        icon: Icons.brightness_3_rounded,
        color: AppColors.primary,
        bigStat: null,
      ),
      _InsightCard(
        kicker: 'PEACE RATIO',
        title: '${(ratio * 100).round()}%',
        subtitle: weekCheckIns.isEmpty
            ? 'No check-ins yet this week. Each one teaches you something.'
            : '$peacefulDays of ${weekCheckIns.length} check-ins were peaceful or hopeful.',
        icon: Icons.balance_rounded,
        color: ratio >= 0.7
            ? AppColors.peace
            : (ratio >= 0.4 ? AppColors.primary : AppColors.war),
        bigStat: '${(ratio * 100).round()}%',
        showRatioBar: true,
        ratioValue: ratio,
      ),
      _InsightCard(
        kicker: 'DOMINANT MOOD',
        title: _moodLabel(dominantMood),
        subtitle: _moodReflection(dominantMood),
        icon: _moodIcon(dominantMood),
        color: _moodColor(dominantMood),
        bigStat: null,
      ),
      _InsightCard(
        kicker: 'STREAK',
        title: '${profile.currentStreak} days',
        subtitle: profile.currentStreak == 0
            ? 'A new chapter starts today. Begin with one small choice.'
            : 'You\'ve sustained ${profile.currentStreak} consecutive days of practice. The discipline is becoming you.',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.primary,
        bigStat: '${profile.currentStreak}',
      ),
      _InsightCard(
        kicker: 'NEXT WEEK',
        title: 'Continue forward.',
        subtitle:
            'You\'re on Day ${profile.daysSinceStart + 1}. ${_nextMilestoneText(profile)}',
        icon: Icons.arrow_forward_rounded,
        color: AppColors.accent,
        bigStat: null,
        isLast: true,
      ),
    ];
  }

  String _nextTitle(UserTitle current) {
    switch (current) {
      case UserTitle.warrior:
        return 'Wanderer';
      case UserTitle.wanderer:
        return 'Seeker';
      case UserTitle.seeker:
        return 'Peacemaker';
      case UserTitle.peacemaker:
        return 'living embodiment of peace';
    }
  }

  String _nextMilestoneText(UserProfile profile) {
    final days = profile.totalDaysOfPeace;
    if (days < 7) return '${7 - days} more peaceful days unlock The Wanderer.';
    if (days < 30) return '${30 - days} more peaceful days unlock The Seeker.';
    if (days < 90) return '${90 - days} more peaceful days unlock The Peacemaker.';
    return 'You\'ve become The Peacemaker. Stay here.';
  }

  String _moodLabel(Mood m) {
    switch (m) {
      case Mood.peaceful:
        return 'Peaceful';
      case Mood.calm:
        return 'Calm';
      case Mood.neutral:
        return 'Neutral';
      case Mood.uneasy:
        return 'Uneasy';
      case Mood.struggling:
        return 'Struggling';
    }
  }

  String _moodReflection(Mood m) {
    switch (m) {
      case Mood.peaceful:
        return 'Peace was your most-felt state this week. You are starting to live it, not just chase it.';
      case Mood.calm:
        return 'Calm is the seed of every change. You\'ve been cultivating it daily.';
      case Mood.neutral:
        return 'Steadiness is its own kind of progress. Don\'t mistake calm for stagnation.';
      case Mood.uneasy:
        return 'Unease is information. Sit with it gently — it\'s pointing somewhere worth knowing.';
      case Mood.struggling:
        return 'Hard weeks are part of the path. Be gentle with yourself — every warrior has rest days.';
    }
  }

  Color _moodColor(Mood m) {
    switch (m) {
      case Mood.peaceful:
        return AppColors.peace;
      case Mood.calm:
        return AppColors.accent;
      case Mood.neutral:
        return AppColors.textSecondary;
      case Mood.uneasy:
        return AppColors.primary;
      case Mood.struggling:
        return AppColors.war;
    }
  }

  IconData _moodIcon(Mood m) {
    switch (m) {
      case Mood.peaceful:
        return Icons.spa_rounded;
      case Mood.calm:
        return Icons.wb_sunny_rounded;
      case Mood.neutral:
        return Icons.horizontal_rule_rounded;
      case Mood.uneasy:
        return Icons.cloud_rounded;
      case Mood.struggling:
        return Icons.flash_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final profile = userProvider.profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cards = _buildCards(profile, userProvider.checkIns);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.4,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: StageParticles(
              title: profile.currentTitle,
              particleCount: 16,
              opacity: 0.35,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybeOf(context)?.maybePop()
                            .then((didPop) {
                          if (!didPop) GoRouter.of(context).go('/journey');
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'WEEKLY INSIGHTS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // balance close button
                    ],
                  ),
                ),

                // Card stack
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, i) =>
                        _InsightCardView(card: cards[i], index: i),
                  ),
                ),

                // Page indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      cards.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentIndex ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
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

class _InsightCard {
  final String kicker;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? bigStat;
  final bool showRatioBar;
  final double ratioValue;
  final bool isLast;

  _InsightCard({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.bigStat,
    this.showRatioBar = false,
    this.ratioValue = 0.0,
    this.isLast = false,
  });
}

class _InsightCardView extends StatelessWidget {
  final _InsightCard card;
  final int index;
  const _InsightCardView({required this.card, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    card.color.withValues(alpha: 0.16),
                    card.color.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: card.color.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: card.color.withValues(alpha: 0.12),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Big icon badge
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: card.color.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(card.icon, color: card.color, size: 40),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(
                          begin: const Offset(0.7, 0.7),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          curve: Curves.easeOutBack),

                  const SizedBox(height: 24),

                  Text(
                    card.kicker,
                    style: TextStyle(
                      color: card.color.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  if (card.bigStat != null)
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          card.color,
                          Color.lerp(card.color, Colors.white, 0.4)!,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        card.bigStat!,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 64,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 500.ms)
                        .slideY(begin: 0.1, end: 0)
                  else
                    Text(
                      card.title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

                  if (card.bigStat != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      card.title == card.bigStat ? '' : card.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (card.showRatioBar) ...[
                    const SizedBox(height: 18),
                    _RatioBar(value: card.ratioValue, color: card.color),
                  ],

                  const SizedBox(height: 16),

                  Text(
                    card.subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

                  if (card.isLast) ...[
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () {
                        if (Navigator.maybeOf(context)?.maybePop() != null) {
                          Navigator.maybeOf(context)?.maybePop();
                        } else {
                          GoRouter.of(context).go('/journey');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: card.color.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Continue the journey',
                          style: TextStyle(
                            color: card.color,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  final double value;
  final Color color;
  const _RatioBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: math.max(0.02, value)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.5),
                    color,
                  ]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
