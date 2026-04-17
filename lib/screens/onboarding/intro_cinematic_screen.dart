import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';
import '../../widgets/shader_transition.dart';

/// A cinematic intro sequence with anime artwork backgrounds.
/// Inspired by Vinland Saga's philosophy of ending inner conflict.
/// Only plays once — first launch.
class IntroCinematicScreen extends StatefulWidget {
  const IntroCinematicScreen({super.key});

  /// Check if the cinematic has been seen before.
  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('intro_cinematic_seen') ?? false;
  }

  /// Mark the cinematic as seen.
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_cinematic_seen', true);
  }

  /// Reset so the cinematic plays again (debug).
  static Future<void> resetSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_cinematic_seen', false);
  }

  @override
  State<IntroCinematicScreen> createState() => _IntroCinematicScreenState();
}

class _IntroCinematicScreenState extends State<IntroCinematicScreen>
    with TickerProviderStateMixin {
  static const _sceneImages = [
    'assets/images/intro/intro_battlefield.png',
    'assets/images/intro/intro_walking_away.png',
    'assets/images/intro/intro_shore.png', // "end the war within"
    'assets/images/intro/intro_peace_face.png', // "choosing peace"
    'assets/images/intro/intro_title_art.png',
  ];

  // Scene timings in milliseconds
  static const _sceneDurations = [5000, 5000, 5000, 5000, 5000];

  int _currentScene = -1; // -1 = black, waiting to start
  bool _showSkip = false;
  bool _isFinishing = false;
  bool _shaderReady = false;

  // Text state
  double _textOpacity = 0.0;
  String _currentText = '';
  // Title scene state (scene 4)
  bool _showTitle = false;
  bool _showBeginButton = false;

  // Particles
  bool _showParticles = false;

  // Ken Burns zoom controllers per scene
  late final List<AnimationController> _zoomControllers;
  late final List<Animation<double>> _zoomAnimations;

  // Dissolve transition controller — drives the shader progress 0..1
  late AnimationController _dissolveController;
  int _prevScene = -1;

  late AnimationController _screenFadeController;

  @override
  void initState() {
    super.initState();

    _zoomControllers = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        // Zoom runs longer than the scene so it's still moving during dissolve
        duration: Duration(milliseconds: _sceneDurations[i] + 3000),
      );
    });

    _zoomAnimations = List.generate(5, (i) {
      return Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(
          parent: _zoomControllers[i],
          curve: Curves.easeOut,
        ),
      );
    });

    // Dissolve transition runs over 1.4s with an ease-in-out curve
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _screenFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Load the GLSL dissolve shader
    DissolveShaderCache.load().then((_) {
      if (mounted) setState(() => _shaderReady = true);
    });

    // Show skip button after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSkip = true);
    });

    // Precache images then start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages().then((_) {
        if (mounted) _startSequence();
      });
    });
  }

  Future<void> _precacheImages() async {
    for (final path in _sceneImages) {
      if (!mounted) return;
      await precacheImage(AssetImage(path), context);
    }
  }

  Future<void> _transitionToScene(int scene) async {
    if (!mounted || _isFinishing) return;
    _prevScene = _currentScene;

    // Reset dissolve controller for a fresh transition
    _dissolveController.value = 0.0;

    setState(() {
      _currentScene = scene;
      _textOpacity = 0.0;
      _currentText = '';
    });

    // Start the dissolve transition (outgoing scene dissolves away)
    _dissolveController.forward(from: 0.0);
    // Start Ken Burns zoom on the incoming scene
    _zoomControllers[scene].forward(from: 0.0);

    // Wait for dissolve to mostly complete before showing text
    await Future.delayed(const Duration(milliseconds: 900));
  }

  // Letter-spacing is driven by the current scene's zoom controller
  // so it expands slowly over the entire scene, synced to Ken Burns.
  static const _lsStart = 0.0;
  static const _lsEnd = 1.8;

  double get _animatedLetterSpacing {
    if (_currentScene < 0 || _currentScene >= _zoomControllers.length) {
      return _lsStart;
    }
    final t = _zoomControllers[_currentScene].value;
    return _lsStart + (_lsEnd - _lsStart) * t;
  }

  Future<void> _fadeInText(String text, {int durationMs = 800}) async {
    if (!mounted || _isFinishing) return;
    setState(() {
      _currentText = text;
      _textOpacity = 0.0;
    });
    const steps = 20;
    final stepDur = Duration(milliseconds: durationMs ~/ steps);
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(stepDur);
      if (!mounted || _isFinishing) return;
      setState(() => _textOpacity = i / steps);
    }
  }

  Future<void> _fadeOutText({int durationMs = 600}) async {
    if (!mounted || _isFinishing) return;
    const steps = 15;
    final stepDur = Duration(milliseconds: durationMs ~/ steps);
    for (var i = steps; i >= 0; i--) {
      await Future.delayed(stepDur);
      if (!mounted || _isFinishing) return;
      setState(() => _textOpacity = i / steps);
    }
    setState(() => _currentText = '');
  }

  Future<void> _startSequence() async {
    // --- Scene 0: Battlefield ---
    await _transitionToScene(0);
    if (!mounted || _isFinishing) return;
    await _fadeInText('Every warrior believes\nthe war is outside.');
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _isFinishing) return;
    await _fadeOutText();

    // --- Scene 1: Walking Away ---
    await _transitionToScene(1);
    if (!mounted || _isFinishing) return;
    await _fadeInText('But the real battlefield\nwas always within.');
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _isFinishing) return;
    await _fadeOutText();

    // --- Scene 2: Shore — "End the war within" ---
    await _transitionToScene(2);
    if (!mounted || _isFinishing) return;
    await _fadeInText('What if you could\nend the war within?');
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted || _isFinishing) return;
    await _fadeOutText();

    // --- Scene 3: Peace Face — "Choosing peace" ---
    await _transitionToScene(3);
    if (!mounted || _isFinishing) return;
    await _fadeInText('Not by winning.\nBy choosing peace.');
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted || _isFinishing) return;
    await _fadeOutText();

    // Show particles before title
    setState(() => _showParticles = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _isFinishing) return;

    // --- Scene 4: Title Art ---
    await _transitionToScene(4);
    if (!mounted || _isFinishing) return;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isFinishing) return;

    // Show all title elements together for smooth entrance
    setState(() {
      _showTitle = true;
      _showBeginButton = true;
    });

    // Wait indefinitely for user to tap Begin
    // (auto-advance disabled on final scene)
  }

  Future<void> _finishSequence() async {
    if (_isFinishing) return;
    _isFinishing = true;

    await IntroCinematicScreen.markAsSeen();

    _screenFadeController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      context.go('/onboarding');
    }
  }

  void _skip() {
    _finishSequence();
  }

  @override
  void dispose() {
    for (final c in _zoomControllers) {
      c.dispose();
    }
    _dissolveController.dispose();
    _screenFadeController.dispose();
    super.dispose();
  }

  Widget _buildSceneImage(int sceneIndex) {
    if (sceneIndex < 0 || sceneIndex >= _sceneImages.length) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: _zoomControllers[sceneIndex],
      builder: (context, child) {
        return Transform.scale(
          scale: _zoomAnimations[sceneIndex].value,
          child: child,
        );
      },
      child: Image.asset(
        _sceneImages[sceneIndex],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 600,
      ),
    );
  }

  /// Per-scene text vertical alignment based on CEO's red-box annotations.
  /// Alignment.y: -1 = top, 0 = center, 1 = bottom
  Alignment _textAlignmentForScene(int scene) {
    switch (scene) {
      case 0: return const Alignment(0, -0.45); // Battlefield: upper area (sky/smoke above warrior)
      case 1: return const Alignment(0, -0.25); // Walking away: upper area (dark silhouette zone)
      case 2: return const Alignment(0, -0.15); // Shore: above center (between moon & figure)
      case 3: return const Alignment(0, 0.35);  // Peace face: LOWER (chest/cloak area below chin)
      default: return Alignment.center;
    }
  }

  Widget _buildVignette() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.2),
              Colors.black.withValues(alpha: 0.6),
            ],
            stops: const [0.3, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _screenFadeController,
        builder: (context, child) {
          return Opacity(
            opacity: 1.0 - _screenFadeController.value,
            child: child,
          );
        },
        child: Stack(
          children: [
            // --- Background images with shader dissolve transition ---
            AnimatedBuilder(
              animation: _dissolveController,
              builder: (context, _) {
                final progress = CurvedAnimation(
                  parent: _dissolveController,
                  curve: Curves.easeInOut,
                ).value;

                // If no previous scene, just show the current one fading in.
                if (_prevScene < 0 && _currentScene >= 0) {
                  return Positioned.fill(
                    child: Opacity(
                      opacity: progress,
                      child: _buildSceneImage(_currentScene),
                    ),
                  );
                }

                if (_currentScene < 0) {
                  return const SizedBox.expand();
                }

                // Use the shader dissolve when the shader is ready,
                // otherwise fall back to a simple crossfade.
                if (_shaderReady) {
                  return Positioned.fill(
                    child: _ShaderDissolveStack(
                      progress: progress,
                      outgoing: _buildSceneImage(_prevScene),
                      incoming: _buildSceneImage(_currentScene),
                    ),
                  );
                }

                // Fallback: simple crossfade
                return Stack(
                  children: [
                    Positioned.fill(
                      child: _buildSceneImage(_prevScene),
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: progress,
                        child: _buildSceneImage(_currentScene),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Vignette overlay
            if (_currentScene >= 0) Positioned.fill(child: _buildVignette()),

            // Ambient particles (appear from scene 3 onwards)
            if (_showParticles)
              Positioned.fill(
                child: AmbientParticles(
                  particleCount: 40,
                  color: AppColors.primary,
                  opacity: 0.4,
                  maxParticleSize: 3.0,
                  minParticleSize: 1.0,
                ).animate().fadeIn(duration: 1500.ms),
              ),

            // --- Scene text (scenes 0-3) with per-scene positioning ---
            if (_currentText.isNotEmpty && !_showTitle && _currentScene >= 0)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _zoomControllers[_currentScene.clamp(0, 4)],
                  builder: (context, _) {
                    return Align(
                      alignment: _textAlignmentForScene(_currentScene),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Opacity(
                          opacity: _textOpacity,
                          child: Text(
                            _currentText,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary.withValues(alpha: 0.95),
                              height: 1.5,
                              letterSpacing: _animatedLetterSpacing,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 20,
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
                  },
                ),
              ),

            // --- Title scene: Logo + Subtitle (centered) ---
            if (_showTitle)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stylized "NO ENEMIES" logo image
                      Image.asset(
                        'assets/images/ui/title_logo.png',
                        width: 320,
                        cacheWidth: 640,
                      ),

                      const SizedBox(height: 20),

                      // Subtitle
                      Text(
                        "Learn to let go. Find peace.",
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary.withValues(alpha: 0.85),
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 1200.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    duration: 1200.ms,
                    curve: Curves.easeOutCubic,
                  ),

            // --- Begin button (pinned to bottom) ---
            if (_showBeginButton)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 60,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFD4A853),
                            Color(0xFFE8C87A),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _finishSequence,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Begin',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: 800.ms,
                    delay: 600.ms,
                    curve: Curves.easeOut,
                  )
                  .slideY(
                    begin: 0.3,
                    end: 0,
                    duration: 800.ms,
                    delay: 600.ms,
                    curve: Curves.easeOutCubic,
                  ),

            // Debug screen picker (dev only)
            if (kDebugMode && _showSkip && !_isFinishing)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                child: GestureDetector(
                  onTap: () => GoRouter.of(context).go('/debug'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bug_report_rounded,
                            size: 14,
                            color: AppColors.accent.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Debug',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms),
              ),

            // Skip button
            if (_showSkip && !_isFinishing)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms),
              ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget that composes the shader dissolve layers.
///
/// Stack order:
///   1. Incoming scene (bottom) — fades in with standard opacity
///   2. Outgoing scene (top) — masked by the dissolve shader so it
///      "burns away" with an amber glow edge, revealing the incoming scene
class _ShaderDissolveStack extends StatelessWidget {
  const _ShaderDissolveStack({
    required this.progress,
    required this.outgoing,
    required this.incoming,
  });

  final double progress;
  final Widget outgoing;
  final Widget incoming;

  @override
  Widget build(BuildContext context) {
    return DissolveTransition(
      progress: progress,
      outgoingChild: outgoing,
      incomingChild: incoming,
    );
  }
}
