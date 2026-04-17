import 'package:flutter/material.dart';
import '../models/current_emotion.dart';

/// Wraps a character portrait in an aura that reflects the user's current
/// emotion. The aura is a soft radial glow behind the child plus a subtle
/// breath animation that speeds up when troubled and slows when joyful.
///
/// This is the single source of truth for "the character reacts to mood" —
/// both the Journey tab and the You tab should render the portrait through
/// this widget so the visual language stays consistent.
class EmotionAura extends StatefulWidget {
  /// The portrait to composite (typically an `Image.asset(...)`).
  final Widget child;

  /// The emotion driving aura colour, intensity and breath pace.
  final CurrentEmotion emotion;

  /// Base aura color to blend with the emotion tint — usually the user's
  /// stage color. If null, the aura uses only the emotion color.
  final Color? baseColor;

  /// Diameter of the aura glow.
  final double auraSize;

  /// How strongly the child animates (0.0 = static, 1.0 = full breath).
  /// Useful for disabling breath on small avatars.
  final double breathAmount;

  /// Optional alignment override for the inner scale/translate transform.
  /// Defaults to [Alignment.bottomCenter] so the character appears to rise
  /// and settle rather than inflate from the middle.
  final Alignment breathAlignment;

  const EmotionAura({
    super.key,
    required this.child,
    required this.emotion,
    this.baseColor,
    this.auraSize = 280,
    this.breathAmount = 1.0,
    this.breathAlignment = Alignment.bottomCenter,
  });

  @override
  State<EmotionAura> createState() => _EmotionAuraState();
}

class _EmotionAuraState extends State<EmotionAura>
    with SingleTickerProviderStateMixin {
  late AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: widget.emotion.breathDuration,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant EmotionAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion.breathDuration != widget.emotion.breathDuration) {
      _breath.duration = widget.emotion.breathDuration;
      _breath
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Color get _blendedColor {
    final base = widget.baseColor ?? widget.emotion.auraColor;
    // Troubled emotion overrides more heavily so it reads clearly;
    // calm leaves the stage color mostly intact.
    switch (widget.emotion) {
      case CurrentEmotion.joyful:
        return Color.lerp(base, widget.emotion.auraColor, 0.45) ?? base;
      case CurrentEmotion.calm:
        return base;
      case CurrentEmotion.troubled:
        return Color.lerp(base, widget.emotion.auraColor, 0.55) ?? base;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_breath.value);
        final pulse = 0.5 + (t * 0.5); // 0.5..1.0
        final color = _blendedColor;
        final intensity = widget.emotion.auraIntensity;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer halo — only visible for joyful/troubled states
            if (intensity > 0)
              IgnorePointer(
                child: Container(
                  width: widget.auraSize + (pulse * 24),
                  height: widget.auraSize + (pulse * 24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: intensity * (0.7 + pulse * 0.3)),
                        color.withValues(alpha: intensity * 0.25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

            // Breathing portrait
            Transform.translate(
              offset: Offset(0, -2.0 + (t * 4.0) * widget.breathAmount),
              child: Transform.scale(
                scale: 1.0 + (t * 0.02 * widget.breathAmount),
                alignment: widget.breathAlignment,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
