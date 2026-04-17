// Unit tests for [AiMentorService] — specifically the fallback path.
//
// We do NOT hit the network here. The test uses the no-model constructor,
// which causes every async prompt method to delegate to the hand-written
// Dart string library in [AiService]. That is the critical correctness
// invariant for Phase 1C: the user NEVER sees a failure or blank prompt
// when Gemini is unavailable.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_enemies/models/ai_context.dart';
import 'package:no_enemies/models/check_in.dart';
import 'package:no_enemies/models/conflict_type.dart';
import 'package:no_enemies/models/user_profile.dart';
import 'package:no_enemies/services/ai_mentor_service.dart';
import 'package:no_enemies/services/ai_service.dart';

void main() {
  group('AiMentorService fallback behaviour', () {
    late AiMentorService mentor;
    late AiService fallback;

    setUp(() {
      fallback = AiService();
      // No model passed → _activeModel is null → every call should fall
      // back to the Dart string library.
      mentor = AiMentorService(fallback: fallback);
    });

    UserProfile buildProfile({String intention = 'Treat myself kindly'}) {
      return UserProfile(
        id: 'uid-test',
        primaryConflict: ConflictType.selfHatred,
        quizAnswers: const [0, 1, 2, 1, 0, 2],
        createdAt: DateTime(2026, 4, 1),
        currentStreak: 5,
        totalDaysOfPeace: 12,
        peaceDays: 9,
        warDays: 3,
        hasCompletedOnboarding: true,
        displayName: 'Test',
        personalIntention: intention,
      );
    }

    test('morningPrompt returns a non-empty fallback when model is missing',
        () async {
      final result = await mentor.morningPrompt(
        profile: buildProfile(),
        mood: Mood.uneasy,
      );
      expect(result, isNotEmpty);
      // It should match one of the fallback library's canned lines.
      expect(
        result,
        equals(fallback.getMorningPrompt(
          ConflictType.selfHatred,
          Mood.uneasy,
        )),
      );
    });

    test('eveningQuestion returns a non-empty fallback when model is missing',
        () async {
      final result = await mentor.eveningQuestion(
        profile: buildProfile(),
        todayMorning: null,
      );
      expect(result, isNotEmpty);
      expect(
        result,
        equals(fallback.getEveningQuestion(ConflictType.selfHatred)),
      );
    });

    test('journalReflection returns a non-empty fallback when model is missing',
        () async {
      final result = await mentor.journalReflection(
        profile: buildProfile(),
        entryText: 'Today I noticed my inner critic was loud.',
      );
      expect(result, isNotEmpty);
    });

    test('rolling-context-aware prompts still fall back cleanly', () async {
      final ctx = const AiContext(
        summary:
            'User has been focused on self-compassion for two weeks with '
            'modest consistency.',
        themes: ['self-compassion'],
      );
      final result = await mentor.morningPrompt(
        profile: buildProfile(),
        mood: Mood.peaceful,
        contextSummary: ctx,
        last7Days: const [],
      );
      expect(result, isNotEmpty);
    });

    test('hasModel is false when no model is provided', () {
      expect(mentor.hasModel, isFalse);
    });

    test('transcribeAudio returns empty string when no model is configured',
        () async {
      // No Firebase model → fallback. The UI relies on this returning '' so
      // the voice flow shows an error state rather than throwing.
      final tmp = File(
        '${Directory.systemTemp.path}/no_enemies_transcribe_test.wav',
      );
      // Don't actually create the file — transcribeAudio must short-circuit
      // on model==null before ever reading bytes.
      final result = await mentor.transcribeAudio(tmp);
      expect(result, '');
    });

    test('init() never throws, even without Firebase', () async {
      // If firebase_ai isn't initialized (no Firebase app), init() must
      // swallow the error and leave the service in fallback mode. This is
      // the guarantee the UI relies on.
      var didThrow = false;
      try {
        await mentor.init();
      } catch (_) {
        didThrow = true;
      }
      expect(didThrow, isFalse);
      expect(mentor.hasModel, isFalse);
    });
  });

  group('AiMentorService fallback preserves mood ordering', () {
    late AiMentorService mentor;
    late AiService fallback;

    setUp(() {
      fallback = AiService();
      mentor = AiMentorService(fallback: fallback);
    });

    test('different moods produce different fallback prompts', () async {
      final profile = UserProfile(
        id: 'uid-test',
        primaryConflict: ConflictType.grief,
        quizAnswers: const [0, 1, 2],
        createdAt: DateTime(2026, 4, 1),
        hasCompletedOnboarding: true,
      );

      final struggling = await mentor.morningPrompt(
        profile: profile,
        mood: Mood.struggling,
      );
      final peaceful = await mentor.morningPrompt(
        profile: profile,
        mood: Mood.peaceful,
      );

      expect(struggling, isNotEmpty);
      expect(peaceful, isNotEmpty);
      expect(struggling, isNot(equals(peaceful)));
    });
  });
}
