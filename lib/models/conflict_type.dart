import 'package:flutter/material.dart';

enum ConflictType {
  resentment,
  selfHatred,
  comparison,
  workplace,
  relationship,
  identity,
  grief,
  addiction;

  String get displayName {
    switch (this) {
      case ConflictType.resentment:
        return 'Resentment';
      case ConflictType.selfHatred:
        return 'Self-Criticism';
      case ConflictType.comparison:
        return 'Comparison';
      case ConflictType.workplace:
        return 'Workplace Conflict';
      case ConflictType.relationship:
        return 'Relationship Conflict';
      case ConflictType.identity:
        return 'Identity Conflict';
      case ConflictType.grief:
        return 'Grief & Loss';
      case ConflictType.addiction:
        return 'Addiction Recovery';
    }
  }

  String get description {
    switch (this) {
      case ConflictType.resentment:
        return 'You carry grudges like armour. Old wounds from parents, '
            'exes, or friends haven\'t healed — they\'ve hardened. '
            'The war inside you is against people who may have already moved on.';
      case ConflictType.selfHatred:
        return 'Your harshest enemy is the one in the mirror. Past mistakes '
            'replay on loop, and forgiveness feels like something you give '
            'others but never yourself.';
      case ConflictType.comparison:
        return 'You see everyone else as competition. Their wins feel like '
            'your losses. The war inside you turns allies into rivals and '
            'joy into jealousy.';
      case ConflictType.workplace:
        return 'Toxic environments have made you combative. You bring the '
            'battlefield energy home. The war at work has become a war '
            'inside you.';
      case ConflictType.relationship:
        return 'The people closest to you trigger the deepest pain. '
            'Love and conflict are tangled together, and you\'re exhausted '
            'from fighting the ones you care about most.';
      case ConflictType.identity:
        return 'You\'re at war with who you are versus who you think you '
            'should be. The gap between your real self and your ideal self '
            'is a battlefield.';
      case ConflictType.grief:
        return 'Loss has left you angry at the unfairness of it all. '
            'The war inside you is against a world that took something '
            'precious and offered no explanation.';
      case ConflictType.addiction:
        return 'The battle with yourself is literal. Every day is a fight '
            'between who you want to be and the patterns that pull you back. '
            'The enemy lives inside you.';
    }
  }

  String get emoji {
    switch (this) {
      case ConflictType.resentment:
        return '🔥';
      case ConflictType.selfHatred:
        return '🪞';
      case ConflictType.comparison:
        return '⚖️';
      case ConflictType.workplace:
        return '🏢';
      case ConflictType.relationship:
        return '💔';
      case ConflictType.identity:
        return '🎭';
      case ConflictType.grief:
        return '🌑';
      case ConflictType.addiction:
        return '⛓️';
    }
  }

  IconData get icon {
    switch (this) {
      case ConflictType.resentment:
        return Icons.local_fire_department_outlined;
      case ConflictType.selfHatred:
        return Icons.person_outline;
      case ConflictType.comparison:
        return Icons.balance_outlined;
      case ConflictType.workplace:
        return Icons.business_outlined;
      case ConflictType.relationship:
        return Icons.favorite_border;
      case ConflictType.identity:
        return Icons.masks_outlined;
      case ConflictType.grief:
        return Icons.nights_stay_outlined;
      case ConflictType.addiction:
        return Icons.link_outlined;
    }
  }

  /// Path to the hand-painted Norse rune asset for this conflict type.
  String get runeAsset {
    switch (this) {
      case ConflictType.resentment:
        return 'assets/images/runes/rune_resentment.png';
      case ConflictType.selfHatred:
        return 'assets/images/runes/rune_selfHatred.png';
      case ConflictType.comparison:
        return 'assets/images/runes/rune_comparison.png';
      case ConflictType.workplace:
        return 'assets/images/runes/rune_workplace.png';
      case ConflictType.relationship:
        return 'assets/images/runes/rune_relationship.png';
      case ConflictType.identity:
        return 'assets/images/runes/rune_identity.png';
      case ConflictType.grief:
        return 'assets/images/runes/rune_grief.png';
      case ConflictType.addiction:
        return 'assets/images/runes/rune_addiction.png';
    }
  }

  String get journeyMessage {
    switch (this) {
      case ConflictType.resentment:
        return 'Your journey is about releasing the weight of old wounds '
            'and discovering that forgiveness is freedom, not surrender.';
      case ConflictType.selfHatred:
        return 'Your journey is about turning the critical voice inside '
            'you into a compassionate one. You deserve the kindness you '
            'give others.';
      case ConflictType.comparison:
        return 'Your journey is about finding your own path instead of '
            'measuring it against everyone else\'s. Your story is yours alone.';
      case ConflictType.workplace:
        return 'Your journey is about separating who you are from what '
            'happens at work, and finding peace that no job can take away.';
      case ConflictType.relationship:
        return 'Your journey is about learning that love doesn\'t have to '
            'be a battleground. Peace starts with how you relate to yourself.';
      case ConflictType.identity:
        return 'Your journey is about accepting the wholeness of who you '
            'are — not the perfect version, but the real one.';
      case ConflictType.grief:
        return 'Your journey is about transforming anger into acceptance, '
            'without forgetting what you\'ve lost.';
      case ConflictType.addiction:
        return 'Your journey is about making peace with the parts of '
            'yourself you\'ve been at war with. You are not your patterns.';
    }
  }
}
