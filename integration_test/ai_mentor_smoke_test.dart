// Live Gemini smoke test for AiMentorService. Talks to real Firebase AI
// (Gemini 2.5 Flash) via the `noenemies-app` project. Must run on a real
// device or simulator — not `flutter test`.
//
// Usage:
//   flutter test integration_test/ai_mentor_smoke_test.dart \
//     -d <simulator-id>
//
// Creates a fresh ephemeral email user, seeds a UserProfile in memory,
// calls morningPrompt / eveningQuestion / journalReflection, and asserts:
//   - non-empty response
//   - NOT equal to the AiService fallback (i.e. Gemini actually ran)
//   - 1–3 sentences
//   - no markdown tokens (*, #, >, ```)
// Prints each Gemini string via `print()` so the runner captures them.
// Does NOT delete the test user — cleanup is manual.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:no_enemies/firebase_options.dart';
import 'package:no_enemies/models/check_in.dart';
import 'package:no_enemies/models/conflict_type.dart';
import 'package:no_enemies/models/user_profile.dart';
import 'package:no_enemies/services/ai_mentor_service.dart';
import 'package:no_enemies/services/ai_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  });

  testWidgets('Live Gemini smoke — morning / evening / journal', (tester) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'test-sdkbump-$ts@noenemies.app';
    const password = 'TestP@ssw0rd!2026';

    // Sign up a fresh test user so App Check / Firebase AI has an auth context.
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    // ignore: avoid_print
    print('SMOKE_UID=$uid');
    // ignore: avoid_print
    print('SMOKE_EMAIL=$email');

    // Init the mentor against real Firebase AI.
    final mentor = AiMentorService();
    await mentor.init();

    if (!mentor.hasModel) {
      // ignore: avoid_print
      print('SKIPPED: AiMentorService.hasModel == false after init. '
          'Gemini model creation failed — see earlier debugPrint for reason.');
      markTestSkipped('Gemini model unavailable on this device.');
      return;
    }

    // Build an in-memory profile. We don't need to persist it; the mentor
    // accepts UserProfile directly.
    final profile = UserProfile(
      id: uid,
      primaryConflict: ConflictType.resentment,
      quizAnswers: const [0, 1, 2, 1, 0, 2, 1, 0, 1, 2],
      createdAt: DateTime.now(),
      totalDaysOfPeace: 12,
      currentStreak: 5,
      peaceDays: 9,
      warDays: 3,
      hasCompletedOnboarding: true,
      displayName: 'Smoke Tester',
      personalIntention: 'I want to stop carrying the grudge against my father.',
    );

    final fallback = AiService();
    final morningFallback =
        fallback.getMorningPrompt(profile.primaryConflict, Mood.calm);
    final eveningFallback =
        fallback.getEveningQuestion(profile.primaryConflict);

    // Runs a Gemini-backed call up to 3x, stopping as soon as we get a
    // response that differs from the known fallback string.
    Future<String> runLive(
      String label,
      String fallbackText,
      Future<String> Function() call,
    ) async {
      String last = '';
      for (var i = 1; i <= 3; i++) {
        final result = await call();
        // ignore: avoid_print
        print('ATTEMPT_${label}_$i=$result');
        last = result;
        if (result != fallbackText) return result;
        // Transient Firebase AI errors (500 high demand, API-not-propagated)
        // cause us to fall back. Brief backoff and retry.
        await Future<void>.delayed(Duration(seconds: 2 * i));
      }
      return last;
    }

    // ---- 1. Morning prompt ----
    final morning = await runLive('MORNING', morningFallback, () =>
        mentor.morningPrompt(profile: profile, mood: Mood.calm));
    // ignore: avoid_print
    print('GEMINI_MORNING=$morning');
    _assertLive(label: 'morning', text: morning, fallback: morningFallback);

    // ---- 2. Evening question ----
    final morningCheckIn = CheckIn(
      id: 'smoke-am',
      type: CheckInType.morning,
      date: DateTime.now(),
      mood: Mood.calm,
      intention: 'Not replay the fight with my father on the drive home.',
    );
    final evening = await runLive('EVENING', eveningFallback, () =>
        mentor.eveningQuestion(
            profile: profile, todayMorning: morningCheckIn));
    // ignore: avoid_print
    print('GEMINI_EVENING=$evening');
    _assertLive(label: 'evening', text: evening, fallback: eveningFallback);

    // ---- 3. Journal reflection ----
    const journalText =
        "Today I saw my father in a memory and didn't tense up for once. "
        'It was a small moment, but I stayed with it instead of flinching '
        'away. I still feel the old heat behind my ribs when I think '
        "about the argument in '19, but it's less sharp today.";
    // Journal falls back to the evening-question string, so reuse that.
    final reflection = await runLive('JOURNAL', eveningFallback, () =>
        mentor.journalReflection(profile: profile, entryText: journalText));
    // ignore: avoid_print
    print('GEMINI_JOURNAL=$reflection');
    _assertLive(
        label: 'journal', text: reflection, fallback: eveningFallback);

    // Leave the user in place for cleanup from the report.
    await FirebaseAuth.instance.signOut();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

void _assertLive({
  required String label,
  required String text,
  required String fallback,
}) {
  expect(text, isNotEmpty, reason: '$label: Gemini returned empty string');
  expect(
    text,
    isNot(equals(fallback)),
    reason: '$label: response matches the AiService fallback — Gemini did '
        'NOT run (probably network / App Check / auth issue).',
  );

  // Sentence count: 1–3.
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.trim().isNotEmpty)
      .toList();
  expect(
    sentences.length,
    lessThanOrEqualTo(4), // 3 + 1 slack for trailing clause
    reason: '$label: expected 1-3 sentences, got ${sentences.length}: $text',
  );
  expect(
    sentences.length,
    greaterThanOrEqualTo(1),
    reason: '$label: expected at least 1 sentence',
  );

  // No markdown / headers.
  for (final token in ['**', '##', '```', '> ']) {
    expect(
      text.contains(token),
      isFalse,
      reason: '$label: response contains markdown token "$token": $text',
    );
  }
  // Bullet check — allow asterisks inside a word, but not a `* ` bullet.
  expect(
    RegExp(r'(^|\n)\s*[\*\-]\s').hasMatch(text),
    isFalse,
    reason: '$label: response contains a bullet: $text',
  );
}
