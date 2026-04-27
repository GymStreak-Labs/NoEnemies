import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/peace_letter.dart';
import '../../providers/peace_exchange_provider.dart';
import '../../theme/app_colors.dart';

class PeaceLetterDetailScreen extends StatelessWidget {
  const PeaceLetterDetailScreen({super.key, required this.letterId});

  final String letterId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PeaceExchangeProvider>();
    final letter = provider.letterById(letterId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: letter == null
            ? _MissingLetter(onBack: () => context.go('/crew'))
            : _LetterDetail(letter: letter),
      ),
    );
  }
}

class _MissingLetter extends StatelessWidget {
  const _MissingLetter({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mail_outline,
              color: AppColors.textTertiary,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              'Letter not found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text('Back to Peace Exchange'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterDetail extends StatelessWidget {
  const _LetterDetail({required this.letter});

  final PeaceLetter letter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PeaceExchangeProvider>();
    final isDraft = letter.status == PeaceLetterStatus.draft;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.75),
                radius: 1.35,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(status: letter.status),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      letter.recipientArchetype.label,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        height: 1.02,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 10),
                    Text(
                      letter.intent.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: letter.themes
                          .map((theme) => _ThemeChip(label: theme.label))
                          .toList(),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.045),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        letter.publicText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.7,
                        ),
                      ),
                    ),
                    if (letter.moderationNote != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        letter.moderationNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          await provider.deleteLetter(letter.id);
                          if (context.mounted) context.go('/crew');
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.war,
                    side: BorderSide(
                      color: AppColors.war.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              if (isDraft) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: provider.isSaving
                        ? null
                        : () async {
                            await provider.sealPrivately(letter);
                            if (context.mounted) context.go('/crew');
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Seal Privately',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
