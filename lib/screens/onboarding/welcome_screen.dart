import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/character_avatar.dart';
import '../../widgets/ambient_particles.dart';
import '../../models/user_profile.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient that subtly animates
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breatheController,
              builder: (context, child) {
                final t = _breatheController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.3 + t * 0.1),
                      radius: 1.2 + t * 0.15,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.06 + t * 0.03),
                        AppColors.background.withValues(alpha: 0.95),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Ambient particles
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 25,
              color: AppColors.primary,
              opacity: 0.35,
              maxParticleSize: 2.5,
              minParticleSize: 0.8,
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Character with dramatic entrance
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow behind character
                      AnimatedBuilder(
                        animation: _breatheController,
                        builder: (context, child) {
                          return Container(
                            width: 200 + _breatheController.value * 20,
                            height: 200 + _breatheController.value * 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.war.withValues(
                                      alpha:
                                          0.12 + _breatheController.value * 0.06),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const CharacterAvatar(
                        title: UserTitle.warrior,
                        size: 160,
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 1200.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1, 1),
                        duration: 1200.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 48),

                  // Title with golden gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFE8C87A),
                        Color(0xFFD4A853),
                        Color(0xFFF0D78C),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      'No Enemies',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            letterSpacing: 2,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 800.ms),

                  const SizedBox(height: 16),

                  // Tagline — connects to the cinematic
                  Text(
                    "You've been fighting\nlong enough.",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                          letterSpacing: 0.5,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 700.ms, duration: 800.ms),

                  const SizedBox(height: 24),

                  // Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      'Every enemy you perceive is a reflection of a war inside you. '
                      'End the inner war, and you have no enemies.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.7,
                            fontStyle: FontStyle.italic,
                          ),
                      textAlign: TextAlign.left,
                    ),
                  ).animate().fadeIn(delay: 1000.ms, duration: 800.ms).slideX(
                        begin: -0.05,
                        end: 0,
                        delay: 1000.ms,
                        duration: 800.ms,
                      ),

                  const Spacer(flex: 3),

                  // Begin button — significant, weighty
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
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => context.go('/quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Begin Your Journey',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1400.ms, duration: 600.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        delay: 1400.ms,
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  const SizedBox(height: 16),

                  // Subtitle under button
                  Text(
                    'A 2-minute journey to understand your inner conflict',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 1700.ms, duration: 400.ms),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
