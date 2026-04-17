import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_particles.dart';

/// Full-screen cinematic shown when the user unlocks a new title stage.
/// Sequence:
///   0.0s  — black, ambient sound (haptic)
///   0.5s  — old stage background fades in (the past)
///   1.5s  — old character portrait appears
///   3.0s  — light bursts (haptic)
///   3.5s  — old fades out, new background fades in
///   4.5s  — new character appears with golden burst (haptic)
///   6.0s  — title text reveals
///   7.5s  — quote/blessing appears
///   9.5s  — Continue button appears
class StageTransitionScreen extends StatefulWidget {
  final UserTitle previousStage;
  final UserTitle newStage;
  final VoidCallback onContinue;

  const StageTransitionScreen({
    super.key,
    required this.previousStage,
    required this.newStage,
    required this.onContinue,
  });

  @override
  State<StageTransitionScreen> createState() => _StageTransitionScreenState();
}

class _StageTransitionScreenState extends State<StageTransitionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9500),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Subtle haptic at start
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.lightImpact();

    _master.forward();

    // Mid-cinematic burst haptic
    await Future.delayed(const Duration(milliseconds: 3000));
    HapticFeedback.mediumImpact();

    // New stage reveal haptic
    await Future.delayed(const Duration(milliseconds: 1500));
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _master.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _bgFor(UserTitle t) {
    switch (t) {
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

  String _portraitFor(UserTitle t) {
    switch (t) {
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

  Color _colorFor(UserTitle t) {
    switch (t) {
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

  String _quoteFor(UserTitle t) {
    switch (t) {
      case UserTitle.warrior:
        return 'The journey begins with a single breath.';
      case UserTitle.wanderer:
        return 'You\'ve put down the sword. The path opens.';
      case UserTitle.seeker:
        return 'The horizon is yours. Sail toward peace.';
      case UserTitle.peacemaker:
        return 'You have arrived. There are no enemies here.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _master,
        builder: (context, _) {
          final t = _master.value;

          // Stage opacities
          final oldBgOpacity = _curve(t, 0.05, 0.16, 0.32, 0.42);
          final oldCharOpacity = _curve(t, 0.16, 0.22, 0.32, 0.40);
          final newBgOpacity = _curve(t, 0.36, 0.50, 1.0, 1.0);
          final newCharOpacity = _curve(t, 0.47, 0.60, 1.0, 1.0);
          final burstOpacity = _curve(t, 0.30, 0.36, 0.42, 0.55);
          final titleOpacity = _curve(t, 0.62, 0.72, 1.0, 1.0);
          final quoteOpacity = _curve(t, 0.78, 0.86, 1.0, 1.0);
          final ctaOpacity = _curve(t, 0.96, 1.0, 1.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Old stage background
              if (oldBgOpacity > 0)
                Opacity(
                  opacity: oldBgOpacity,
                  child: Image.asset(
                    _bgFor(widget.previousStage),
                    fit: BoxFit.cover,
                  ),
                ),

              // Old character
              if (oldCharOpacity > 0)
                Opacity(
                  opacity: oldCharOpacity,
                  child: Center(
                    child: Image.asset(
                      _portraitFor(widget.previousStage),
                      fit: BoxFit.fitHeight,
                      height: MediaQuery.of(context).size.height * 0.7,
                    ),
                  ),
                ),

              // White light burst (transition moment)
              if (burstOpacity > 0)
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.6 + burstOpacity * 0.8,
                      colors: [
                        Colors.white.withValues(alpha: burstOpacity * 0.95),
                        _colorFor(widget.newStage)
                            .withValues(alpha: burstOpacity * 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

              // New stage background
              if (newBgOpacity > 0)
                Opacity(
                  opacity: newBgOpacity,
                  child: Image.asset(
                    _bgFor(widget.newStage),
                    fit: BoxFit.cover,
                  ),
                ),

              // Particles over new stage
              if (newBgOpacity > 0.3)
                Opacity(
                  opacity: newBgOpacity,
                  child: AmbientParticles(
                    particleCount: 24,
                    color: _colorFor(widget.newStage),
                    opacity: 0.5,
                    maxParticleSize: 3.0,
                  ),
                ),

              // New character with rim glow
              if (newCharOpacity > 0)
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing aura
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          return Container(
                            width: 360 + _pulse.value * 40,
                            height: 360 + _pulse.value * 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _colorFor(widget.newStage).withValues(
                                      alpha:
                                          0.18 * newCharOpacity * (0.6 + _pulse.value * 0.4)),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Opacity(
                        opacity: newCharOpacity,
                        child: Image.asset(
                          _portraitFor(widget.newStage),
                          fit: BoxFit.fitHeight,
                          height: MediaQuery.of(context).size.height * 0.65,
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom gradient for text legibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xCC000000),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),

              // Title + quote + CTA
              Positioned(
                left: 32,
                right: 32,
                bottom: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Section label
                    Opacity(
                      opacity: titleOpacity,
                      child: Text(
                        'YOU HAVE BECOME',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Opacity(
                      opacity: titleOpacity,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            _colorFor(widget.newStage),
                            Color.lerp(_colorFor(widget.newStage),
                                Colors.white, 0.4)!,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'The ${widget.newStage.displayName}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: _colorFor(widget.newStage)
                                    .withValues(alpha: 0.5),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Quote
                    Opacity(
                      opacity: quoteOpacity,
                      child: Text(
                        _quoteFor(widget.newStage),
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 19,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Continue button
                    Opacity(
                      opacity: ctaOpacity,
                      child: GestureDetector(
                        onTap: ctaOpacity >= 1.0 ? widget.onContinue : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _colorFor(widget.newStage)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  color: _colorFor(widget.newStage),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Skip button (top right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: Opacity(
                  opacity: 0.4,
                  child: GestureDetector(
                    onTap: widget.onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Smooth opacity curve: 0 before [start], 1 between [riseEnd]→[fallStart], 0 after [end].
  double _curve(double t, double start, double riseEnd, double fallStart, double end) {
    if (t <= start) return 0;
    if (t < riseEnd) {
      final p = (t - start) / (riseEnd - start);
      return Curves.easeInOut.transform(p);
    }
    if (t <= fallStart) return 1;
    if (t < end) {
      final p = 1 - (t - fallStart) / (end - fallStart);
      return Curves.easeInOut.transform(p);
    }
    return 0;
  }
}
