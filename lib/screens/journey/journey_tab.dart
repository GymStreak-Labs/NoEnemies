import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../providers/journey_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/emotion_aura.dart';
import '../../widgets/stage_particles.dart';
import '../../widgets/peace_streak_card.dart';
import '../../widgets/today_card.dart';
import '../../widgets/voyage_map.dart';

class JourneyTab extends StatefulWidget {
  const JourneyTab({super.key});

  @override
  State<JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<JourneyTab> {
  @override
  void initState() {
    super.initState();
    // Check for a pending stage transition once the first frame is on screen,
    // then push the cinematic. This fires when the user opens the app for
    // the first time after crossing 7/30/90 days of peace.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForStageTransition();
    });
  }

  void _checkForStageTransition() {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final transition = userProvider.pendingStageTransition();
    if (transition == null) return;
    GoRouter.of(context).push(
      '/stage-transition',
      extra: {
        'from': transition.from,
        'to': transition.to,
      },
    );
  }

  static String _backgroundForTitle(UserTitle title) {
    switch (title) {
      case UserTitle.warrior:
        return 'assets/images/backgrounds/bg_warrior.png';
      case UserTitle.wanderer:
        return 'assets/images/backgrounds/bg_wanderer.png';
      case UserTitle.seeker:
        return 'assets/images/backgrounds/bg_seeker.png';
      case UserTitle.peacemaker:
        return 'assets/images/backgrounds/bg_peacemaker.png';
    }
  }

  static Color _stageColor(UserTitle title) {
    switch (title) {
      case UserTitle.warrior:
        return AppColors.war;
      case UserTitle.wanderer:
        return AppColors.primary;
      case UserTitle.seeker:
        return AppColors.accent;
      case UserTitle.peacemaker:
        return AppColors.peace;
    }
  }

  static String _portraitForTitle(UserTitle title) {
    switch (title) {
      case UserTitle.warrior:
        return 'assets/images/characters/warrior_portrait.png';
      case UserTitle.wanderer:
        return 'assets/images/characters/wanderer_portrait.png';
      case UserTitle.seeker:
        return 'assets/images/characters/seeker_portrait.png';
      case UserTitle.peacemaker:
        return 'assets/images/characters/peacemaker_portrait.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final journeyProvider = context.read<JourneyProvider>();
    final profile = userProvider.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final isEvening = now.hour >= 17;
    final isMorning = now.hour < 12;

    final peaceMission =
        journeyProvider.getPeaceMission(profile.primaryConflict);

    final headerHeight = MediaQuery.of(context).size.height * 0.5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Parallax Header ──
              SliverAppBar(
                expandedHeight: headerHeight,
                backgroundColor: Colors.black,
                pinned: false,
                floating: false,
                stretch: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Stage background image
                      Image.asset(
                        _backgroundForTitle(profile.currentTitle),
                        fit: BoxFit.cover,
                        cacheWidth: 1080,
                      ),

                      // Subtle darkening for character contrast
                      Container(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),

                      // Character portrait — composited onto the landscape.
                      // The EmotionAura drives both the breath animation and
                      // the subtle colored halo behind the character so the
                      // portrait visibly reacts to recent check-in moods.
                      Positioned(
                        right: -40,
                        bottom: -10,
                        top: 20,
                        child: EmotionAura(
                          emotion: userProvider.currentEmotion(),
                          baseColor: _stageColor(profile.currentTitle),
                          auraSize: headerHeight * 0.7,
                          breathAmount: 0.6,
                          child: Image.asset(
                            _portraitForTitle(profile.currentTitle),
                            fit: BoxFit.fitHeight,
                            cacheHeight: 1200,
                          ),
                        ),
                      ),

                      // Gradient overlay: dark at bottom to blend into content
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.5, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black,
                            ],
                          ),
                        ),
                      ),

                      // Stage-specific ambient particles (embers/dust/glow/petals)
                      StageParticles(
                        title: profile.currentTitle,
                        particleCount: 28,
                        opacity: 0.7,
                      ),

                      // Header content
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting(now),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Day ${profile.daysSinceStart + 1} of your journey',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                            ),
                            const SizedBox(height: 8),
                            // Title badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 8, sigmaY: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shield,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'The ${profile.currentTitle.displayName}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Voyage Map (parchment + ship)
                      VoyageMap(
                        daysSinceStart: profile.daysSinceStart,
                        totalPeaceDays: profile.totalDaysOfPeace,
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 16),

                      // Today's actions
                      if (isMorning || !userProvider.hasMorningCheckInToday)
                        TodayCard(
                          title: 'Morning Check-in',
                          subtitle: 'Set your intention for today',
                          icon: Icons.wb_sunny_outlined,
                          accentColor: AppColors.primary,
                          isCompleted: userProvider.hasMorningCheckInToday,
                          onTap: () => context.push('/morning-check-in'),
                        ),

                      if (userProvider.hasMorningCheckInToday)
                        const SizedBox(height: 12),

                      if (isEvening || userProvider.hasMorningCheckInToday)
                        TodayCard(
                          title: 'Evening Reflection',
                          subtitle: 'Reflect on your day',
                          icon: Icons.nights_stay_outlined,
                          accentColor: AppColors.accent,
                          isCompleted: userProvider.hasEveningReflectionToday,
                          onTap: () => context.push('/evening-reflection'),
                        ),

                      const SizedBox(height: 16),

                      // Peace Mission
                      _PeaceMissionCard(mission: peaceMission)
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 400.ms),

                      const SizedBox(height: 16),

                      // Streak card
                      PeaceStreakCard(
                        currentStreak: profile.currentStreak,
                        longestStreak: profile.longestStreak,
                        totalDaysOfPeace: profile.totalDaysOfPeace,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}


class _PeaceMissionCard extends StatelessWidget {
  final String mission;

  const _PeaceMissionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.accent.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\'s Peace Mission',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mission,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
