import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_context.dart';
import '../models/check_in.dart';
import '../models/user_profile.dart';
import 'ai_service.dart';
import 'firestore_repository.dart';

/// Real AI mentor backed by Gemini 2.5 Flash via `firebase_ai` (Gemini
/// Developer API). Falls back to the hand-written Dart strings in
/// [AiService] when Gemini is unavailable, throws, or returns empty.
///
/// Phase 1C scope:
/// - Morning prompts
/// - Evening reflection questions
/// - Optional journal reflection
/// - Rolling context summary stored at `users/{uid}/ai/context`
///
/// Out of scope: streaming, function-calling, voice. See
/// `docs/plans/backend/firebase-integration.md` §7.
class AiMentorService {
  AiMentorService({
    AiService? fallback,
    GenerativeModel? model,
  })  : _fallback = fallback ?? AiService(),
        _modelOverride = model;

  final AiService _fallback;

  /// When set (tests), skips [init] and uses this model directly.
  final GenerativeModel? _modelOverride;

  GenerativeModel? _model;
  bool _initialized = false;

  /// The fallback library — exposed so [JourneyProvider] can keep its
  /// synchronous hooks (e.g. `getPeaceMission`) without needing a network
  /// call for cheap content.
  AiService get fallback => _fallback;

  /// Model + system prompt config. Matches the plan's voice guidelines:
  /// calm, kind, direct. No diagnoses, no markdown/emojis, 1–3 sentences.
  static const String _modelName = 'gemini-2.5-flash';

  static const String _systemPrompt = '''
You are a calm, kind, direct mentor helping someone work through inner conflict.

Voice rules:
- 1 to 3 sentences. Short is strong.
- No markdown, no emojis, no headers, no lists.
- Speak to the user as "you". Never use their name.
- Never diagnose. Never prescribe treatment.
- Never be saccharine, preachy, or performatively spiritual.
- Reference the user's context (conflict type, mood, intention, history) with a light touch.

If the user seems to be in crisis (suicidal ideation, self-harm, severe panic),
gently suggest they reach out to a mental health professional or crisis line,
in one sentence. Do not lecture. Do not refuse other content.

You are not their therapist. You are a calm voice beside them on a long journey.
''';

  /// Initialize once at app startup, after `Firebase.initializeApp`.
  ///
  /// Safe to call more than once — subsequent calls are no-ops.
  /// App Check is activated with a debug provider in dev builds so the
  /// service is compatible when enforcement is eventually enabled on the
  /// Firebase console (that's a launch-time task, not done here).
  Future<void> init() async {
    if (_initialized || _modelOverride != null) {
      _initialized = true;
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e, st) {
      // Non-fatal — without App Check, calls still work until enforcement is
      // turned on in the Firebase console. Log so we can notice drift in dev.
      debugPrint('[AiMentorService] App Check activate failed: $e\n$st');
    }

    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        systemInstruction: Content.text(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          // 400 leaves comfortable headroom for the 1–3 sentence outputs we
          // ask for. Live smoke testing with 200 produced truncated responses
          // on Gemini 2.5 Flash ("Reflecting on your morning intention,") —
          // the model was spending budget we couldn't see before emitting
          // anything visible. See the thinkingConfig note below.
          maxOutputTokens: 400,
          // Gemini 2.5 Flash spends "thinking" tokens before the visible
          // output, and those tokens count against maxOutputTokens. For our
          // short, tone-constrained creative prompts (1–3 sentences, specific
          // voice), thinking is overkill and eats the budget. Disable it so
          // the whole 400-token window is available for the actual answer.
          thinkingConfig: ThinkingConfig.withThinkingBudget(0),
        ),
      );
    } catch (e, st) {
      debugPrint(
        '[AiMentorService] model init failed — falling back to Dart '
        'strings. Error: $e\n$st',
      );
      _model = null;
    }

    _initialized = true;
  }

  bool get hasModel => _modelOverride != null || _model != null;

  GenerativeModel? get _activeModel => _modelOverride ?? _model;

  // ---------------------------------------------------------------------------
  // Prompt builders
  // ---------------------------------------------------------------------------

  String _contextBlock({
    required UserProfile profile,
    required AiContext? context,
  }) {
    final lines = <String>[];
    lines.add('Conflict focus: ${profile.primaryConflict.displayName}');
    if ((profile.personalIntention ?? '').isNotEmpty) {
      lines.add('Their stated intention: ${profile.personalIntention}');
    }
    if (profile.currentStreak > 0) {
      lines.add('Current peace streak: ${profile.currentStreak} days');
    }
    if (profile.totalDaysOfPeace > 0) {
      lines.add('Total days of peace: ${profile.totalDaysOfPeace}');
    }
    if (context != null && !context.isEmpty) {
      lines.add('Rolling memory: ${context.summary}');
    }
    return lines.join('\n');
  }

  String _recentCheckInsBlock(List<CheckIn> checkIns) {
    if (checkIns.isEmpty) return '';
    final slice = checkIns.take(7).toList();
    final lines = slice.map((c) {
      final type = c.type == CheckInType.morning ? 'morning' : 'evening';
      final snippet = c.type == CheckInType.morning
          ? (c.intention ?? '').trim()
          : (c.reflectionAnswer ?? '').trim();
      final trimmed = snippet.length > 80 ? '${snippet.substring(0, 77)}…' : snippet;
      return '- $type / ${c.mood.label}${trimmed.isEmpty ? '' : ': $trimmed'}';
    });
    return 'Last 7 days:\n${lines.join('\n')}';
  }

  // ---------------------------------------------------------------------------
  // Public prompt methods — each one has a guaranteed fallback.
  // ---------------------------------------------------------------------------

  Future<String> morningPrompt({
    required UserProfile profile,
    required Mood mood,
    AiContext? contextSummary,
    List<CheckIn> last7Days = const [],
  }) async {
    final model = _activeModel;
    if (model == null) {
      return _fallback.getMorningPrompt(profile.primaryConflict, mood);
    }
    final context = _contextBlock(profile: profile, context: contextSummary);
    final recent = _recentCheckInsBlock(last7Days);
    final prompt = '''
The user just opened the app for their morning check-in. They feel: ${mood.label}.

${context.isEmpty ? '' : context}
${recent.isEmpty ? '' : '\n$recent'}

Write ONE short morning prompt (1–2 sentences). Ground it in their current
mood and, if relevant, their stated intention or recent pattern. Do not
start with "Good morning". Do not use their name.
''';
    return _safeGenerate(
      prompt,
      fallback: () =>
          _fallback.getMorningPrompt(profile.primaryConflict, mood),
    );
  }

  Future<String> eveningQuestion({
    required UserProfile profile,
    CheckIn? todayMorning,
    AiContext? contextSummary,
  }) async {
    final model = _activeModel;
    if (model == null) {
      return _fallback.getEveningQuestion(profile.primaryConflict);
    }
    final context = _contextBlock(profile: profile, context: contextSummary);
    final morningLine = todayMorning == null
        ? ''
        : 'This morning they felt ${todayMorning.mood.label} and set the '
            'intention: "${(todayMorning.intention ?? '').trim()}".';
    final prompt = '''
The user is opening the app for their evening reflection.

${context.isEmpty ? '' : context}
${morningLine.isEmpty ? '' : '\n$morningLine'}

Write ONE reflection question (1 sentence). If they set a morning intention,
reference it gently. The question should invite honesty, not performance.
''';
    return _safeGenerate(
      prompt,
      fallback: () => _fallback.getEveningQuestion(profile.primaryConflict),
    );
  }

  Future<String> journalReflection({
    required UserProfile profile,
    required String entryText,
    AiContext? contextSummary,
  }) async {
    final model = _activeModel;
    if (model == null) {
      return _fallback.getEveningQuestion(profile.primaryConflict);
    }
    final context = _contextBlock(profile: profile, context: contextSummary);
    final truncated =
        entryText.length > 2000 ? entryText.substring(0, 2000) : entryText;
    final prompt = '''
The user just wrote a journal entry. Reflect on it briefly.

${context.isEmpty ? '' : context}

Their entry:
"""
$truncated
"""

Write a 1–3 sentence reflection. You may end with at most one question —
only if it would genuinely help them go deeper. No summaries of what they
wrote. No advice stacks.
''';
    return _safeGenerate(
      prompt,
      fallback: () => _fallback.getEveningQuestion(profile.primaryConflict),
    );
  }

  // ---------------------------------------------------------------------------
  // Rolling context summary
  // ---------------------------------------------------------------------------

  /// Rebuild the rolling context from the last 20 check-ins. Persists the
  /// result to `users/{uid}/ai/context` via [repo]. Silent failure — returns
  /// the existing context unchanged if Gemini is unreachable.
  Future<AiContext> rebuildContext({
    required FirestoreRepository repo,
    required UserProfile profile,
    required List<CheckIn> recentCheckIns,
  }) async {
    final model = _activeModel;
    if (model == null || recentCheckIns.isEmpty) {
      return repo.loadAiContext();
    }
    final slice = recentCheckIns.take(20).toList();
    final transcript = slice.map((c) {
      final type = c.type == CheckInType.morning ? 'AM' : 'PM';
      final text = c.type == CheckInType.morning
          ? (c.intention ?? '')
          : (c.reflectionAnswer ?? '');
      return '$type / ${c.mood.label}: ${text.trim()}';
    }).join('\n');
    final intention = (profile.personalIntention ?? '').trim();

    final prompt = '''
Summarize this user's journey in 3–4 sentences. Capture recurring themes,
wins, and blockers. Third person, neutral tone. No names. Max 400 characters.

Conflict focus: ${profile.primaryConflict.displayName}.
${intention.isEmpty ? '' : 'Stated intention: "$intention".'}

Recent check-ins:
$transcript

Return only the summary. No preamble.
''';

    try {
      final res = await model.generateContent([Content.text(prompt)]);
      final text = _extractText(res);
      if (text == null || text.trim().isEmpty) {
        return repo.loadAiContext();
      }
      final trimmed =
          text.length > 500 ? text.substring(0, 500) : text;
      final rebuilt = AiContext(
        summary: trimmed.trim(),
        themes: const [],
        lastRebuiltAt: DateTime.now(),
        checkInsCount: slice.length,
        tokenEstimate: (trimmed.length / 4).round(),
      );
      await repo.saveAiContext(rebuilt);
      return rebuilt;
    } catch (e, st) {
      debugPrint('[AiMentorService] rebuildContext failed: $e\n$st');
      return repo.loadAiContext();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Run a generation with try/catch and fall back to the Dart string library
  /// on any failure. Never throws. Never returns an empty string.
  Future<String> _safeGenerate(
    String prompt, {
    required String Function() fallback,
  }) async {
    final model = _activeModel;
    if (model == null) return fallback();
    try {
      final res = await model.generateContent([Content.text(prompt)]);
      final text = _extractText(res);
      if (text == null || text.trim().isEmpty) {
        debugPrint('[AiMentorService] empty response — using fallback');
        return fallback();
      }
      return text.trim();
    } catch (e, st) {
      debugPrint('[AiMentorService] generateContent failed: $e\n$st');
      return fallback();
    }
  }

  String? _extractText(GenerateContentResponse res) {
    try {
      return res.text;
    } catch (_) {
      return null;
    }
  }
}
