import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/peace_letter.dart';
import '../../providers/peace_letters_provider.dart';
import '../../theme/app_colors.dart';

class WritePeaceLetterScreen extends StatefulWidget {
  const WritePeaceLetterScreen({super.key});

  @override
  State<WritePeaceLetterScreen> createState() => _WritePeaceLetterScreenState();
}

class _WritePeaceLetterScreenState extends State<WritePeaceLetterScreen> {
  final _controller = TextEditingController();
  PeaceRecipientArchetype _recipient = PeaceRecipientArchetype.enemyInMyHead;
  PeaceIntent _intent = PeaceIntent.needToBeHeard;
  final Set<PeaceTheme> _themes = {PeaceTheme.resentment};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({required bool seal}) async {
    final text = _controller.text.trim();
    if (text.length < 24) {
      _showSnack('Write a little more before sealing this letter.');
      return;
    }
    HapticFeedback.mediumImpact();
    final provider = context.read<PeaceLettersProvider>();
    final draft = await provider.saveDraft(
      rawText: text,
      recipientArchetype: _recipient,
      intent: _intent,
      themes: _themes.toList(),
    );
    if (!mounted) return;
    if (draft == null) {
      _showSnack(provider.lastError ?? 'Could not save this letter.');
      return;
    }
    if (seal) {
      final sealed = await provider.sealPrivately(draft);
      if (!mounted) return;
      if (sealed == null) {
        _showSnack(provider.lastError ?? 'Could not seal this letter.');
        return;
      }
      _showSnack(
        'Letter sealed privately. It is yours to keep, revisit, or release.',
      );
    } else {
      _showSnack('Draft saved privately.');
    }
    context.go('/crew');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<PeaceLettersProvider>().isSaving;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.75),
                  radius: 1.25,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.04),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(onClose: () => context.pop()),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WRITE THE WAR DOWN',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                              ),
                        ).animate().fadeIn(duration: 280.ms),
                        const SizedBox(height: 8),
                        Text(
                          'Begin with the messy truth.',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppColors.textPrimary,
                            fontSize: 38,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ).animate().fadeIn(delay: 80.ms, duration: 320.ms),
                        const SizedBox(height: 10),
                        Text(
                          'This draft stays private. Next, Peace Alchemy can help soften and rewrite it for your own Book of Peace.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel('Who is this letter to?'),
                        const SizedBox(height: 10),
                        _RecipientPicker(
                          selected: _recipient,
                          onChanged: (value) =>
                              setState(() => _recipient = value),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel('What do you need?'),
                        const SizedBox(height: 10),
                        _IntentPicker(
                          selected: _intent,
                          onChanged: (value) => setState(() => _intent = value),
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel('What is it carrying?'),
                        const SizedBox(height: 10),
                        _ThemePicker(
                          selected: _themes,
                          onToggle: (theme) {
                            setState(() {
                              if (_themes.contains(theme)) {
                                if (_themes.length > 1) _themes.remove(theme);
                              } else {
                                _themes.add(theme);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel('The raw letter'),
                        const SizedBox(height: 10),
                        _LetterEditor(
                          controller: _controller,
                          recipient: _recipient,
                        ),
                        const SizedBox(height: 18),
                        const _PeerSupportNotice(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActions(
              isSaving: isSaving,
              bottomPadding: bottom,
              onSaveDraft: () => _save(seal: false),
              onSeal: () => _save(seal: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            'Peace Letter',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 2.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RecipientPicker extends StatelessWidget {
  const _RecipientPicker({required this.selected, required this.onChanged});

  final PeaceRecipientArchetype selected;
  final ValueChanged<PeaceRecipientArchetype> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PeaceRecipientArchetype.values.map((value) {
        final isSelected = value == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SelectableTile(
            selected: isSelected,
            title: value.label,
            subtitle: value.prompt,
            icon: _recipientIcon(value),
            onTap: () => onChanged(value),
          ),
        );
      }).toList(),
    );
  }

  IconData _recipientIcon(PeaceRecipientArchetype value) {
    switch (value) {
      case PeaceRecipientArchetype.someoneICantForgive:
        return Icons.bolt_outlined;
      case PeaceRecipientArchetype.versionOfMeIHate:
        return Icons.broken_image_outlined;
      case PeaceRecipientArchetype.personIMiss:
        return Icons.nights_stay_outlined;
      case PeaceRecipientArchetype.enemyInMyHead:
        return Icons.psychology_alt_outlined;
      case PeaceRecipientArchetype.anyoneWhoUnderstands:
        return Icons.public_outlined;
    }
  }
}

class _IntentPicker extends StatelessWidget {
  const _IntentPicker({required this.selected, required this.onChanged});

  final PeaceIntent selected;
  final ValueChanged<PeaceIntent> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PeaceIntent.values.map((intent) {
        final isSelected = intent == selected;
        return _ChoiceChip(
          label: intent.label,
          selected: isSelected,
          onTap: () => onChanged(intent),
        );
      }).toList(),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onToggle});

  final Set<PeaceTheme> selected;
  final ValueChanged<PeaceTheme> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PeaceTheme.values.map((theme) {
        return _ChoiceChip(
          label: theme.label,
          selected: selected.contains(theme),
          onTap: () => onToggle(theme),
        );
      }).toList(),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.06 : 0.032),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.26 : 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.36)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterEditor extends StatelessWidget {
  const _LetterEditor({required this.controller, required this.recipient});

  final TextEditingController controller;
  final PeaceRecipientArchetype recipient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 260),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 18,
            cursorColor: AppColors.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.55,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '${recipient.label},\n\nI have been carrying...',
              hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textTertiary.withValues(alpha: 0.55),
                height: 1.55,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeerSupportNotice extends StatelessWidget {
  const _PeerSupportNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Do not include names, addresses, handles, or contact details. Peace Letters is peer witness, not therapy or emergency support.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isSaving,
    required this.bottomPadding,
    required this.onSaveDraft,
    required this.onSeal,
  });

  final bool isSaving;
  final double bottomPadding;
  final VoidCallback onSaveDraft;
  final VoidCallback onSeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.92),
            Colors.black,
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : onSaveDraft,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save Draft'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isSaving ? null : AppColors.primaryGradient,
                color: isSaving ? AppColors.surfaceLight : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: isSaving ? null : onSeal,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  disabledForegroundColor: AppColors.textTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Seal Privately',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
