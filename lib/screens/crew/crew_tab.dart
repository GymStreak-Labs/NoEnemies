import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/peace_letter.dart';
import '../../providers/peace_letters_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

class CrewTab extends StatelessWidget {
  const CrewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final peace = context.watch<PeaceLettersProvider>();
    final drafts = peace.drafts;
    final sealed = peace.sealedLetters;
    final totalWords = peace.letters.fold<int>(
      0,
      (sum, letter) => sum + letter.wordCount,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.78),
                  radius: 1.25,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.04),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 12,
              color: AppColors.primary,
              opacity: 0.14,
              maxParticleSize: 2,
              minParticleSize: 0.4,
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(context),
                      const SizedBox(height: 18),
                      _HeroCard(
                            draftsCount: drafts.length,
                            sealedCount: sealed.length,
                            totalWords: totalWords,
                          )
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 420.ms)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            delay: 120.ms,
                            duration: 420.ms,
                          ),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Private Rituals',
                        subtitle:
                            'A launch-safe way to write, seal, and return to what you carried.',
                      ),
                      const SizedBox(height: 12),
                      const _ActionGrid(),
                      const SizedBox(height: 26),
                      _SectionTitle(
                        title: 'Your Letters',
                        subtitle: drafts.isEmpty && sealed.isEmpty
                            ? 'Start with one truth you no longer want to carry alone.'
                            : 'Drafts and sealed letters are private to you.',
                      ),
                      const SizedBox(height: 12),
                      if (drafts.isEmpty && sealed.isEmpty)
                        const _EmptyLettersCard()
                      else ...[
                        ...drafts.map((letter) => _LetterPreviewCard(letter)),
                        ...sealed.map((letter) => _LetterPreviewCard(letter)),
                      ],
                      const SizedBox(height: 28),
                      const _SafetyCard(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PEACE LETTERS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn(duration: 280.ms),
        const SizedBox(height: 8),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'Lay the war down',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 42,
              height: 0.96,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ).animate().fadeIn(delay: 80.ms, duration: 360.ms),
        const SizedBox(height: 8),
        Text(
          'A private letter ritual for anger, grief, guilt, shame, and the arguments you keep having inside.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ).animate().fadeIn(delay: 140.ms, duration: 360.ms),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.draftsCount,
    required this.sealedCount,
    required this.totalWords,
  });

  final int draftsCount;
  final int sealedCount;
  final int totalWords;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.34),
                          AppColors.primary.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.mail_lock_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'What part of the war are you ready to lay down?',
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Write it raw. Seal it privately. Return when you are ready to soften, save, or release it. No strangers, no feed, no social pressure.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(value: '$draftsCount', label: 'Drafts'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(value: '$sealedCount', label: 'Sealed'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(value: '$totalWords', label: 'Words'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push('/peace/write'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            'Write a Peace Letter',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                ),
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
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cormorantGaramond(
              color: AppColors.primary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.edit_note_rounded,
                title: 'Write',
                subtitle: 'Start with the messy truth.',
                active: true,
                onTap: () => context.push('/peace/write'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.auto_fix_high_rounded,
                title: 'Soften',
                subtitle: 'AI rewrite comes next.',
                active: false,
                onTap: () => _showSoon(
                  context,
                  'Peace Alchemy comes next: raw draft → softened letter.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Release',
                subtitle: 'Burn / sea ritual soon.',
                active: false,
                onTap: () => _showSoon(
                  context,
                  'The release ritual is queued after the private draft loop.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.auto_stories_outlined,
                title: 'Book',
                subtitle: 'Save wisdom privately.',
                active: false,
                onTap: () => context.push('/journal'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static void _showSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.055 : 0.032),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: active ? 0.24 : 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLettersCard extends StatelessWidget {
  const _EmptyLettersCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.032),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mail_lock_outlined,
            color: AppColors.primary.withValues(alpha: 0.86),
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            'No letters yet',
            style: GoogleFonts.cormorantGaramond(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is private. Begin with one argument, memory, or ache that keeps returning.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterPreviewCard extends StatelessWidget {
  const _LetterPreviewCard(this.letter);

  final PeaceLetter letter;

  @override
  Widget build(BuildContext context) {
    final isDraft = letter.status == PeaceLetterStatus.draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/peace/letter/${letter.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.036),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDraft ? AppColors.textTertiary : AppColors.primary)
                    .withValues(alpha: isDraft ? 0.08 : 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(status: letter.status),
                    const Spacer(),
                    Text(
                      '${letter.wordCount} words',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  letter.recipientArchetype.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  letter.displayText.isEmpty
                      ? letter.recipientArchetype.prompt
                      : letter.displayText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PeaceLetterStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == PeaceLetterStatus.draft
        ? AppColors.textTertiary
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Peace Letters is private reflection, not therapy or emergency support. If you may hurt yourself or someone else, contact local emergency services or a crisis line now.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
