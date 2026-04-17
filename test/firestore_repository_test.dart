// Round-trip tests for model serialisation used by [FirestoreRepository].
//
// These tests don't touch Firestore — they only verify that each model's
// `toFirestore` / `fromFirestore` is a stable round-trip for the kinds of
// values we actually write (Timestamp dates, enum ints, etc.). That alone
// catches 95% of the pain when models drift.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_enemies/models/ai_context.dart';
import 'package:no_enemies/models/check_in.dart';
import 'package:no_enemies/models/conflict_type.dart';
import 'package:no_enemies/models/journal_entry.dart';
import 'package:no_enemies/models/user_profile.dart';

void main() {
  group('UserProfile Firestore round-trip', () {
    test('preserves all fields through toFirestore/fromFirestore', () {
      final created = DateTime(2026, 4, 17, 9, 12);
      final lastCheckIn = DateTime(2026, 4, 17, 7, 30);
      final profile = UserProfile(
        id: 'uid-abc123',
        primaryConflict: ConflictType.selfHatred,
        quizAnswers: const [0, 1, 2, 1, 0, 2],
        createdAt: created,
        totalDaysOfPeace: 14,
        currentStreak: 7,
        longestStreak: 12,
        peaceDays: 10,
        warDays: 4,
        lastCheckInDate: lastCheckIn,
        hasCompletedOnboarding: true,
        displayName: 'Joe',
        conflictTarget: 'Myself',
        conflictDuration: 'Years',
        conflictIntensity: 7,
        conflictStyle: 'Fighter',
        preferredCheckInTime: 'Morning',
        personalIntention: 'Treat myself with kindness',
        previousAttempts: const ['Therapy', 'Meditation'],
      );

      final map = profile.toFirestore();
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['lastCheckInDate'], isA<Timestamp>());
      expect(map['schemaVersion'], 1);

      final decoded = UserProfile.fromFirestore(map);
      expect(decoded.id, profile.id);
      expect(decoded.primaryConflict, profile.primaryConflict);
      expect(decoded.quizAnswers, profile.quizAnswers);
      expect(decoded.createdAt, profile.createdAt);
      expect(decoded.lastCheckInDate, profile.lastCheckInDate);
      expect(decoded.totalDaysOfPeace, profile.totalDaysOfPeace);
      expect(decoded.currentStreak, profile.currentStreak);
      expect(decoded.longestStreak, profile.longestStreak);
      expect(decoded.peaceDays, profile.peaceDays);
      expect(decoded.warDays, profile.warDays);
      expect(decoded.hasCompletedOnboarding, profile.hasCompletedOnboarding);
      expect(decoded.displayName, profile.displayName);
      expect(decoded.conflictTarget, profile.conflictTarget);
      expect(decoded.conflictDuration, profile.conflictDuration);
      expect(decoded.conflictIntensity, profile.conflictIntensity);
      expect(decoded.conflictStyle, profile.conflictStyle);
      expect(decoded.preferredCheckInTime, profile.preferredCheckInTime);
      expect(decoded.personalIntention, profile.personalIntention);
      expect(decoded.previousAttempts, profile.previousAttempts);
    });

    test('handles legacy ISO-8601 string dates (migration path)', () {
      final map = <String, dynamic>{
        'id': 'uid-xyz',
        'primaryConflict': 0,
        'quizAnswers': <int>[0, 1, 2],
        'createdAt': '2026-04-10T10:00:00.000',
        'hasCompletedOnboarding': true,
        'previousAttempts': <String>[],
      };
      final decoded = UserProfile.fromFirestore(map);
      expect(decoded.createdAt, DateTime.parse('2026-04-10T10:00:00.000'));
    });
  });

  group('CheckIn Firestore half round-trip', () {
    test('morning half preserves mood, intention, timestamp', () {
      final ts = DateTime(2026, 4, 17, 7, 32);
      final morning = CheckIn(
        id: 'abc',
        date: ts,
        type: CheckInType.morning,
        mood: Mood.calm,
        intention: "Don't react. Just notice.",
        aiPrompt: 'The weight is not protecting you.',
        isPeaceful: true,
      );
      final map = morning.toFirestoreHalf();
      expect(map['timestamp'], isA<Timestamp>());
      expect(map['mood'], Mood.calm.index);

      final decoded = CheckIn.fromFirestoreHalf(
        map,
        type: CheckInType.morning,
        fallbackDate: ts,
      );
      expect(decoded.id, morning.id);
      expect(decoded.date, morning.date);
      expect(decoded.mood, Mood.calm);
      expect(decoded.intention, morning.intention);
      expect(decoded.aiPrompt, morning.aiPrompt);
      expect(decoded.type, CheckInType.morning);
      expect(decoded.isPeaceful, true);
    });

    test('evening half preserves dimensions', () {
      final ts = DateTime(2026, 4, 17, 21, 45);
      final evening = CheckIn(
        id: 'def',
        date: ts,
        type: CheckInType.evening,
        mood: Mood.peaceful,
        reflectionAnswer: 'I caught myself and let it pass.',
        dimensions: const [
          DimensionRating(name: 'Acceptance', value: 0.7),
          DimensionRating(name: 'Kindness', value: 0.5),
        ],
      );
      final map = evening.toFirestoreHalf();
      final decoded = CheckIn.fromFirestoreHalf(
        map,
        type: CheckInType.evening,
        fallbackDate: ts,
      );
      expect(decoded.dimensions.length, 2);
      expect(decoded.dimensions.first.name, 'Acceptance');
      expect(decoded.dimensions.first.value, closeTo(0.7, 1e-9));
      expect(decoded.reflectionAnswer, evening.reflectionAnswer);
    });
  });

  group('JournalEntry Firestore round-trip', () {
    test('preserves content and derives wordCount', () {
      final entry = JournalEntry(
        id: 'j1',
        date: DateTime(2026, 4, 17),
        title: 'Something shifted',
        content: 'I noticed the tension in my shoulders and let go.',
        isBookmarked: true,
      );
      final map = entry.toFirestore();
      expect(map['wordCount'], 10);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
      expect(map['isBookmarked'], true);

      final decoded = JournalEntry.fromFirestore(map);
      expect(decoded.id, entry.id);
      expect(decoded.title, entry.title);
      expect(decoded.content, entry.content);
      expect(decoded.isBookmarked, true);
      expect(decoded.date, entry.date);
    });

    test('wordCount of empty content is 0', () {
      final entry = JournalEntry(
        id: 'j2',
        date: DateTime(2026, 4, 17),
        title: '',
        content: '   ',
      );
      expect(entry.wordCount, 0);
    });

    test('audio fields round-trip when present', () {
      final entry = JournalEntry(
        id: 'voice-1',
        date: DateTime(2026, 4, 17, 8, 0),
        title: 'Ten seconds of breath',
        content: 'I said more than I meant to and it felt good.',
        audioStoragePath: 'users/uid-xyz/audio/journal/voice-1.wav',
        audioDurationSeconds: 47,
      );
      final map = entry.toFirestore();
      expect(map['audioStoragePath'], 'users/uid-xyz/audio/journal/voice-1.wav');
      expect(map['audioDurationSeconds'], 47);

      final decoded = JournalEntry.fromFirestore(map);
      expect(decoded.audioStoragePath, entry.audioStoragePath);
      expect(decoded.audioDurationSeconds, 47);
      expect(decoded.hasAudio, true);
    });

    test('audio fields are omitted when null (old entry compat)', () {
      final entry = JournalEntry(
        id: 'text-1',
        date: DateTime(2026, 4, 17),
        title: 't',
        content: 'c',
      );
      final map = entry.toFirestore();
      expect(map.containsKey('audioStoragePath'), false);
      expect(map.containsKey('audioDurationSeconds'), false);

      final decoded = JournalEntry.fromFirestore(map);
      expect(decoded.hasAudio, false);
      expect(decoded.audioStoragePath, isNull);
      expect(decoded.audioDurationSeconds, isNull);
    });

    test('copyWith clearAudio drops audio fields', () {
      final entry = JournalEntry(
        id: 'voice-2',
        date: DateTime(2026, 4, 17),
        title: 't',
        content: 'c',
        audioStoragePath: 'users/u/audio/journal/voice-2.wav',
        audioDurationSeconds: 12,
      );
      final cleared = entry.copyWith(clearAudio: true);
      expect(cleared.hasAudio, false);
      expect(cleared.audioStoragePath, isNull);
      expect(cleared.audioDurationSeconds, isNull);
    });
  });

  group('AiContext rebuild counter', () {
    test('defaults checkInsSinceLastRebuild to 0', () {
      expect(AiContext.empty.checkInsSinceLastRebuild, 0);
      expect(const AiContext().checkInsSinceLastRebuild, 0);
    });

    test('copyWith bumps checkInsSinceLastRebuild without touching other fields',
        () {
      final ctx = AiContext(
        summary: 'Two weeks in, trending calmer.',
        themes: const ['self-compassion'],
        lastRebuiltAt: DateTime(2026, 4, 10),
        checkInsCount: 14,
        checkInsSinceLastRebuild: 3,
        tokenEstimate: 180,
      );
      final bumped = ctx.copyWith(checkInsSinceLastRebuild: 4);
      expect(bumped.checkInsSinceLastRebuild, 4);
      expect(bumped.summary, ctx.summary);
      expect(bumped.themes, ctx.themes);
      expect(bumped.lastRebuiltAt, ctx.lastRebuiltAt);
      expect(bumped.checkInsCount, ctx.checkInsCount);
      expect(bumped.tokenEstimate, ctx.tokenEstimate);
    });

    test('checkInsSinceLastRebuild survives Firestore round-trip', () {
      final ctx = AiContext(
        summary: 'Summary',
        themes: const ['a', 'b'],
        lastRebuiltAt: DateTime(2026, 4, 17, 7, 30),
        checkInsCount: 20,
        checkInsSinceLastRebuild: 7,
        tokenEstimate: 150,
      );
      final map = ctx.toFirestore();
      expect(map['checkInsSinceLastRebuild'], 7);
      final decoded = AiContext.fromFirestore(map);
      expect(decoded.checkInsSinceLastRebuild, 7);
      expect(decoded.checkInsCount, 20);
      expect(decoded.summary, ctx.summary);
    });

    test('fromFirestore tolerates missing checkInsSinceLastRebuild (migration)',
        () {
      // Docs written before the counter field existed must decode with 0.
      final map = <String, dynamic>{
        'summary': 'legacy',
        'themes': <String>[],
        'lastRebuiltAt': null,
        'checkInsCount': 10,
        'tokenEstimate': 100,
      };
      final decoded = AiContext.fromFirestore(map);
      expect(decoded.checkInsSinceLastRebuild, 0);
      expect(decoded.summary, 'legacy');
    });

    test('a freshly rebuilt AiContext resets checkInsSinceLastRebuild to 0', () {
      // Mirrors what AiMentorService.rebuildContext does: constructs a new
      // AiContext without passing checkInsSinceLastRebuild, so it must default
      // to 0. Guards against accidentally threading the bumped counter through.
      final rebuilt = AiContext(
        summary: 'new',
        themes: const [],
        lastRebuiltAt: DateTime(2026, 4, 17),
        checkInsCount: 20,
        tokenEstimate: 120,
      );
      expect(rebuilt.checkInsSinceLastRebuild, 0);
    });
  });
}
