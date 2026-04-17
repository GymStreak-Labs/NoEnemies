import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A reduced 3-value emotion summary derived from recent check-ins, used to
/// drive how the character portrait is lit (aura colour, breath speed, glow
/// intensity). We intentionally fold the 5 raw [Mood] values into 3 so the
/// visual treatment stays readable at a glance.
enum CurrentEmotion {
  /// The user is at peace. Green/teal aura, slow gentle breathing.
  joyful,

  /// Default state — character sits in their stage colour, no mood overlay.
  calm,

  /// The user is struggling. Muted red/amber aura, slightly faster breath,
  /// heavier vignette.
  troubled;

  /// Human-readable label, used in debug overlays / "You" tab captions.
  String get label {
    switch (this) {
      case CurrentEmotion.joyful:
        return 'At peace';
      case CurrentEmotion.calm:
        return 'Steady';
      case CurrentEmotion.troubled:
        return 'Struggling';
    }
  }

  /// Aura tint to blend with the user's stage colour.
  Color get auraColor {
    switch (this) {
      case CurrentEmotion.joyful:
        return AppColors.peace;
      case CurrentEmotion.calm:
        return AppColors.primary;
      case CurrentEmotion.troubled:
        return AppColors.war;
    }
  }

  /// Breath cycle duration. Troubled = faster (tenser), joyful = slower (eased).
  Duration get breathDuration {
    switch (this) {
      case CurrentEmotion.joyful:
        return const Duration(milliseconds: 5000);
      case CurrentEmotion.calm:
        return const Duration(milliseconds: 4000);
      case CurrentEmotion.troubled:
        return const Duration(milliseconds: 2800);
    }
  }

  /// Extra aura opacity on top of the base stage glow. Joyful = more luminous,
  /// troubled = dimmer but warmer.
  double get auraIntensity {
    switch (this) {
      case CurrentEmotion.joyful:
        return 0.35;
      case CurrentEmotion.calm:
        return 0.0;
      case CurrentEmotion.troubled:
        return 0.22;
    }
  }
}
