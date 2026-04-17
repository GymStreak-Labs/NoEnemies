import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/check_in.dart';
import '../../providers/user_provider.dart';
import '../../providers/journey_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mood_selector.dart';
import '../../widgets/dimension_slider.dart';

class EveningReflectionScreen extends StatefulWidget {
  const EveningReflectionScreen({super.key});

  @override
  State<EveningReflectionScreen> createState() =>
      _EveningReflectionScreenState();
}

class _EveningReflectionScreenState extends State<EveningReflectionScreen> {
  final _reflectionController = TextEditingController();
  Mood? _selectedMood;
  int _step = 0; // 0 = mood, 1 = question, 2 = dimensions, 3 = summary
  String? _question;
  bool _loadingQuestion = false;

  // Dimension values
  double _peace = 0.5;
  double _selfCompassion = 0.5;
  double _forgiveness = 0.5;
  double _presence = 0.5;

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _onMoodSelected(Mood mood) {
    setState(() {
      _selectedMood = mood;
      _step = 1;
      _loadingQuestion = true;
      _question = null;
    });

    () async {
      final userProvider = context.read<UserProvider>();
      final journeyProvider = context.read<JourneyProvider>();
      final profile = userProvider.profile;
      if (profile == null) return;
      // Try to pass today's morning check-in as context so the question
      // references the user's intention.
      final now = DateTime.now();
      final todayMorning = userProvider.checkIns
          .cast<CheckIn?>()
          .firstWhere(
            (c) =>
                c != null &&
                c.type == CheckInType.morning &&
                c.date.year == now.year &&
                c.date.month == now.month &&
                c.date.day == now.day,
            orElse: () => null,
          );
      try {
        final question = await journeyProvider.generateEveningQuestion(
          profile: profile,
          todayMorning: todayMorning,
          context: userProvider.aiContext,
        );
        if (!mounted) return;
        setState(() {
          _question = question;
          _loadingQuestion = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _question =
              journeyProvider.getEveningQuestion(profile.primaryConflict);
          _loadingQuestion = false;
        });
      }
    }();
  }

  void _proceedToDimensions() {
    setState(() => _step = 2);
  }

  Future<void> _complete() async {
    if (_selectedMood == null) return;

    final dimensions = [
      DimensionRating(name: 'Peace', value: _peace),
      DimensionRating(name: 'Self-Compassion', value: _selfCompassion),
      DimensionRating(name: 'Forgiveness', value: _forgiveness),
      DimensionRating(name: 'Presence', value: _presence),
    ];

    HapticFeedback.mediumImpact();
    final userProvider = context.read<UserProvider>();
    await userProvider.recordEveningReflection(
      mood: _selectedMood!,
      reflectionAnswer: _reflectionController.text.trim(),
      dimensions: dimensions,
    );

    if (mounted) {
      HapticFeedback.lightImpact();
      setState(() => _step = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 3) {
      return _CompletionView(onDone: () => context.pop());
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Evening Reflection'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Step 1: Mood
              MoodSelector(
                selectedMood: _selectedMood,
                onMoodSelected: _onMoodSelected,
              ),

              // Step 2: Guided question (may be loading)
              if (_step >= 1) ...[
                const SizedBox(height: 32),
                if (_loadingQuestion || _question == null)
                  const _MentorThinking()
                else ...[
                  Text(
                    _question!,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              height: 1.4,
                            ),
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reflectionController,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Write freely...',
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 20),
                  if (_step == 1)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _proceedToDimensions,
                        child: const Text('Rate Your Dimensions'),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                ],
              ],

              // Step 3: Dimension ratings
              if (_step >= 2) ...[
                const SizedBox(height: 32),
                Text(
                  'How did today feel?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  'Rate each dimension honestly. There are no wrong answers.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                const SizedBox(height: 24),
                DimensionSlider(
                  label: 'Peace',
                  lowLabel: 'At war',
                  highLabel: 'At peace',
                  value: _peace,
                  onChanged: (v) => setState(() => _peace = v),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                const SizedBox(height: 20),
                DimensionSlider(
                  label: 'Self-Compassion',
                  lowLabel: 'Self-critical',
                  highLabel: 'Self-kind',
                  value: _selfCompassion,
                  onChanged: (v) => setState(() => _selfCompassion = v),
                ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                const SizedBox(height: 20),
                DimensionSlider(
                  label: 'Forgiveness',
                  lowLabel: 'Holding on',
                  highLabel: 'Letting go',
                  value: _forgiveness,
                  onChanged: (v) => setState(() => _forgiveness = v),
                ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
                const SizedBox(height: 20),
                DimensionSlider(
                  label: 'Presence',
                  lowLabel: 'Distracted',
                  highLabel: 'Present',
                  value: _presence,
                  onChanged: (v) => setState(() => _presence = v),
                ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _complete,
                    child: const Text('Complete Reflection'),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown while the mentor's evening question is being generated.
class _MentorThinking extends StatelessWidget {
  const _MentorThinking();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeOut(duration: 700.ms)
            .then()
            .fadeIn(duration: 700.ms),
        const SizedBox(width: 10),
        Text(
          'The mentor is considering your day…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

class _CompletionView extends StatelessWidget {
  final VoidCallback onDone;

  const _CompletionView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.nights_stay_rounded,
                color: AppColors.accent,
                size: 64,
              ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 24),
              Text(
                'Reflection complete',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              const SizedBox(height: 12),
              Text(
                'Another day of your journey recorded.\n'
                'Rest well — you\'ve earned it.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
