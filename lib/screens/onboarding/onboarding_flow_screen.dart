import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/conflict_type.dart';
import '../../models/onboarding_data.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

// ---------------------------------------------------------------------------
// Quiz data structures — ported from quiz_screen.dart
// ---------------------------------------------------------------------------

class _QuizOption {
  final String text;
  final Map<ConflictType, int> scores;
  const _QuizOption({required this.text, required this.scores});
}

class _QuizQuestion {
  final String question;
  final List<_QuizOption> options;
  const _QuizQuestion({required this.question, required this.options});
}

// ---------------------------------------------------------------------------
// Page CTA configuration — drives the fixed bottom CTA bar
// ---------------------------------------------------------------------------

class _PageCTAConfig {
  final String text;
  final VoidCallback? action; // null means disabled
  final String? skipText;
  final VoidCallback? skipAction;

  const _PageCTAConfig({
    required this.text,
    required this.action,
    this.skipText,
    this.skipAction,
  });
}

// ---------------------------------------------------------------------------
// Main orchestrator
// ---------------------------------------------------------------------------

class OnboardingFlowScreen extends StatefulWidget {
  /// Optional starting page for debug quick-navigation.
  final int startPage;

  const OnboardingFlowScreen({super.key, this.startPage = 0});

  /// Page names for the debug picker.
  static const pageNames = [
    '0 — Name Input',
    '1 — Quiz Q1: First Instinct',
    '2 — Quiz Q2: Keeps You Up',
    '3 — Quiz Q3: Resonates Most',
    '4 — Not Alone (value)',
    '5 — Science (value)',
    '6 — Quiz Q4: Anger Trigger',
    '7 — Quiz Q5: Peace Moment',
    '8 — Quiz Q6: Struggle Pattern',
    '9 — Conflict Target',
    '10 — Duration',
    '11 — Mentor (value)',
    '12 — Cost of Conflict (value)',
    '13 — Previous Attempts',
    '14 — Conflict Style',
    '15 — Intensity Slider',
    '16 — Check-in Time',
    '17 — Journey Preview',
    '18 — Personal Intention',
    '19 — Processing',
    '20 — Conflict Reveal',
    '21 — Ready to Commit',
    '22 — Celebration',
  ];

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen>
    with TickerProviderStateMixin {
  static const _totalPages = 23;

  /// Bottom padding each scrollable page reserves so its content doesn't hide
  /// behind the fixed global CTA bar.
  static const double _bottomCtaReserve = 120.0;

  final _pageController = PageController();
  final _data = OnboardingData();
  int _currentPage = 0;
  bool _isTransitioning = false;

  // Pulsing glow shared across atmospheric screens
  late AnimationController _pulseController;

  // Processing screen state
  bool _processingDone = false;
  String _processingDisplayText = '';
  late AnimationController _cursorBlinkController;
  bool _processingTypingActive = false;

  // Reveal screen state
  bool _revealShowContent = false;
  bool _revealShowName = false;
  bool _revealShowDescription = false;
  bool _revealShowPersonal = false;
  bool _revealShowCharacter = false;
  bool _revealShowJourney = false;
  bool _revealShowButton = false;
  late AnimationController _revealScaleController;
  late Animation<double> _revealScale;

  // Celebration confetti
  bool _showConfetti = false;

  // Name field
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  // Intention field
  final _intentionController = TextEditingController();
  final _intentionFocus = FocusNode();

  // Slider state
  double _sliderValue = 5;
  int _lastIntensityValue = 5;

  // Multi-select state for previous attempts
  final Set<String> _selectedAttempts = {};

  // Animated stat counter
  double _animatedStatPercent = 0;
  Timer? _statCountTimer;

  // Completed processing lines for the typing effect
  final List<String> _processingCompletedLines = [];

  // --- Quiz questions (reused from quiz_screen.dart) ---
  static const _quizQuestions = [
    // Q1 (page 2)
    _QuizQuestion(
      question: "When conflict arises, what's your first instinct?",
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
    // Q2 (page 3)
    _QuizQuestion(
      question: 'What keeps you up at night?',
      options: [
        _QuizOption(
          text: "Replaying arguments and things I should have said",
          scores: {ConflictType.resentment: 3, ConflictType.workplace: 1},
        ),
        _QuizOption(
          text: "Feeling like I'm not who I'm supposed to be",
          scores: {ConflictType.identity: 3, ConflictType.selfHatred: 1},
        ),
        _QuizOption(
          text: 'Worrying about what others think of me',
          scores: {ConflictType.comparison: 2, ConflictType.identity: 2},
        ),
        _QuizOption(
          text: "Fighting urges or habits I can't seem to break",
          scores: {ConflictType.addiction: 3, ConflictType.selfHatred: 1},
        ),
      ],
    ),
    // Q3 (page 4)
    _QuizQuestion(
      question: 'Which statement resonates most?',
      options: [
        _QuizOption(
          text: "I can't forgive them for what they did",
          scores: {ConflictType.resentment: 3, ConflictType.grief: 1},
        ),
        _QuizOption(
          text: "I can't forgive myself for what I did",
          scores: {ConflictType.selfHatred: 3, ConflictType.addiction: 1},
        ),
        _QuizOption(
          text: 'Everyone else seems to have it figured out except me',
          scores: {ConflictType.comparison: 3, ConflictType.identity: 1},
        ),
        _QuizOption(
          text: "The world took something from me and it's not fair",
          scores: {ConflictType.grief: 3, ConflictType.resentment: 1},
        ),
      ],
    ),
    // Q4 (page 7)
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
          text: "On social media \u2014 seeing everyone's perfect lives",
          scores: {ConflictType.comparison: 3, ConflictType.selfHatred: 1},
        ),
      ],
    ),
    // Q5 (page 8)
    _QuizQuestion(
      question: 'If you could wave a magic wand, what would you change?',
      options: [
        _QuizOption(
          text: "I'd erase the people who wronged me from my memory",
          scores: {ConflictType.resentment: 3},
        ),
        _QuizOption(
          text: "I'd finally feel at peace with who I am",
          scores: {ConflictType.identity: 2, ConflictType.selfHatred: 2},
        ),
        _QuizOption(
          text: "I'd stop caring about what everyone else is doing",
          scores: {ConflictType.comparison: 3},
        ),
        _QuizOption(
          text: "I'd bring back what I've lost",
          scores: {ConflictType.grief: 3},
        ),
      ],
    ),
    // Q6 (page 9)
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

  // Q7 target options
  static const _conflictTargets = [
    ('Myself', Icons.person_outline),
    ('Family', Icons.family_restroom_outlined),
    ('Partner', Icons.favorite_border),
    ('Colleague', Icons.business_outlined),
    ('Friend', Icons.people_outline),
    ('The world', Icons.public_outlined),
  ];

  // Q7 scoring
  static const _targetScores = {
    'Myself': {ConflictType.selfHatred: 2, ConflictType.identity: 1},
    'Family': {ConflictType.relationship: 2, ConflictType.resentment: 1},
    'Partner': {ConflictType.relationship: 2, ConflictType.grief: 1},
    'Colleague': {ConflictType.workplace: 2, ConflictType.resentment: 1},
    'Friend': {ConflictType.resentment: 2, ConflictType.comparison: 1},
    'The world': {ConflictType.grief: 2, ConflictType.identity: 1},
  };

  // Q8 duration options
  static const _durationOptions = [
    ('Days', Icons.today_outlined),
    ('Weeks', Icons.date_range_outlined),
    ('Months', Icons.calendar_month_outlined),
    ('Years', Icons.calendar_today_outlined),
    ("Can't remember", Icons.all_inclusive_outlined),
  ];

  // Q9 previous attempts
  static const _attemptOptions = [
    'Therapy',
    'Meditation',
    'Journaling',
    'Friends & family',
    'Books & podcasts',
    'Nothing',
  ];

  // Q10 conflict styles
  static const _conflictStyles = [
    ('Fighter', Icons.gavel_outlined, 'You confront head-on'),
    ('Avoider', Icons.shield_outlined, 'You dodge and deflect'),
    ('People-pleaser', Icons.volunteer_activism_outlined, 'You give in to keep peace'),
    ('Suppressor', Icons.whatshot_outlined, 'You bottle it up inside'),
  ];

  // Intention placeholders by conflict type
  static const _intentionPlaceholders = {
    ConflictType.resentment: [
      'I want to let go of the grudge against...',
      'I want to stop replaying old arguments...',
      'I want to free myself from bitterness...',
    ],
    ConflictType.selfHatred: [
      'I want to stop being so hard on myself...',
      'I want to forgive my past mistakes...',
      'I want to treat myself with kindness...',
    ],
    ConflictType.comparison: [
      'I want to stop comparing myself to others...',
      'I want to celebrate my own journey...',
      'I want to feel enough as I am...',
    ],
    ConflictType.workplace: [
      'I want to leave work stress at work...',
      'I want to stop letting toxic people control me...',
      'I want peace regardless of my environment...',
    ],
    ConflictType.relationship: [
      'I want to stop fighting with the people I love...',
      'I want healthier communication...',
      'I want love without constant conflict...',
    ],
    ConflictType.identity: [
      'I want to accept who I really am...',
      'I want to stop pretending to be someone else...',
      'I want to bridge who I am and who I want to be...',
    ],
    ConflictType.grief: [
      'I want to find peace with what I have lost...',
      'I want to stop being angry at the universe...',
      'I want to honour my loss without drowning in it...',
    ],
    ConflictType.addiction: [
      'I want to break the cycle that controls me...',
      'I want to be stronger than my patterns...',
      'I want to find peace without numbing myself...',
    ],
  };

  @override
  void initState() {
    super.initState();

    // Debug: jump to a specific page if requested
    if (widget.startPage > 0 && widget.startPage < _totalPages) {
      _currentPage = widget.startPage;
      // Pre-fill onboarding data with defaults so pages don't crash
      _data.userName = 'Debug User';
      _data.quizAnswers = [0, 0, 0, 0, 0, 0];
      _data.conflictTarget = 'Myself';
      _data.conflictDuration = 'Years';
      _data.previousAttempts = ['Nothing'];
      _data.conflictStyle = 'Fighter';
      _data.conflictIntensity = 5;
      _data.preferredCheckInTime = 'Morning';
      _data.personalIntention = 'Find peace';
      _data.calculatedConflictType = ConflictType.selfHatred;
      // Jump the page controller after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(widget.startPage);
      });
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _cursorBlinkController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _cursorBlinkController.forward();
        }
      });

    _revealScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _revealScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealScaleController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _cursorBlinkController.dispose();
    _revealScaleController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    _intentionController.dispose();
    _intentionFocus.dispose();
    _statCountTimer?.cancel();
    super.dispose();
  }

  // --- Navigation helpers ---

  void _nextPage() {
    if (_isTransitioning || _currentPage >= _totalPages - 1) return;
    _isTransitioning = true;
    _pageController
        .nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    )
        .then((_) {
      _isTransitioning = false;
    });
  }

  void _previousPage() {
    if (_isTransitioning) return;
    if (_currentPage == 0) {
      context.go('/intro');
      return;
    }
    _isTransitioning = true;
    _pageController
        .previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    )
        .then((_) {
      _isTransitioning = false;
    });
  }

  void _selectQuizAnswer(int questionIndex, int answerIndex) {
    if (_isTransitioning) return;
    setState(() {
      if (questionIndex < _data.quizAnswers.length) {
        _data.quizAnswers[questionIndex] = answerIndex;
      } else {
        _data.quizAnswers.add(answerIndex);
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _nextPage();
    });
  }

  ConflictType _calculateConflictType() {
    final scores = <ConflictType, int>{};
    for (final type in ConflictType.values) {
      scores[type] = 0;
    }

    // Q1-Q6 standard quiz scoring
    for (var i = 0; i < _data.quizAnswers.length && i < _quizQuestions.length;
        i++) {
      final question = _quizQuestions[i];
      final option = question.options[_data.quizAnswers[i]];
      for (final entry in option.scores.entries) {
        scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
      }
    }

    // Q7 target scoring
    if (_data.conflictTarget != null) {
      final targetScores = _targetScores[_data.conflictTarget];
      if (targetScores != null) {
        for (final entry in targetScores.entries) {
          scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
        }
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

  Future<void> _typeOutLine(String line) async {
    _processingDisplayText = '';
    _processingTypingActive = true;
    _cursorBlinkController.forward();
    int charCount = 0;
    for (int i = 0; i < line.length; i++) {
      if (!mounted) return;
      charCount++;
      setState(() {
        _processingDisplayText = line.substring(0, i + 1);
      });
      if (charCount % 3 == 0) {
        HapticFeedback.selectionClick();
      }
      await Future.delayed(const Duration(milliseconds: 40));
    }
    _processingTypingActive = false;
    _cursorBlinkController.stop();
    if (mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _runProcessingSequence() async {
    final steps = [
      'Mapping your conflict patterns...',
      'Identifying your primary conflict...',
      'Building your personalised journey...',
      'Your profile is ready.',
    ];

    setState(() {
      _processingCompletedLines.clear();
      _processingDisplayText = '';
      _processingTypingActive = false;
    });

    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return;
      await _typeOutLine(steps[i]);
      if (!mounted) return;

      if (i < steps.length - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _processingCompletedLines.add(steps[i]);
          _processingDisplayText = '';
        });
      } else {
        // Last line — calculate conflict type and mark done
        _data.calculatedConflictType = _calculateConflictType();
        setState(() {
          _processingDone = true;
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;
        _nextPage();
      }
    }
  }

  Future<void> _runRevealSequence() async {
    // Reset state
    _revealShowContent = false;
    _revealShowName = false;
    _revealShowDescription = false;
    _revealShowPersonal = false;
    _revealShowCharacter = false;
    _revealShowJourney = false;
    _revealShowButton = false;
    _revealScaleController.value = 0;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _revealShowContent = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _revealShowName = true);
    _revealScaleController.forward();
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _revealShowDescription = true);

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _revealShowPersonal = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _revealShowCharacter = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _revealShowJourney = true);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _revealShowButton = true);
  }

  void _startStatAnimation() {
    _animatedStatPercent = 0;
    int step = 0;
    const totalSteps = 60;
    _statCountTimer?.cancel();
    _statCountTimer =
        Timer.periodic(const Duration(milliseconds: 25), (timer) {
      step++;
      if (!mounted || step >= totalSteps) {
        timer.cancel();
        if (mounted) setState(() => _animatedStatPercent = 73);
        return;
      }
      setState(() {
        _animatedStatPercent = 73 * (step / totalSteps);
      });
    });
  }

  Future<void> _finishOnboarding() async {
    final conflictType =
        _data.calculatedConflictType ?? _calculateConflictType();
    final userProvider = context.read<UserProvider>();
    await userProvider.createProfile(
      conflictType: conflictType,
      quizAnswers: _data.quizAnswers,
      displayName: _data.userName,
      conflictTarget: _data.conflictTarget,
      conflictDuration: _data.conflictDuration,
      conflictIntensity: _data.conflictIntensity,
      conflictStyle: _data.conflictStyle,
      preferredCheckInTime: _data.preferredCheckInTime,
      personalIntention: _data.personalIntention,
      previousAttempts: _data.previousAttempts,
    );
    if (mounted) {
      context.go('/paywall');
    }
  }

  String _getConflictFileName(ConflictType conflict) {
    switch (conflict) {
      case ConflictType.resentment:
        return 'resentment';
      case ConflictType.selfHatred:
        return 'self_criticism';
      case ConflictType.comparison:
        return 'comparison';
      case ConflictType.workplace:
        return 'workplace';
      case ConflictType.relationship:
        return 'relationship';
      case ConflictType.identity:
        return 'identity';
      case ConflictType.grief:
        return 'grief';
      case ConflictType.addiction:
        return 'addiction';
    }
  }

  // --- Helpers for checking if back/progress should be hidden ---

  bool get _hideBackButton =>
      _currentPage == 19 || // processing
      _currentPage == 20 || // reveal
      _currentPage == 22; // celebration

  bool get _hideProgress =>
      _currentPage == 19 || // processing
      _currentPage == 20; // reveal

  // --- Page changed callback ---

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Trigger special sequences
    if (page == 5) {
      _startStatAnimation();
    }
    if (page == 19) {
      _processingDone = false;
      _runProcessingSequence();
    }
    if (page == 20) {
      _runRevealSequence();
    }
    if (page == 22) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showConfetti = true);
      });
      // Haptic feedback for each stat card appearing
      for (int i = 0; i < 4; i++) {
        Future.delayed(Duration(milliseconds: 1100 + i * 150), () {
          if (mounted) HapticFeedback.lightImpact();
        });
      }
    }
  }

  // -----------------------------------------------------------------------
  // CTA config — one source of truth for the fixed bottom CTA bar
  // -----------------------------------------------------------------------

  _PageCTAConfig? _ctaConfigForPage(int page) {
    switch (page) {
      case 0: // Name input
        return _PageCTAConfig(
          text: 'Continue',
          action: () {
            _data.userName = _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim();
            _nextPage();
          },
          skipText: 'Skip',
          skipAction: () {
            _data.userName = null;
            _nextPage();
          },
        );
      // Quiz pages (auto-advance) — no CTA
      case 1:
      case 2:
      case 3:
      case 6:
      case 7:
      case 8:
      case 9: // Q7 target — auto advance
      case 10: // Q8 duration — auto advance
      case 14: // Q10 style — auto advance
        return null;
      case 4: // Not alone
        return _PageCTAConfig(text: "I'm not alone", action: _nextPage);
      case 5: // Science
        return _PageCTAConfig(text: "I'm ready to change", action: _nextPage);
      case 11: // AI mentor
        return _PageCTAConfig(text: 'I want my mentor', action: _nextPage);
      case 12: // Cost of conflict
        return _PageCTAConfig(text: 'I choose peace', action: _nextPage);
      case 13: // Q9 previous attempts — multi-select, disabled until selection
        return _PageCTAConfig(
          text: 'Continue',
          action: _selectedAttempts.isEmpty
              ? null
              : () {
                  _data.previousAttempts = _selectedAttempts.toList();
                  _nextPage();
                },
        );
      case 15: // Intensity slider
        return _PageCTAConfig(
          text: 'Continue',
          action: () {
            _data.conflictIntensity = _sliderValue.round();
            _nextPage();
          },
        );
      case 16: // Check-in time — disabled until selection
        return _PageCTAConfig(
          text: 'Continue',
          action: _data.preferredCheckInTime == null ? null : _nextPage,
        );
      case 17: // Journey preview
        return _PageCTAConfig(text: 'Show me my path', action: _nextPage);
      case 18: // Personal intention
        return _PageCTAConfig(
          text: 'Continue',
          action: () {
            _data.personalIntention =
                _intentionController.text.trim().isEmpty
                    ? null
                    : _intentionController.text.trim();
            _nextPage();
          },
          skipText: 'Skip',
          skipAction: () {
            _data.personalIntention = null;
            _nextPage();
          },
        );
      case 19: // Processing — auto advance
        return null;
      case 20: // Conflict reveal — only show after animation completes
        if (!_revealShowButton) return null;
        return _PageCTAConfig(
          text: 'Continue Your Journey',
          action: _nextPage,
        );
      case 21: // Ready to commit — uses inline choice cards
        return null;
      case 22: // Celebration — create profile then navigate to paywall
        return _PageCTAConfig(
          text: 'See Your Plan',
          action: () async {
            await _finishOnboarding();
          },
        );
      default:
        return null;
    }
  }

  // -----------------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _totalPages;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
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

          // Particles on atmospheric screens
          if (_currentPage == 4 || // not alone
              _currentPage == 17 || // journey preview
              _currentPage == 20 || // reveal
              _currentPage == 22) // celebration
            const Positioned.fill(
              child: AmbientParticles(
                particleCount: 15,
                color: AppColors.primary,
                opacity: 0.25,
                maxParticleSize: 2.0,
                minParticleSize: 0.5,
              ),
            ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                if (!_hideProgress)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (!_hideBackButton)
                              GestureDetector(
                                onTap: _previousPage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 42),
                            const Spacer(),
                            const Spacer(),
                            const SizedBox(width: 42),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Thin golden progress bar
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
                                    Container(
                                      color: AppColors.surfaceBorder
                                          .withValues(alpha: 0.3),
                                    ),
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

                // Pages + fixed CTA overlay
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          return _buildPage(index);
                        },
                      ),

                      // Gradient fade at bottom — obscures content scrolling
                      // behind the fixed CTA bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.0),
                                  Colors.black.withValues(alpha: 0.85),
                                  Colors.black,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Fixed CTA bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildFixedCtaBar(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Fixed bottom CTA bar
  // -----------------------------------------------------------------------

  Widget _buildFixedCtaBar() {
    final cta = _ctaConfigForPage(_currentPage);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: cta == null
              ? const SizedBox(
                  key: ValueKey('cta-empty'),
                  width: double.infinity,
                )
              : Column(
                  key: ValueKey(
                    'cta-$_currentPage-${cta.text}-${cta.action == null}',
                  ),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _goldenCTA(cta.text, cta.action),
                    if (cta.skipText != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: cta.skipAction,
                        child: Text(
                          cta.skipText!,
                          style: TextStyle(
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page router
  // -----------------------------------------------------------------------

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildNameInputPage();
      case 1:
        return _buildQuizPage(0); // Q1
      case 2:
        return _buildQuizPage(1); // Q2
      case 3:
        return _buildQuizPage(2); // Q3
      case 4:
        return _buildNotAlonePage();
      case 5:
        return _buildSciencePage();
      case 6:
        return _buildQuizPage(3); // Q4
      case 7:
        return _buildQuizPage(4); // Q5
      case 8:
        return _buildQuizPage(5); // Q6
      case 9:
        return _buildConflictTargetPage(); // Q7
      case 10:
        return _buildConflictDurationPage(); // Q8
      case 11:
        return _buildAiMentorPage();
      case 12:
        return _buildCostOfConflictPage();
      case 13:
        return _buildPreviousAttemptsPage(); // Q9
      case 14:
        return _buildConflictStylePage(); // Q10
      case 15:
        return _buildIntensitySliderPage();
      case 16:
        return _buildCheckInTimePage();
      case 17:
        return _buildJourneyPreviewPage();
      case 18:
        return _buildPersonalIntentionPage();
      case 19:
        return _buildProcessingPage();
      case 20:
        return _buildConflictRevealPage();
      case 21:
        return _buildReadyToCommitPage();
      case 22:
        return _buildCelebrationPage();
      default:
        return const SizedBox.shrink();
    }
  }

  // -----------------------------------------------------------------------
  // Shared widgets
  // -----------------------------------------------------------------------

  /// Scrolls when content overflows but allows [Spacer] to fill free space
  /// when the screen is tall enough. Use this for any page whose layout
  /// currently relies on [Spacer] and fixed spacing.
  Widget _adaptiveScroll({
    required List<Widget> children,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24),
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _goldenCTA(String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFFD4A853), Color(0xFFE8C87A)]
                  : [
                      const Color(0xFFD4A853).withValues(alpha: 0.55),
                      const Color(0xFFE8C87A).withValues(alpha: 0.55),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledForegroundColor: Colors.black.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _frostedCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }

  // -----------------------------------------------------------------------
  // Page 1 — Name Input
  // -----------------------------------------------------------------------

  Widget _buildNameInputPage() {
    return _adaptiveScroll(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(
          'What should\nwe call you?',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
        ).animate().fadeIn(duration: 500.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 500.ms,
            ),
        const SizedBox(height: 12),
        Text(
          "This is your private journey. We'll use this to personalise your experience.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                height: 1.6,
              ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const SizedBox(height: 36),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          autofocus: widget.startPage == 0,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(
              color: AppColors.textTertiary,
            ),
            filled: false,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onSubmitted: (_) {
            _data.userName = _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim();
            _nextPage();
          },
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
        const Spacer(),
        const SizedBox(height: _bottomCtaReserve),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Quiz pages (Q1-Q6) — reuses existing card styling
  // -----------------------------------------------------------------------

  Widget _buildQuizPage(int questionIndex) {
    final question = _quizQuestions[questionIndex];
    final selectedAnswer = questionIndex < _data.quizAnswers.length
        ? _data.quizAnswers[questionIndex]
        : null;

    return SingleChildScrollView(
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
          const SizedBox(height: 28),
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedAnswer == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _selectQuizAnswer(questionIndex, index),
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
                              color:
                                  AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
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
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option.text,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 5 — "You're not alone"
  // -----------------------------------------------------------------------

  Widget _buildNotAlonePage() {
    // Target audience: anime/seinen fans, mostly 20-40, dealing with modern conflicts.
    // Raw, specific, relatable vignettes — not generic one-liners.
    final stories = [
      _NotAloneStory(
        quote:
            "I haven't spoken to my dad in 4 years. I still hear his voice in every argument.",
        label: 'Hasn\'t spoken to his father',
        duration: '4 years',
        color: AppColors.war,
        icon: Icons.link_off,
      ),
      _NotAloneStory(
        quote:
            "I scroll at 2 a.m. comparing myself to people I don't even know. I hate it. I can't stop.",
        label: 'Stuck in comparison',
        duration: 'every night',
        color: AppColors.primary,
        icon: Icons.visibility_outlined,
      ),
      _NotAloneStory(
        quote:
            "My job is eating me alive. I come home angry and take it out on people I love.",
        label: 'Burnt out and bitter',
        duration: '3 years',
        color: AppColors.accent,
        icon: Icons.local_fire_department_outlined,
      ),
      _NotAloneStory(
        quote:
            "She left a year ago and I'm still rehearsing what I should have said.",
        label: 'Still writing the ending',
        duration: '1 year',
        color: AppColors.peace,
        icon: Icons.favorite_border,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),

          _sectionLabel('YOU ARE NOT ALONE')
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 14),

          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFE8C87A),
                Color(0xFFD4A853),
                Color(0xFFF0D78C),
              ],
            ).createShader(bounds),
            child: Text(
              'Real people,\nreal battles.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 6),
          Text(
            "You're not the only one carrying this.",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          const SizedBox(height: 22),

          ...stories.asMap().entries.map((entry) {
            final story = entry.value;
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _storyCard(story),
            )
                .animate()
                .fadeIn(
                  delay: (500 + i * 180).ms,
                  duration: 600.ms,
                )
                .slideY(
                  begin: 0.08,
                  end: 0,
                  delay: (500 + i * 180).ms,
                  duration: 600.ms,
                );
          }),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              "Thousands of men and women\nare walking this same path.",
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: AppColors.primary.withValues(alpha: 0.9),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          )
              .animate()
              .fadeIn(delay: 1400.ms, duration: 500.ms),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  Widget _storyCard(_NotAloneStory story) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: story.color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: story.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  story.icon,
                  color: story.color,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  story.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: story.color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                story.duration,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The quote — italic, slightly larger, emotional
          Text(
            story.quote,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 6 — "The science is clear"
  // -----------------------------------------------------------------------

  Widget _buildSciencePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 32),

          _sectionLabel('THE SCIENCE IS CLEAR'),
          const SizedBox(height: 40),

          // Big animated stat
          Text(
            '${_animatedStatPercent.toInt()}%',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1,
                ),
          ).animate().fadeIn(duration: 600.ms),

          const SizedBox(height: 8),
          Text(
            'of people who practice daily reflection\nreport reduced inner conflict',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

          const SizedBox(height: 40),

          // Bullet points
          ...[
            ('Lower cortisol', 'Reduced stress hormone levels'),
            ('Less anxiety', 'Fewer intrusive thoughts & rumination'),
            ('Reduced inflammation', 'Better physical health markers'),
          ].asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.$1,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          entry.value.$2,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                  delay: (500 + entry.key * 150).ms,
                  duration: 400.ms,
                )
                .slideX(
                  begin: 0.05,
                  end: 0,
                  delay: (500 + entry.key * 150).ms,
                  duration: 400.ms,
                );
          }),

          const SizedBox(height: 16),

          Text(
            'Source: Journal of Behavioural Medicine, 2023',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 10 — Q7 Conflict Target (2-column grid)
  // -----------------------------------------------------------------------

  Widget _buildConflictTargetPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Who is this conflict\nreally with?',
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

          // 2-column grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: _conflictTargets.asMap().entries.map((entry) {
              final target = entry.value;
              final isSelected = _data.conflictTarget == target.$1;

              return GestureDetector(
                onTap: () {
                  if (_isTransitioning) return;
                  setState(() => _data.conflictTarget = target.$1);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) _nextPage();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
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
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        target.$2,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        target.$1,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: (200 + entry.key * 80).ms,
                    duration: 400.ms,
                  )
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                    delay: (200 + entry.key * 80).ms,
                    duration: 400.ms,
                  );
            }).toList(),
          ),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 11 — Q8 Conflict Duration
  // -----------------------------------------------------------------------

  Widget _buildConflictDurationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'How long have you\nbeen carrying this?',
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

          ..._durationOptions.asMap().entries.map((entry) {
            final option = entry.value;
            final isSelected = _data.conflictDuration == option.$1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  if (_isTransitioning) return;
                  setState(() => _data.conflictDuration = option.$1);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) _nextPage();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
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
                  ),
                  child: Row(
                    children: [
                      Icon(
                        option.$2,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        option.$1,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: (150 + entry.key * 80).ms,
                    duration: 400.ms,
                  )
                  .slideX(
                    begin: 0.05,
                    end: 0,
                    delay: (150 + entry.key * 80).ms,
                    duration: 400.ms,
                  ),
            );
          }),
          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 12 — Mentor Preview
  // -----------------------------------------------------------------------

  Widget _buildAiMentorPage() {
    final name = _data.userName ?? 'friend';
    final conflictLabel = _data.conflictTarget?.toLowerCase() ?? 'your heart';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),

          _sectionLabel('YOUR MENTOR'),
          const SizedBox(height: 32),

          Text(
            'Meet your\nmentor.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          // Mentor image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/onboarding/ai_mentor.png',
              width: 160,
              height: 160,
              cacheWidth: 320,
              fit: BoxFit.cover,
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 600.ms).scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                delay: 300.ms,
                duration: 600.ms,
              ),

          const SizedBox(height: 24),

          // Chat bubble
          _frostedCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              'I see you carry the weight of $conflictLabel, $name. '
              "That takes courage to admit. Let's start your journey to peace \u2014 "
              "together, one day at a time.",
              style: GoogleFonts.cormorantGaramond(
                fontSize: 17,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(
                begin: 0.1,
                end: 0,
                delay: 600.ms,
                duration: 600.ms,
              ),

          const SizedBox(height: 24),

          // Feature pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _featurePill('Personalised guidance'),
              _featurePill('Available 24/7'),
              _featurePill('Grows with you'),
            ],
          ).animate().fadeIn(delay: 900.ms, duration: 500.ms),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  Widget _featurePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 13 — Cost of Conflict
  // -----------------------------------------------------------------------

  Widget _buildCostOfConflictPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 32),

          _sectionLabel('THE COST OF CARRYING CONFLICT'),
          const SizedBox(height: 40),

          Text(
            'The cost of\ncarrying conflict.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms),

          const SizedBox(height: 36),

          ...[
            ('Sleep quality', '47%', 'decrease reported'),
            ('Relationships', '3.2', 'lost on average'),
            ('Health impact', '29%', 'higher inflammation'),
          ].asMap().entries.map((entry) {
            final stat = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.war.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.war.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      stat.$2,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                            color: AppColors.war,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.$1,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            stat.$3,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(
                  delay: (400 + entry.key * 200).ms,
                  duration: 500.ms,
                )
                .slideX(
                  begin: 0.05,
                  end: 0,
                  delay: (400 + entry.key * 200).ms,
                  duration: 500.ms,
                );
          }),

          const SizedBox(height: 16),

          Text(
            "You don't have to keep paying this price.",
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 14 — Q9 Previous Attempts (multi-select)
  // -----------------------------------------------------------------------

  Widget _buildPreviousAttemptsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Have you tried to\nresolve this before?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),

          const SizedBox(height: 8),
          Text(
            'Select all that apply',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 28),

          ..._attemptOptions.asMap().entries.map((entry) {
            final option = entry.value;
            final isSelected = _selectedAttempts.contains(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAttempts.remove(option);
                    } else {
                      _selectedAttempts.add(option);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
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
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        option,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: (150 + entry.key * 80).ms,
                    duration: 400.ms,
                  )
                  .slideX(
                    begin: 0.05,
                    end: 0,
                    delay: (150 + entry.key * 80).ms,
                    duration: 400.ms,
                  ),
            );
          }),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 15 — Q10 Conflict Style
  // -----------------------------------------------------------------------

  Widget _buildConflictStylePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'How do you typically\nrespond to conflict?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),

          const SizedBox(height: 28),

          ..._conflictStyles.asMap().entries.map((entry) {
            final style = entry.value;
            final isSelected = _data.conflictStyle == style.$1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  if (_isTransitioning) return;
                  setState(() => _data.conflictStyle = style.$1);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) _nextPage();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          style.$2,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.$1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              style.$3,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: (200 + entry.key * 100).ms,
                    duration: 400.ms,
                  )
                  .slideX(
                    begin: 0.05,
                    end: 0,
                    delay: (200 + entry.key * 100).ms,
                    duration: 400.ms,
                  ),
            );
          }),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 16 — Intensity Slider
  // -----------------------------------------------------------------------

  Widget _buildIntensitySliderPage() {
    final descriptions = [
      'A mild irritation', // 1
      'Noticeable but manageable', // 2
      'It surfaces regularly', // 3
      'Hard to ignore some days', // 4
      'A constant background hum', // 5
      'It affects my decisions', // 6
      'It colours most of my day', // 7
      'It disrupts my relationships', // 8
      'It dominates my thoughts', // 9
      'It consumes everything', // 10
    ];

    final intensityColor = Color.lerp(
      AppColors.accent,
      AppColors.war,
      (_sliderValue - 1) / 9,
    )!;

    return _adaptiveScroll(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'How much does this\nconflict affect your\ndaily life?',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms),
        const Spacer(flex: 2),
        const SizedBox(height: 16),
        // Big number
        Center(
          child: Text(
            '${_sliderValue.round()}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: intensityColor,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              descriptions[(_sliderValue.round() - 1).clamp(0, 9)],
              key: ValueKey(_sliderValue.round()),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Slider
        Row(
          children: [
            Text('1',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: intensityColor,
                  inactiveTrackColor:
                      Colors.white.withValues(alpha: 0.08),
                  thumbColor: intensityColor,
                  overlayColor: intensityColor.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12),
                ),
                child: Slider(
                  value: _sliderValue,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (v) {
                    final newRounded = v.round();
                    if (newRounded != _lastIntensityValue) {
                      if (newRounded == 1 || newRounded == 10) {
                        HapticFeedback.heavyImpact();
                      } else if (newRounded % 5 == 0) {
                        HapticFeedback.mediumImpact();
                      } else {
                        HapticFeedback.selectionClick();
                      }
                      _lastIntensityValue = newRounded;
                    }
                    setState(() => _sliderValue = v);
                  },
                ),
              ),
            ),
            Text('10',
                style: TextStyle(
                    color: AppColors.war, fontWeight: FontWeight.w600)),
          ],
        ),
        const Spacer(flex: 3),
        const SizedBox(height: _bottomCtaReserve),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Page 17 — Check-in Time
  // -----------------------------------------------------------------------

  Widget _buildCheckInTimePage() {
    return _adaptiveScroll(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const SizedBox(height: 24),

          Text(
            'When do you have\nthe most clarity?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),

          const SizedBox(height: 8),
          Text(
            "We'll schedule your reflections around this time.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 36),

          // Morning card
          _timeCard(
            'Morning',
            Icons.wb_sunny_outlined,
            "Fresh mind, clear thoughts",
            _data.preferredCheckInTime == 'morning',
            () => setState(() => _data.preferredCheckInTime = 'morning'),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.05, end: 0, delay: 300.ms, duration: 500.ms),

          const SizedBox(height: 12),

          // Evening card
          _timeCard(
            'Evening',
            Icons.nights_stay_outlined,
            'Reflective, winding down',
            _data.preferredCheckInTime == 'evening',
            () => setState(() => _data.preferredCheckInTime = 'evening'),
          )
              .animate()
              .fadeIn(delay: 450.ms, duration: 500.ms)
              .slideY(begin: 0.05, end: 0, delay: 450.ms, duration: 500.ms),

          const SizedBox(height: 12),

          // Both option (smaller)
          GestureDetector(
            onTap: () =>
                setState(() => _data.preferredCheckInTime = 'both'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: _data.preferredCheckInTime == 'both'
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _data.preferredCheckInTime == 'both'
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Text(
                  'Both \u2014 morning & evening',
                  style: TextStyle(
                    color: _data.preferredCheckInTime == 'both'
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms),

          const Spacer(),
          const SizedBox(height: _bottomCtaReserve),
      ],
    );
  }

  Widget _timeCard(String label, IconData icon, String subtitle,
      bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                icon,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 18 — Journey Preview
  // -----------------------------------------------------------------------

  Widget _buildJourneyPreviewPage() {
    final stages = [
      _JourneyStage(
        name: 'Warrior',
        tagline: 'Still fighting, but aware',
        day: 'Day 1',
        color: AppColors.war,
        image: 'assets/images/characters/warrior_square.png',
        current: true,
      ),
      _JourneyStage(
        name: 'Wanderer',
        tagline: 'Seeking a different path',
        day: 'Week 1',
        color: AppColors.primary,
        image: 'assets/images/characters/wanderer_square.png',
        current: false,
      ),
      _JourneyStage(
        name: 'Seeker',
        tagline: 'Actively practicing peace',
        day: 'Month 1',
        color: AppColors.accent,
        image: 'assets/images/characters/seeker_square.png',
        current: false,
      ),
      _JourneyStage(
        name: 'Peacemaker',
        tagline: 'Living at peace',
        day: 'Month 3+',
        color: AppColors.peace,
        image: 'assets/images/characters/peacemaker_square.png',
        current: false,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          _sectionLabel('YOUR JOURNEY')
              .animate()
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 12),

          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFE8C87A),
                Color(0xFFD4A853),
                Color(0xFFF0D78C),
              ],
            ).createShader(bounds),
            child: Text(
              'From warrior\nto peacemaker.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 6),

          Text(
            'Every journey has stages. Here is yours.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          const SizedBox(height: 24),

          // Vertical timeline — each stage is a row with
          // timeline line on the left, card on the right
          ...List.generate(stages.length, (i) {
            final isLast = i == stages.length - 1;
            return _timelineRow(stages[i], i, isLast);
          }),

          const SizedBox(height: _bottomCtaReserve),
        ],
      ),
    );
  }

  /// A single row in the vertical journey timeline.
  Widget _timelineRow(_JourneyStage stage, int index, bool isLast) {
    const double dotSize = 18;
    const double lineWidth = 2.4;
    const double avatarSize = 72;
    final int delayBase = 500 + index * 200;

    // Align dot center with avatar center in the card.
    // Card padding top (10) + half avatar (36) - half dot (9) = 37
    const double dotTopOffset = 10 + (avatarSize / 2) - (dotSize / 2);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline track (left column) ──
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Upper line segment (connects from previous row's dot)
                if (index > 0)
                  Container(
                    width: lineWidth,
                    height: dotTopOffset,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (index > 0
                                  ? [AppColors.war, AppColors.primary, AppColors.accent, AppColors.peace][index - 1]
                                  : stage.color)
                              .withValues(alpha: 0.5),
                          stage.color.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (delayBase - 50).ms, duration: 400.ms),
                // Top spacer for first row only (no line above)
                if (index == 0)
                  SizedBox(height: dotTopOffset),
                // Glowing dot
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stage.current
                        ? stage.color
                        : stage.color.withValues(alpha: 0.25),
                    border: Border.all(
                      color: stage.color.withValues(alpha: 0.7),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: stage.color.withValues(alpha: stage.current ? 0.6 : 0.2),
                        blurRadius: stage.current ? 12 : 6,
                        spreadRadius: stage.current ? 2 : 0,
                      ),
                    ],
                  ),
                  child: stage.current
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : null,
                )
                    .animate()
                    .fadeIn(delay: delayBase.ms, duration: 400.ms)
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      delay: delayBase.ms,
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    ),
                // Connecting line (not on last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: lineWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            stage.color.withValues(alpha: 0.5),
                            // Blend to next stage color
                            (index < 3
                                    ? [AppColors.war, AppColors.primary, AppColors.accent, AppColors.peace][index + 1]
                                    : stage.color)
                                .withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: (delayBase + 150).ms, duration: 400.ms),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Stage card (right column) ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: stage.current
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            stage.color.withValues(alpha: 0.12),
                            stage.color.withValues(alpha: 0.03),
                          ],
                        )
                      : null,
                  color: stage.current
                      ? null
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: stage.current
                        ? stage.color.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                    width: stage.current ? 1.5 : 1,
                  ),
                  boxShadow: stage.current
                      ? [
                          BoxShadow(
                            color: stage.color.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Character avatar
                    Stack(
                      children: [
                        // Glow behind current stage avatar
                        if (stage.current)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: stage.color.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ColorFiltered(
                            colorFilter: stage.current
                                ? const ColorFilter.mode(
                                    Colors.transparent, BlendMode.multiply)
                                : ColorFilter.mode(
                                    Colors.black.withValues(alpha: 0.4),
                                    BlendMode.darken),
                            child: Image.asset(
                              stage.image,
                              width: avatarSize,
                              height: avatarSize,
                              cacheWidth: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // "YOU ARE HERE" indicator
                        if (stage.current)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: stage.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Day badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: stage.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stage.day.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: stage.color,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Stage name
                          Text(
                            stage.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: stage.current
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Tagline
                          Text(
                            stage.tagline,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow indicating forward progression
                    if (!isLast)
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: stage.color.withValues(alpha: 0.3),
                        size: 18,
                      ),
                    if (isLast)
                      Icon(
                        Icons.auto_awesome,
                        color: stage.color.withValues(alpha: 0.5),
                        size: 16,
                      ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: delayBase.ms, duration: 500.ms)
                  .slideX(
                    begin: 0.08,
                    end: 0,
                    delay: delayBase.ms,
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 18 — Personal Intention
  // -----------------------------------------------------------------------

  Widget _buildPersonalIntentionPage() {
    final placeholders =
        _intentionPlaceholders[_data.calculatedConflictType ??
                ConflictType.resentment] ??
            _intentionPlaceholders[ConflictType.resentment]!;
    final placeholder = placeholders[
        DateTime.now().second % placeholders.length];

    // Use MediaQuery to detect keyboard and adjust layout
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 100;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: keyboardVisible ? 12 : 24),
            if (!keyboardVisible) ...[
              Text(
                'In one sentence,\nwhat do you want\nto change?',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, duration: 500.ms),
              const SizedBox(height: 8),
              Text(
                'This becomes your guiding intention throughout the journey.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 28),
            ] else ...[
              Text(
                'Your intention',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _frostedCard(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _intentionController,
                focusNode: _intentionFocus,
                maxLines: keyboardVisible ? 4 : 3,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
            const SizedBox(height: _bottomCtaReserve),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 21 — Processing
  // -----------------------------------------------------------------------

  Widget _buildProcessingPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _sectionLabel('ANALYSING'),
            const SizedBox(height: 40),

            // Pulsing ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 100 + _pulseController.value * 20,
                  height: 100 + _pulseController.value * 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.3 + _pulseController.value * 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.1 + _pulseController.value * 0.1),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Icon(
                    _processingDone
                        ? Icons.check_rounded
                        : Icons.psychology_outlined,
                    color: AppColors.primary,
                    size: 40,
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            // Typing effect text — left-aligned for terminal feel
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Completed lines at reduced opacity
                  ..._processingCompletedLines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Opacity(
                        opacity: 0.5,
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ),
                    );
                  }),
                  // Currently typing line with cursor
                  if (_processingDisplayText.isNotEmpty || _processingTypingActive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _processingDisplayText,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (_processingTypingActive)
                            AnimatedBuilder(
                              animation: _cursorBlinkController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _cursorBlinkController.value,
                                  child: Container(
                                    width: 2,
                                    height: 18,
                                    margin: const EdgeInsets.only(left: 2),
                                    color: AppColors.primary,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 22 — Conflict Reveal (enhanced)
  // -----------------------------------------------------------------------

  Widget _buildConflictRevealPage() {
    final conflict = _data.calculatedConflictType ?? ConflictType.resentment;
    final name = _data.userName ?? 'friend';
    final duration = _data.conflictDuration ?? 'some time';
    final intensity = _data.conflictIntensity;
    final style = _data.conflictStyle ?? 'your way';

    final personalLine =
        "$name, you've been carrying this for $duration. "
        "At an intensity of $intensity/10, as a ${style.toLowerCase()}, "
        "this conflict has shaped how you see the world.";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pulsing background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 1.0 + t * 0.2,
                      colors: [
                        AppColors.war.withValues(alpha: 0.08 + t * 0.04),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 20,
              color: AppColors.war,
              opacity: 0.25,
              maxParticleSize: 2.5,
            ),
          ),

          // Scroll hint at bottom
          if (_revealShowDescription)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 60,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 28,
                      )
                          .animate(
                            onPlay: (c) => c.repeat(reverse: true),
                          )
                          .moveY(
                            begin: 0,
                            end: 6,
                            duration: 800.ms,
                            curve: Curves.easeInOut,
                          ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .then(delay: 4.seconds)
                .fadeOut(duration: 800.ms),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Section label
                  if (_revealShowContent)
                    _sectionLabel('YOUR INNER CONFLICT')
                        .animate()
                        .fadeIn(duration: 800.ms),

                  const SizedBox(height: 40),

                  // Conflict illustration + name
                  if (_revealShowName)
                    AnimatedBuilder(
                      animation: _revealScaleController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _revealScale.value,
                          child: Opacity(
                            opacity: _revealScaleController.value
                                .clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulseValue = _pulseController.value;
                              final conflictColor = AppColors.primary;
                              return SizedBox(
                                width: 320,
                                height: 320,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Concentric glow rings
                                    ...List.generate(3, (i) {
                                      final ringSize = 220.0 + (i * 40.0);
                                      return Container(
                                        width: ringSize,
                                        height: ringSize,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: conflictColor.withValues(
                                                alpha: (0.3 - i * 0.1) * pulseValue),
                                            width: 1.5,
                                          ),
                                        ),
                                      );
                                    }),
                                    // Inner pulsing glow
                                    Container(
                                      width: 220 + pulseValue * 20,
                                      height: 220 + pulseValue * 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.primary
                                                .withValues(alpha: 0.15),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Image.asset(
                                      'assets/images/conflicts/${_getConflictFileName(conflict)}.png',
                                      width: 200,
                                      height: 200,
                                      cacheWidth: 400,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                Color(0xFFE8C87A),
                                Color(0xFFD4A853),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              conflict.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 34,
                                    letterSpacing: 0.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Description
                  if (_revealShowDescription)
                    _frostedCard(
                      child: Text(
                        conflict.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.7,
                              fontSize: 15,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(
                            begin: 0.1, end: 0, duration: 800.ms),

                  const SizedBox(height: 24),

                  // Personalised line
                  if (_revealShowPersonal)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        personalLine,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(
                            begin: 0.08, end: 0, duration: 800.ms),

                  const SizedBox(height: 28),

                  // Character section
                  if (_revealShowCharacter)
                    Column(
                      children: [
                        Text(
                          'You begin as',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textTertiary,
                                letterSpacing: 1,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 130 +
                                      _pulseController.value * 12,
                                  height: 130 +
                                      _pulseController.value * 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.war.withValues(
                                            alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Image.asset(
                              'assets/images/characters/warrior.png',
                              width: 110,
                              height: 110,
                              cacheWidth: 220,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The Warrior',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppColors.war,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Still fighting, but aware',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                          duration: 800.ms,
                        ),

                  const SizedBox(height: 28),

                  // Journey message
                  if (_revealShowJourney)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.06),
                            AppColors.accent.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary
                                .withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            conflict.journeyMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppColors.primary,
                                  height: 1.7,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 15,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .slideY(
                            begin: 0.08, end: 0, duration: 800.ms),

                  const SizedBox(height: _bottomCtaReserve),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Page 23 — Ready to Commit
  // -----------------------------------------------------------------------

  Widget _buildReadyToCommitPage() {
    final intention = _data.personalIntention;
    final conflict = _data.calculatedConflictType ?? ConflictType.resentment;
    final name = _data.userName ?? 'friend';
    final duration = _data.conflictDuration ?? 'some time';

    return _adaptiveScroll(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
          const SizedBox(height: 24),

          _sectionLabel('THE MOMENT OF CHOICE')
              .animate()
              .fadeIn(duration: 500.ms),

          const SizedBox(height: 24),

          Text(
            'Are you ready to\nchoose peace?',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

          const SizedBox(height: 28),

          // Journey summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                // User name + conflict
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _commitStat(
                        Icons.local_fire_department_rounded,
                        'Conflict',
                        conflict.displayName,
                        AppColors.war,
                        imageAsset: conflict.runeAsset,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    Expanded(
                      child: _commitStat(
                        Icons.schedule_rounded,
                        'Carrying for',
                        duration,
                        AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                if (intention != null && intention.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'YOUR INTENTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"$intention"',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.05, end: 0, delay: 400.ms, duration: 600.ms),

          const SizedBox(height: 12),

          // Reassurance text
          Text(
            'Every journey starts with a single step.\nThis is yours.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 700.ms, duration: 500.ms),

          const Spacer(),

          // Yes card
          GestureDetector(
            onTap: () {
              _data.readyToCommit = true;
              _nextPage();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.favorite_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    "Yes \u2014 I'm ready",
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 900.ms, duration: 500.ms)
              .slideY(begin: 0.05, end: 0, delay: 900.ms, duration: 500.ms),

          const SizedBox(height: 28),
      ],
    );
  }

  Widget _commitStat(IconData icon, String label, String value, Color color,
      {String? imageAsset}) {
    return Column(
      children: [
        if (imageAsset != null)
          SizedBox(
            width: 36,
            height: 36,
            child: Image.asset(imageAsset, fit: BoxFit.contain, cacheHeight: 120),
          )
        else
          Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Page 23 — Celebration
  // -----------------------------------------------------------------------

  Widget _buildCelebrationPage() {
    final conflict = _data.calculatedConflictType ?? ConflictType.resentment;
    final name = _data.userName;
    final style = _data.conflictStyle ?? 'Warrior';
    final checkIn = _data.preferredCheckInTime ?? 'morning';
    final intention = _data.personalIntention;
    final intensity = _data.conflictIntensity;

    String checkInLabel() {
      if (checkIn == 'both') return 'Morning + Evening';
      return checkIn[0].toUpperCase() + checkIn.substring(1);
    }

    IconData checkInIcon() {
      if (checkIn == 'evening') return Icons.nightlight_round;
      if (checkIn == 'both') return Icons.brightness_6_outlined;
      return Icons.wb_sunny_outlined;
    }

    IconData styleIcon() {
      switch (style.toLowerCase()) {
        case 'avoider': return Icons.shield_outlined;
        case 'people-pleaser': return Icons.favorite_outline;
        case 'suppressor': return Icons.whatshot_outlined;
        default: return Icons.bolt_outlined; // fighter
      }
    }

    return Stack(
      children: [
        // Radial glow background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 1.1,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.04),
                  Colors.black,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),

        // Confetti particles
        if (_showConfetti)
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 60,
              color: AppColors.primary,
              opacity: 0.6,
              maxParticleSize: 5.0,
              minParticleSize: 1.0,
            ),
          ),

        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Section label
              _sectionLabel('PROFILE UNLOCKED')
                  .animate()
                  .fadeIn(duration: 600.ms),

              const SizedBox(height: 20),

              // Hero: Warrior character with pulsing golden aura
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing glow
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.1),
                      duration: const Duration(milliseconds: 2400),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.25),
                                  AppColors.primary.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Warrior image
                    Image.asset(
                      'assets/images/characters/warrior.png',
                      width: 180,
                      cacheWidth: 360,
                    ),
                    // Laurel/badge at the bottom
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFD4A853),
                              Color(0xFFE8C87A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'THE WARRIOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A0E1A),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 800.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    delay: 200.ms,
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 20),

              // Headline with name personalization
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFE8C87A),
                    Color(0xFFD4A853),
                    Color(0xFFF0D78C),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  name != null && name.isNotEmpty
                      ? "$name, your path is set."
                      : 'Your path is set.',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 700.ms)
                  .slideY(
                      begin: 0.15,
                      end: 0,
                      delay: 600.ms,
                      duration: 700.ms),

              const SizedBox(height: 8),

              Text(
                'Forged for your journey to peace.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 600.ms),

              const SizedBox(height: 28),

              // Stat cards grid (2x2) — each card cascades individually
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.psychology_outlined,
                      label: 'CONFLICT',
                      value: conflict.displayName,
                      color: AppColors.war,
                    )
                        .animate()
                        .fadeIn(delay: 1100.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 1100.ms,
                            duration: 600.ms)
                        .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                            delay: 1100.ms,
                            duration: 600.ms,
                            curve: Curves.elasticOut),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: styleIcon(),
                      label: 'YOUR STYLE',
                      value: style,
                      color: AppColors.primary,
                    )
                        .animate()
                        .fadeIn(delay: 1250.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 1250.ms,
                            duration: 600.ms)
                        .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                            delay: 1250.ms,
                            duration: 600.ms,
                            curve: Curves.elasticOut),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.show_chart,
                      label: 'INTENSITY',
                      value: '$intensity / 10',
                      color: intensity >= 7
                          ? AppColors.war
                          : intensity >= 4
                              ? AppColors.primary
                              : AppColors.peace,
                    )
                        .animate()
                        .fadeIn(delay: 1400.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 1400.ms,
                            duration: 600.ms)
                        .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                            delay: 1400.ms,
                            duration: 600.ms,
                            curve: Curves.elasticOut),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: checkInIcon(),
                      label: 'RITUAL',
                      value: checkInLabel(),
                      color: AppColors.accent,
                    )
                        .animate()
                        .fadeIn(delay: 1550.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 1550.ms,
                            duration: 600.ms)
                        .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                            delay: 1550.ms,
                            duration: 600.ms,
                            curve: Curves.elasticOut),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Personal intention quote card (if provided)
              if (intention != null && intention.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08),
                        AppColors.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'YOUR NORTH STAR',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        intention,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1500.ms, duration: 600.ms)
                    .slideY(
                        begin: 0.1,
                        end: 0,
                        delay: 1500.ms,
                        duration: 600.ms),

              if (intention != null && intention.trim().isNotEmpty)
                const SizedBox(height: 20),

              // Day 1 begins today — journey path preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.peace.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.peace,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DAY 1 BEGINS TODAY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.peace,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Journey path dots
                    Row(
                      children: [
                        _journeyMilestone('Warrior', 0, true),
                        _journeyConnector(),
                        _journeyMilestone('Wanderer', 7, false),
                        _journeyConnector(),
                        _journeyMilestone('Seeker', 30, false),
                        _journeyConnector(),
                        _journeyMilestone('Peacemaker', 90, false),
                      ],
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 1700.ms, duration: 600.ms)
                  .slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 1700.ms,
                      duration: 600.ms),

              const SizedBox(height: _bottomCtaReserve),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyMilestone(String label, int day, bool current) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: current ? 14 : 10,
            height: current ? 14 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.15),
              boxShadow: current
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: current
                  ? AppColors.primary
                  : AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            day == 0 ? 'Day 1' : 'Day $day',
            style: TextStyle(
              fontSize: 8,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _journeyConnector() {
    return Container(
      width: 20,
      height: 1,
      margin: const EdgeInsets.only(bottom: 28),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

}


class _JourneyStage {
  final String name;
  final String tagline;
  final String day;
  final Color color;
  final String image;
  final bool current;

  const _JourneyStage({
    required this.name,
    required this.tagline,
    required this.day,
    required this.color,
    required this.image,
    required this.current,
  });
}

class _NotAloneStory {
  final String quote;
  final String label;
  final String duration;
  final Color color;
  final IconData icon;

  const _NotAloneStory({
    required this.quote,
    required this.label,
    required this.duration,
    required this.color,
    required this.icon,
  });
}
