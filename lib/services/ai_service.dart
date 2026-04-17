import '../models/conflict_type.dart';
import '../models/check_in.dart';

/// Mock AI service that returns pre-written prompts and reflections
/// based on conflict type and mood. Will be replaced with real
/// Claude/Gemini API calls in Phase 2.
class AiService {
  /// Returns a morning prompt based on the user's conflict type and mood.
  String getMorningPrompt(ConflictType conflictType, Mood mood) {
    final prompts = _morningPrompts[conflictType] ?? _defaultMorningPrompts;
    switch (mood) {
      case Mood.struggling:
      case Mood.uneasy:
        return prompts[0];
      case Mood.neutral:
        return prompts[1];
      case Mood.calm:
      case Mood.peaceful:
        return prompts[2];
    }
  }

  /// Returns an evening reflection question.
  String getEveningQuestion(ConflictType conflictType) {
    final questions = _eveningQuestions[conflictType] ?? _defaultEveningQuestions;
    final index = DateTime.now().day % questions.length;
    return questions[index];
  }

  /// Returns a daily peace mission.
  String getPeaceMission(ConflictType conflictType) {
    final missions = _peaceMissions[conflictType] ?? _defaultMissions;
    final index = DateTime.now().day % missions.length;
    return missions[index];
  }

  // --- Mock Data ---

  static const _defaultMorningPrompts = [
    'Take a deep breath. Today is a new opportunity for peace, even if '
        'yesterday was hard.',
    'You\'re in a steady place. What small act of peace can you commit to today?',
    'You\'re carrying calm energy. How can you share that peace with someone today?',
  ];

  static const Map<ConflictType, List<String>> _morningPrompts = {
    ConflictType.resentment: [
      'That weight you\'re carrying — it\'s not protecting you. What would '
          'it feel like to set it down, just for today?',
      'Think of someone you\'re holding something against. Can you find one '
          'thing about them that\'s simply human?',
      'Your peace is growing stronger than your grudges. Notice how much '
          'lighter you feel.',
    ],
    ConflictType.selfHatred: [
      'The voice being cruel to you right now — would you speak that way to '
          'someone you love? You deserve that same kindness.',
      'You don\'t need to earn the right to exist peacefully. What would you '
          'tell your younger self today?',
      'Self-compassion is a muscle, and yours is getting stronger. What are '
          'you proud of about yourself?',
    ],
    ConflictType.comparison: [
      'Their highlight reel isn\'t your behind-the-scenes. What\'s one thing '
          'in YOUR life that genuinely brings you joy?',
      'Today, practise celebrating someone else\'s win without measuring it '
          'against your own.',
      'You\'re on your own timeline. What progress have YOU made recently '
          'that has nothing to do with anyone else?',
    ],
    ConflictType.workplace: [
      'Before you step into work today, remember: you are not your job title, '
          'your performance review, or your inbox.',
      'Set one boundary today that protects your peace at work. Just one.',
      'You\'re learning to separate who you are from what happens at work. '
          'That\'s real strength.',
    ],
    ConflictType.relationship: [
      'The people who trigger us most are often the ones we love most. '
          'What need of yours isn\'t being met right now?',
      'Today, try listening to understand rather than to respond. '
          'What might you hear differently?',
      'Your relationships are reflecting your growing peace. '
          'Notice the moments of genuine connection today.',
    ],
    ConflictType.identity: [
      'You don\'t have to have it all figured out today. Who are you '
          'right now, in this moment? That person is enough.',
      'The gap between who you are and who you want to be isn\'t a failure — '
          'it\'s direction. What small step can you take today?',
      'You\'re becoming more yourself every day. What feels most authentic '
          'about your life right now?',
    ],
    ConflictType.grief: [
      'It\'s okay to not be okay. Your grief is a measure of your love. '
          'What would bring you a moment of comfort today?',
      'You can hold both sadness and peace at the same time. '
          'They\'re not opposites — they\'re companions.',
      'Your loss has shaped you, but it hasn\'t defined you. '
          'What would the person you lost want for you today?',
    ],
    ConflictType.addiction: [
      'Today, you only need to get through today. One moment, one choice, '
          'one breath at a time.',
      'The urge doesn\'t define you. It\'s a wave — it rises and it passes. '
          'What can you anchor to right now?',
      'Every peaceful moment you\'ve chosen is proof of your strength. '
          'You\'re building something real.',
    ],
  };

  static const _defaultEveningQuestions = [
    'What moment today challenged your peace? How did you respond?',
    'Did you encounter any conflict today? What triggered it?',
    'What are you grateful for today, even if it was a hard day?',
  ];

  static const Map<ConflictType, List<String>> _eveningQuestions = {
    ConflictType.resentment: [
      'Did any old wounds surface today? How did you handle them?',
      'Was there a moment where you chose to let go instead of hold on?',
      'Think of someone you\'re carrying resentment toward. Has anything '
          'shifted, even slightly?',
    ],
    ConflictType.selfHatred: [
      'How did you speak to yourself today? Were there moments of kindness?',
      'What\'s one thing you did today that you can genuinely acknowledge?',
      'Did the inner critic get loud today? What was it really trying to say?',
    ],
    ConflictType.comparison: [
      'Did you catch yourself comparing today? What was the trigger?',
      'Name one thing you accomplished today that has nothing to do with anyone else.',
      'Were you able to celebrate someone else without diminishing yourself?',
    ],
    ConflictType.workplace: [
      'How did you protect your peace at work today?',
      'Did you carry any work stress home? What can you release right now?',
      'What boundary did you set or wish you had set today?',
    ],
    ConflictType.relationship: [
      'How did your interactions with loved ones feel today?',
      'Was there a moment of genuine connection? What made it possible?',
      'Did any conflicts arise? What was really underneath them?',
    ],
    ConflictType.identity: [
      'Did you feel aligned with who you want to be today? Why or why not?',
      'What moment today felt most authentically "you"?',
      'Where did you feel pressure to be someone else? How did you respond?',
    ],
    ConflictType.grief: [
      'How present was your grief today? Did it surprise you at any point?',
      'What memory brought you comfort today?',
      'Were you able to sit with your feelings without fighting them?',
    ],
    ConflictType.addiction: [
      'How many peaceful choices did you make today?',
      'Were there moments of temptation? What helped you through them?',
      'What are you most proud of about today?',
    ],
  };

  static const _defaultMissions = [
    'Take three deep breaths before responding to anything that triggers you.',
    'Write down one thing you\'re grateful for that you usually take for granted.',
    'Spend five minutes in silence, observing your thoughts without judging them.',
  ];

  static const Map<ConflictType, List<String>> _peaceMissions = {
    ConflictType.resentment: [
      'Write a letter you\'ll never send to someone you resent. Say everything. Then close it.',
      'Find one positive memory with someone you\'re angry at. Sit with it for two minutes.',
      'When resentment rises today, place your hand on your heart and say: "I choose peace."',
    ],
    ConflictType.selfHatred: [
      'Look in the mirror and say one genuinely kind thing to yourself. Mean it.',
      'Write down three things your body has done for you today. Thank it.',
      'When the inner critic speaks, respond as you would to a friend. Out loud.',
    ],
    ConflictType.comparison: [
      'Unfollow or mute one account that triggers comparison. Just for today.',
      'Message someone you admire and tell them what you appreciate. No jealousy, just appreciation.',
      'Write down three things you have that money can\'t buy.',
    ],
    ConflictType.workplace: [
      'Take a 5-minute walk at some point during work. Leave your phone behind.',
      'Before your first meeting, set a private intention: "I am more than my productivity."',
      'At the end of the workday, physically close your laptop and say: "Enough."',
    ],
    ConflictType.relationship: [
      'Tell someone you love one specific thing you appreciate about them. Be detailed.',
      'When tension rises, pause for 10 seconds before speaking.',
      'Ask someone close to you: "What do you need from me right now?" and truly listen.',
    ],
    ConflictType.identity: [
      'Do one thing today purely because you enjoy it — not because it\'s productive or impressive.',
      'Write down: "I am ___" and fill it with who you ARE, not who you think you should be.',
      'Spend 5 minutes sitting with the question: "What would I do if nobody was watching?"',
    ],
    ConflictType.grief: [
      'Light a candle (real or imagined) for someone you\'ve lost. Sit with the flame for one minute.',
      'Share one memory of your loss with someone you trust.',
      'Write a short note to whoever or whatever you\'ve lost. Say what you wish you\'d said.',
    ],
    ConflictType.addiction: [
      'When the urge rises, drink a glass of cold water slowly. Feel every sip.',
      'Call or text one person who supports your journey. You don\'t have to say much.',
      'Write down the three things that matter most to you. Read them when it gets hard.',
    ],
  };
}
