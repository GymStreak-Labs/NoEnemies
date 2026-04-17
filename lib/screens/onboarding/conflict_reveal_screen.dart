import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';
import '../../models/conflict_type.dart';

class ConflictRevealScreen extends StatefulWidget {
  const ConflictRevealScreen({super.key});

  @override
  State<ConflictRevealScreen> createState() => _ConflictRevealScreenState();
}

class _ConflictRevealScreenState extends State<ConflictRevealScreen>
    with TickerProviderStateMixin {
  bool _showContent = false;
  bool _showConflictName = false;
  bool _showDescription = false;
  bool _showCharacter = false;
  bool _showJourneyMessage = false;
  bool _showButton = false;
  late AnimationController _pulseController;
  late AnimationController _revealController;
  late Animation<double> _revealScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _revealScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Curves.easeOutBack,
      ),
    );

    _startRevealSequence();
  }

  Future<void> _startRevealSequence() async {
    // Initial dark moment — let it breathe
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Show "Your Inner Conflict" label
    setState(() => _showContent = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Reveal the conflict type name dramatically
    setState(() => _showConflictName = true);
    _revealController.forward();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Show description line by line
    setState(() => _showDescription = true);

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // Show character
    setState(() => _showCharacter = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Show journey message
    setState(() => _showJourneyMessage = true);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Show continue button
    setState(() => _showButton = true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  /// Maps ConflictType enum values to the corresponding image file name
  /// in assets/images/conflicts/.
  String _getConflictFileName(ConflictType conflict) {
    switch (conflict) {
      case ConflictType.resentment:
        return 'resentment';
      case ConflictType.selfHatred:
        return 'self_criticism';
      case ConflictType.comparison:
        return 'comparison';
      case ConflictType.workplace:
        return 'workplace';
      case ConflictType.relationship:
        return 'relationship';
      case ConflictType.identity:
        return 'identity';
      case ConflictType.grief:
        return 'grief';
      case ConflictType.addiction:
        return 'addiction';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;
    if (profile == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final conflict = profile.primaryConflict;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dark atmospheric background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.0 + t * 0.2,
                      colors: [
                        AppColors.war.withValues(alpha: 0.08 + t * 0.04),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Particles with war color transitioning
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 20,
              color: AppColors.war,
              opacity: 0.25,
              maxParticleSize: 2.5,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Section label
                  if (_showContent)
                    Text(
                      'YOUR INNER CONFLICT',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    AppColors.textTertiary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4,
                                fontSize: 12,
                              ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 800.ms),

                  const SizedBox(height: 40),

                  // Conflict emoji with dramatic reveal
                  if (_showConflictName)
                    AnimatedBuilder(
                      animation: _revealController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _revealScale.value,
                          child: Opacity(
                            opacity: _revealController.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          // Conflict illustration with pulsing glow
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 220 + _pulseController.value * 20,
                                    height: 220 + _pulseController.value * 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.primary
                                              .withValues(alpha: 0.15),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Image.asset(
                                'assets/images/conflicts/${_getConflictFileName(conflict)}.png',
                                width: 200,
                                height: 200,
                                cacheWidth: 400,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Conflict type name with golden gradient
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                Color(0xFFE8C87A),
                                Color(0xFFD4A853),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              conflict.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 34,
                                    letterSpacing: 0.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Description — appears with weight
                  if (_showDescription)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        conflict.description,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.7,
                                  fontSize: 15,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.1, end: 0, duration: 800.ms),

                  const SizedBox(height: 36),

                  // Character section
                  if (_showCharacter)
                    Column(
                      children: [
                        Text(
                          'You begin as',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textTertiary,
                                letterSpacing: 1,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width:
                                      150 + _pulseController.value * 15,
                                  height:
                                      150 + _pulseController.value * 15,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.war
                                            .withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Image.asset(
                              'assets/images/characters/warrior.png',
                              width: 130,
                              height: 130,
                              cacheWidth: 260,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The Warrior',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppColors.war,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Still fighting, but aware',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                        ),

                  const SizedBox(height: 28),

                  // Journey message
                  if (_showJourneyMessage)
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            conflict.journeyMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppColors.primary,
                                  height: 1.7,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 15,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.08, end: 0, duration: 800.ms),

                  const SizedBox(height: 40),

                  // Continue button
                  if (_showButton)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFD4A853),
                              Color(0xFFE8C87A),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => context.go('/paywall'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Continue Your Journey',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0, duration: 600.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
