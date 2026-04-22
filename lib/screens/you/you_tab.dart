import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/current_emotion.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/emotion_aura.dart';
import '../../widgets/stage_particles.dart';
import '../onboarding/intro_cinematic_screen.dart';

class YouTab extends StatelessWidget {
  const YouTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background with character-color tint
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [
                    _titleColor(profile.currentTitle).withValues(alpha: 0.04),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Stage-specific particles (embers/dust/bioluminescence/petals)
          Positioned.fill(
            child: StageParticles(
              title: profile.currentTitle,
              particleCount: 24,
              opacity: 0.4,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'You',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      GestureDetector(
                        onTap: () => _showSettingsSheet(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.settings_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 28),

                  // Character with animated glow
                  _AnimatedCharacterSection(profile: profile),

                  const SizedBox(height: 8),

                  // Title progression
                  _TitleProgressBar(
                    currentTitle: profile.currentTitle,
                    totalDays: profile.totalDaysOfPeace,
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // Stats grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Days of Peace',
                          value: '${profile.totalDaysOfPeace}',
                          icon: Icons.spa_outlined,
                          color: AppColors.peace,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Current Streak',
                          value: '${profile.currentStreak}',
                          icon: Icons.local_fire_department_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Peace Ratio',
                          value: '${(profile.peaceRatio * 100).round()}%',
                          icon: Icons.pie_chart_outline,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Day',
                          value: '${profile.daysSinceStart + 1}',
                          icon: Icons.calendar_today_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // Conflict Type
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Your Inner Conflict',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Hand-painted Norse rune
                            Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                profile.primaryConflict.runeAsset,
                                fit: BoxFit.contain,
                                cacheHeight: 200,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.primaryConflict.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.primaryConflict.journeyMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textTertiary,
                                          height: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // Peace vs War breakdown
                  _PeaceWarBar(
                    peaceDays: profile.peaceDays,
                    warDays: profile.warDays,
                  ).animate().fadeIn(delay: 900.ms, duration: 400.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _titleColor(UserTitle title) {
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

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final storage = context.read<StorageService>();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  _SettingsItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Coming soon',
                  ),
                  _SettingsItem(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Coming soon',
                  ),
                  // Voice journaling — save audio alongside the transcript so
                  // you can replay yourself later. Transcript is always kept.
                  _SettingsToggle(
                    icon: Icons.mic_none_rounded,
                    title: 'Save audio with voice entries',
                    subtitle: storage.saveVoiceAudio
                        ? 'Your recordings are kept for replay'
                        : 'Spark mode: only the transcript is kept',
                    value: storage.saveVoiceAudio,
                    onChanged: (v) async {
                      await storage.setSaveVoiceAudio(v);
                      setSheetState(() {});
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Coming soon',
                  ),
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: 'About No Enemies',
                    subtitle: 'Version 1.0.0',
                  ),
                  const SizedBox(height: 8),
                  // Debug: replay cinematic intro
                  _SettingsItem(
                    icon: Icons.replay_outlined,
                    title: 'Replay Intro',
                    subtitle: 'Rewatch the cinematic opening',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await IntroCinematicScreen.resetSeen();
                      if (context.mounted) {
                        GoRouter.of(context).go('/intro');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Sign out — routes back to /auth.
                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    title: 'Sign out',
                    subtitle: 'Return to sign-in',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _handleSignOut(context);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final authService = context.read<AuthService>();
    try {
      await authService.signOut();
    } catch (e) {
      debugPrint('[YouTab] signOut failed: $e');
    }
    if (context.mounted) {
      GoRouter.of(context).go('/auth');
    }
  }
}

class _AnimatedCharacterSection extends StatefulWidget {
  final UserProfile profile;

  const _AnimatedCharacterSection({required this.profile});

  @override
  State<_AnimatedCharacterSection> createState() =>
      _AnimatedCharacterSectionState();
}

class _AnimatedCharacterSectionState extends State<_AnimatedCharacterSection>
    with SingleTickerProviderStateMixin {
  // Separate shimmer controller just for the progress ring — decoupled from
  // the breath animation (which now lives in EmotionAura) so a troubled state
  // doesn't make the ring shimmer faster than reads well.
  late AnimationController _ringShimmer;

  @override
  void initState() {
    super.initState();
    _ringShimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringShimmer.dispose();
    super.dispose();
  }

  Color get _stageColor {
    switch (widget.profile.currentTitle) {
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

  String get _portraitAsset {
    switch (widget.profile.currentTitle) {
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

  /// Progress (0.0 - 1.0) from current title's threshold toward the next.
  double _progressToNextStage() {
    final days = widget.profile.totalDaysOfPeace;
    final current = widget.profile.currentTitle;
    int currentThreshold = current.requiredDays;
    int? nextThreshold;
    switch (current) {
      case UserTitle.warrior:
        nextThreshold = UserTitle.wanderer.requiredDays;
        break;
      case UserTitle.wanderer:
        nextThreshold = UserTitle.seeker.requiredDays;
        break;
      case UserTitle.seeker:
        nextThreshold = UserTitle.peacemaker.requiredDays;
        break;
      case UserTitle.peacemaker:
        return 1.0; // Maxed
    }
    final span = nextThreshold - currentThreshold;
    if (span <= 0) return 1.0;
    final progress = (days - currentThreshold) / span;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final emotion = context.watch<UserProvider>().currentEmotion();
    // The ring color blends the stage with the emotion's aura color so it
    // matches whatever halo the EmotionAura widget is drawing.
    final ringColor = switch (emotion) {
      CurrentEmotion.calm => _stageColor,
      _ => Color.lerp(_stageColor, emotion.auraColor, 0.4) ?? _stageColor,
    };

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring — arc showing progress to next stage.
              AnimatedBuilder(
                animation: _ringShimmer,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(280, 280),
                    painter: _ProgressRingPainter(
                      progress: _progressToNextStage(),
                      color: ringColor,
                      shimmerT: _ringShimmer.value,
                      isMaxed:
                          widget.profile.currentTitle == UserTitle.peacemaker,
                    ),
                  );
                },
              ),
              // Character portrait wrapped in the emotion-reactive aura.
              EmotionAura(
                emotion: emotion,
                baseColor: _stageColor,
                auraSize: 280,
                child: Image.asset(
                  _portraitAsset,
                  height: 320,
                  fit: BoxFit.fitHeight,
                  cacheHeight: 800,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 600.ms),

        const SizedBox(height: 16),

        Text(
          'The ${widget.profile.currentTitle.displayName}',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: ringColor,
                fontWeight: FontWeight.w700,
              ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

        Text(
          widget.profile.currentTitle.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
              ),
        ).animate().fadeIn(delay: 400.ms, duration: 300.ms),

        if (emotion != CurrentEmotion.calm) ...[
          const SizedBox(height: 6),
          Text(
            emotion.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: emotion.auraColor.withValues(alpha: 0.9),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
          ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
        ],
      ],
    );
  }
}

class _TitleProgressBar extends StatelessWidget {
  final UserTitle currentTitle;
  final int totalDays;

  const _TitleProgressBar({
    required this.currentTitle,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: UserTitle.values.map((title) {
              final isReached = totalDays >= title.requiredDays;
              final isCurrent = title == currentTitle;
              return Column(
                children: [
                  Container(
                    width: isCurrent ? 16 : 12,
                    height: isCurrent ? 16 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isReached
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isReached
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isCurrent ? 2 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isReached
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    title.requiredDays == 0
                        ? 'Start'
                        : '${title.requiredDays}d',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeaceWarBar extends StatelessWidget {
  final int peaceDays;
  final int warDays;

  const _PeaceWarBar({required this.peaceDays, required this.warDays});

  @override
  Widget build(BuildContext context) {
    final total = peaceDays + warDays;
    final peacePercent = total == 0 ? 0.5 : peaceDays / total;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peace vs Struggle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Flexible(
                    flex: (peacePercent * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.peace.withValues(alpha: 0.7),
                            AppColors.peace,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: ((1 - peacePercent) * 100).round().clamp(1, 99),
                    child: Container(
                        color: AppColors.war.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.peace,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$peaceDays peaceful',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.peace,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.war.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$warDays struggle',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.war,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (total == 0) ...[
            const SizedBox(height: 8),
            Text(
              'Complete check-ins to see your ratio',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

/// Animated arc ring drawn around the character showing progress to next stage.
/// At Peacemaker (final stage), draws a full glowing closed ring instead.
class _ProgressRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final double shimmerT;
  final bool isMaxed;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.shimmerT,
    required this.isMaxed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (isMaxed) {
      // Full ring with shimmer for Peacemaker
      final shimmerOpacity = 0.5 + 0.4 * shimmerT;
      final maxedPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            color.withValues(alpha: shimmerOpacity),
            color.withValues(alpha: shimmerOpacity * 0.6),
            color.withValues(alpha: shimmerOpacity),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(shimmerT * 6.283),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, maxedPaint);
      return;
    }

    if (progress <= 0) return;

    // Progress arc (starts at top, sweeps clockwise)
    final progressPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final startAngle = -1.5708; // -pi/2 (top)
    final sweep = 6.283 * progress; // 2pi * progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      progressPaint,
    );

    // Glowing dot at the end of the arc
    final endAngle = startAngle + sweep;
    final dotX = center.dx + radius * math.cos(endAngle);
    final dotY = center.dy + radius * math.sin(endAngle);
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.9 + shimmerT * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(dotX, dotY), 5, dotPaint);
    canvas.drawCircle(
        Offset(dotX, dotY), 3, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.shimmerT != shimmerT ||
      old.isMaxed != isMaxed;
}
