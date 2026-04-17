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

class MorningCheckInScreen extends StatefulWidget {
  const MorningCheckInScreen({super.key});

  @override
  State<MorningCheckInScreen> createState() => _MorningCheckInScreenState();
}

class _MorningCheckInScreenState extends State<MorningCheckInScreen> {
  final _intentionController = TextEditingController();
  Mood? _selectedMood;
  String? _aiPrompt;
  int _step = 0; // 0 = mood, 1 = AI prompt, 2 = intention

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  bool _loadingPrompt = false;

  void _onMoodSelected(Mood mood) {
    setState(() {
      _selectedMood = mood;
      _step = 1;
      _loadingPrompt = true;
      _aiPrompt = null;
    });

    // Fetch the AI prompt async — UI shows a soft placeholder in the meantime.
    () async {
      final userProvider = context.read<UserProvider>();
      final journeyProvider = context.read<JourneyProvider>();
      final profile = userProvider.profile;
      if (profile == null) return;
      try {
        final prompt = await journeyProvider.generateMorningPrompt(
          profile: profile,
          mood: mood,
          context: userProvider.aiContext,
          last7Days: userProvider.checkIns,
        );
        if (!mounted) return;
        setState(() {
          _aiPrompt = prompt;
          _loadingPrompt = false;
        });
      } catch (_) {
        if (!mounted) return;
        // Belt-and-braces — journeyProvider already falls back internally.
        setState(() {
          _aiPrompt = journeyProvider.getMorningPrompt(
            profile.primaryConflict,
            mood: mood,
          );
          _loadingPrompt = false;
        });
      }
    }();
  }

  void _proceedToIntention() {
    setState(() => _step = 2);
  }

  Future<void> _complete() async {
    if (_selectedMood == null) return;

    HapticFeedback.mediumImpact();
    final userProvider = context.read<UserProvider>();
    await userProvider.recordMorningCheckIn(
      mood: _selectedMood!,
      intention: _intentionController.text.trim(),
      aiPrompt: _aiPrompt,
    );

    if (mounted) {
      HapticFeedback.lightImpact();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(
              Icons.check_circle_outlined,
              color: AppColors.peace,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Morning check-in complete',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Carry your intention with you today.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Morning Check-in'),
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

              // Step 2: AI Prompt (may be loading)
              if (_step >= 1) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.accent.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Mentor Says',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loadingPrompt || _aiPrompt == null)
                        _MentorThinking()
                      else
                        Text(
                          _aiPrompt!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 20),
                if (_step == 1 && !_loadingPrompt && _aiPrompt != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _proceedToIntention,
                      child: const Text('Set Today\'s Intention'),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              ],

              // Step 3: Intention
              if (_step >= 2) ...[
                const SizedBox(height: 24),
                Text(
                  'What is your intention for today?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  'One sentence. Something you can carry with you.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                const SizedBox(height: 16),
                TextField(
                  controller: _intentionController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. "I will respond with calm today"',
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _complete,
                    child: const Text('Complete Check-in'),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft placeholder while the mentor prompt streams back. Keeps the card's
/// visual height roughly stable so the CTA doesn't jump when the text lands.
class _MentorThinking extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeOut(duration: 700.ms)
            .then()
            .fadeIn(duration: 700.ms),
        const SizedBox(width: 8),
        Text(
          'The mentor is listening…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}
