import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/conflict_type.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

class _QuizQuestion {
  final String question;
  final List<_QuizOption> options;

  const _QuizQuestion({required this.question, required this.options});
}

class _QuizOption {
  final String text;
  final Map<ConflictType, int> scores;

  const _QuizOption({required this.text, required this.scores});
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final List<int> _answers = [];
  int _currentPage = 0;
  bool _isTransitioning = false;
  late AnimationController _progressController;

  static const _questions = [
    _QuizQuestion(
      question: 'When conflict arises, what\'s your first instinct?',
      options: [
        _QuizOption(
          text: 'Hold onto it \u2014 they need to know they hurt me',
          scores: {ConflictType.resentment: 3, ConflictType.relationship: 1},
        ),
        _QuizOption(
          text: 'Blame myself \u2014 I probably deserved it',
          scores: {ConflictType.selfHatred: 3, ConflictType.identity: 1},
        ),
        _QuizOption(
          text: 'Compare how others handle things better than me',
          scores: {ConflictType.comparison: 3, ConflictType.selfHatred: 1},
        ),
        _QuizOption(
          text: 'Shut down and withdraw',
          scores: {ConflictType.grief: 2, ConflictType.relationship: 2},
        ),
      ],
    ),
    _QuizQuestion(
      question: 'What keeps you up at night?',
      options: [
        _QuizOption(
          text: 'Replaying arguments and things I should have said',
          scores: {ConflictType.resentment: 3, ConflictType.workplace: 1},
        ),
        _QuizOption(
          text: 'Feeling like I\'m not who I\'m supposed to be',
          scores: {ConflictType.identity: 3, ConflictType.selfHatred: 1},
        ),
        _QuizOption(
          text: 'Worrying about what others think of me',
          scores: {ConflictType.comparison: 2, ConflictType.identity: 2},
        ),
        _QuizOption(
          text: 'Fighting urges or habits I can\'t seem to break',
          scores: {ConflictType.addiction: 3, ConflictType.selfHatred: 1},
        ),
      ],
    ),
    _QuizQuestion(
      question: 'Which statement resonates most?',
      options: [
        _QuizOption(
          text: 'I can\'t forgive them for what they did',
          scores: {ConflictType.resentment: 3, ConflictType.grief: 1},
        ),
        _QuizOption(
          text: 'I can\'t forgive myself for what I did',
          scores: {ConflictType.selfHatred: 3, ConflictType.addiction: 1},
        ),
        _QuizOption(
          text: 'Everyone else seems to have it figured out except me',
          scores: {ConflictType.comparison: 3, ConflictType.identity: 1},
        ),
        _QuizOption(
          text: 'The world took something from me and it\'s not fair',
          scores: {ConflictType.grief: 3, ConflictType.resentment: 1},
        ),
      ],
    ),
    _QuizQuestion(
      question: 'Where do you feel the most tension?',
      options: [
        _QuizOption(
          text: 'At work \u2014 toxic people, unfair situations',
          scores: {ConflictType.workplace: 3, ConflictType.resentment: 1},
        ),
        _QuizOption(
          text: 'At home \u2014 with my partner, family, or loved ones',
          scores: {ConflictType.relationship: 3, ConflictType.identity: 1},
        ),
        _QuizOption(
          text: 'Inside myself \u2014 a constant inner battle',
          scores: {ConflictType.selfHatred: 2, ConflictType.addiction: 2},
        ),
        _QuizOption(
          text: 'On social media \u2014 seeing everyone\'s perfect lives',
          scores: {ConflictType.comparison: 3, ConflictType.selfHatred: 1},
        ),
      ],
    ),
    _QuizQuestion(
      question: 'If you could wave a magic wand, what would you change?',
      options: [
        _QuizOption(
          text: 'I\'d erase the people who wronged me from my memory',
          scores: {ConflictType.resentment: 3},
        ),
        _QuizOption(
          text: 'I\'d finally feel at peace with who I am',
          scores: {ConflictType.identity: 2, ConflictType.selfHatred: 2},
        ),
        _QuizOption(
          text: 'I\'d stop caring about what everyone else is doing',
          scores: {ConflictType.comparison: 3},
        ),
        _QuizOption(
          text: 'I\'d bring back what I\'ve lost',
          scores: {ConflictType.grief: 3},
        ),
      ],
    ),
    _QuizQuestion(
      question: 'How do you typically deal with pain?',
      options: [
        _QuizOption(
          text: 'I numb it \u2014 substances, screens, distractions',
          scores: {ConflictType.addiction: 3, ConflictType.selfHatred: 1},
        ),
        _QuizOption(
          text: 'I project it \u2014 someone else is always at fault',
          scores: {ConflictType.resentment: 2, ConflictType.workplace: 2},
        ),
        _QuizOption(
          text: 'I internalise it \u2014 I must be the problem',
          scores: {ConflictType.selfHatred: 3, ConflictType.identity: 1},
        ),
        _QuizOption(
          text: 'I isolate \u2014 pull away from everyone',
          scores: {ConflictType.grief: 2, ConflictType.relationship: 2},
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  ConflictType _calculateResult() {
    final scores = <ConflictType, int>{};
    for (final type in ConflictType.values) {
      scores[type] = 0;
    }

    for (var i = 0; i < _answers.length; i++) {
      final question = _questions[i];
      final option = question.options[_answers[i]];
      for (final entry in option.scores.entries) {
        scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
      }
    }

    var maxType = ConflictType.resentment;
    var maxScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        maxType = entry.key;
      }
    }
    return maxType;
  }

  void _selectAnswer(int index) {
    if (_isTransitioning) return;

    setState(() {
      _isTransitioning = true;
      if (_currentPage < _answers.length) {
        _answers[_currentPage] = index;
      } else {
        _answers.add(index);
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_currentPage < _questions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
        setState(() => _isTransitioning = false);
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _finishQuiz() async {
    final conflictType = _calculateResult();
    final userProvider = context.read<UserProvider>();
    await userProvider.createProfile(
      conflictType: conflictType,
      quizAnswers: _answers,
    );
    if (mounted) {
      context.go('/conflict-reveal');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _questions.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Subtle background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.04),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Very subtle particles
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 12,
              color: AppColors.primary,
              opacity: 0.2,
              maxParticleSize: 2.0,
              minParticleSize: 0.5,
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with journey-style progress
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_currentPage > 0) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOutCubic,
                                );
                              } else {
                                context.go('/intro');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Step indicator text
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              'Question ${_currentPage + 1} of ${_questions.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 42), // Balance the back button
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Journey-style progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 3,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOutCubic,
                            builder: (context, value, child) {
                              return Stack(
                                children: [
                                  // Track
                                  Container(
                                    color: AppColors.surfaceBorder
                                        .withValues(alpha: 0.3),
                                  ),
                                  // Fill
                                  FractionallySizedBox(
                                    widthFactor: value,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primaryDim,
                                            AppColors.primary,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Questions
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      return _QuizPage(
                        key: ValueKey('quiz_page_$index'),
                        question: _questions[index],
                        questionIndex: index,
                        selectedIndex:
                            index < _answers.length ? _answers[index] : null,
                        onSelect: _selectAnswer,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizPage extends StatelessWidget {
  final _QuizQuestion question;
  final int questionIndex;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _QuizPage({
    super.key,
    required this.question,
    required this.questionIndex,
    this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            question.question,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),
          const SizedBox(height: 32),
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Selection indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.2),
                            width: isSelected ? 0 : 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.background,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.text,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: (150 + index * 80).ms,
                    duration: 400.ms,
                  )
                  .slideX(
                    begin: 0.05,
                    end: 0,
                    delay: (150 + index * 80).ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),
            );
          }),
        ],
      ),
    );
  }
}
