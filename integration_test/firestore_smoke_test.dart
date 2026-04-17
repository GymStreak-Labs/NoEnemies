// Phase 1B smoke test: drives the real FirestoreRepository against the
// real `noenemies-app` Firebase project on a connected device/simulator.
//
// Usage:
//   flutter test integration_test/firestore_smoke_test.dart \
//     -d <simulator-id>
//
// Creates a fresh ephemeral email user, writes a profile + morning check-in
// + journal entry, reads them back through the streams, asserts equality,
// signs out, signs back in, and verifies the data is still there. Does NOT
// delete the test user — cleanup is manual (see report).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:no_enemies/firebase_options.dart';
import 'package:no_enemies/models/check_in.dart';
import 'package:no_enemies/models/conflict_type.dart';
import 'package:no_enemies/models/journal_entry.dart';
import 'package:no_enemies/models/user_profile.dart';
import 'package:no_enemies/services/firestore_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // Force a clean slate before each test run.
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  });

  testWidgets('Phase 1B Firestore round-trip', (tester) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'test-phase1b-$ts@noenemies.app';
    const password = 'TestP@ssw0rd!2026';

    // ---- Sign up ----
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    // Used for the final cleanup report.
    // ignore: avoid_print
    print('SMOKE_UID=$uid');
    // ignore: avoid_print
    print('SMOKE_EMAIL=$email');
    expect(uid, isNotEmpty);

    final repo = FirestoreRepository(uid: uid);

    // ---- Write profile ----
    final now = DateTime.now();
    final profile = UserProfile(
      id: uid,
      primaryConflict: ConflictType.selfHatred,
      quizAnswers: const [0, 1, 2, 1, 0, 2, 1, 0, 1, 2],
      createdAt: now,
      totalDaysOfPeace: 3,
      currentStreak: 3,
      peaceDays: 2,
      warDays: 1,
      hasCompletedOnboarding: true,
      displayName: 'Smoke Tester',
      personalIntention: 'Phase 1B round-trip.',
      conflictIntensity: 6,
      conflictTarget: 'self',
      conflictDuration: 'years',
      conflictStyle: 'withdraw',
      preferredCheckInTime: 'morning',
      previousAttempts: const ['journaling', 'therapy'],
    );
    await repo.saveProfile(profile);

    // ---- Write morning check-in ----
    final morning = CheckIn(
      id: 'morning-$ts',
      date: now,
      type: CheckInType.morning,
      mood: Mood.calm,
      intention: 'Stay grounded today.',
      isPeaceful: true,
    );
    await repo.saveCheckIn(morning);

    // ---- Write journal entry ----
    final journal = JournalEntry(
      id: 'journal-$ts',
      title: 'Smoke entry',
      content: 'This is a Phase 1B smoke-test journal entry, short and sweet.',
      date: now,
      isBookmarked: true,
    );
    await repo.saveJournalEntry(journal);

    // ---- One-shot reads ----
    final loadedProfile = await repo.loadProfile();
    expect(loadedProfile, isNotNull);
    expect(loadedProfile!.id, uid);
    expect(loadedProfile.primaryConflict, ConflictType.selfHatred);
    expect(loadedProfile.displayName, 'Smoke Tester');
    expect(loadedProfile.personalIntention, 'Phase 1B round-trip.');
    expect(loadedProfile.previousAttempts,
        containsAll(<String>['journaling', 'therapy']));
    expect(loadedProfile.quizAnswers.length, 10);

    final loadedCheckIns = await repo.loadCheckIn(now);
    expect(loadedCheckIns.length, 1);
    expect(loadedCheckIns.first.mood, Mood.calm);
    expect(loadedCheckIns.first.intention, 'Stay grounded today.');
    expect(loadedCheckIns.first.type, CheckInType.morning);

    final loadedJournal = await repo.listJournalEntries();
    expect(loadedJournal, isNotEmpty);
    final match =
        loadedJournal.firstWhere((j) => j.id == 'journal-$ts');
    expect(match.title, 'Smoke entry');
    expect(match.isBookmarked, isTrue);
    expect(match.wordCount, greaterThan(0));

    // ---- Stream sanity check (first event has data) ----
    final profileStreamFirst = await repo.streamProfile().firstWhere(
          (p) => p != null,
          orElse: () => null,
        );
    expect(profileStreamFirst, isNotNull);
    expect(profileStreamFirst!.displayName, 'Smoke Tester');

    final journalStreamFirst = await repo
        .streamJournalEntries()
        .firstWhere((l) => l.any((j) => j.id == 'journal-$ts'));
    expect(journalStreamFirst, isNotEmpty);

    final checkInsStreamFirst = await repo
        .streamRecentCheckIns()
        .firstWhere((l) => l.any((c) => c.id == 'morning-$ts'));
    expect(checkInsStreamFirst, isNotEmpty);

    // ---- Sign out, sign back in, verify data still there ----
    await FirebaseAuth.instance.signOut();
    expect(FirebaseAuth.instance.currentUser, isNull);

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    expect(FirebaseAuth.instance.currentUser?.uid, uid);

    final repo2 = FirestoreRepository(uid: uid);
    final reloadedProfile = await repo2.loadProfile();
    expect(reloadedProfile, isNotNull);
    expect(reloadedProfile!.displayName, 'Smoke Tester');

    final reloadedJournal = await repo2.listJournalEntries();
    expect(reloadedJournal.any((j) => j.id == 'journal-$ts'), isTrue);

    final reloadedCheckIns = await repo2.loadCheckIn(now);
    expect(
      reloadedCheckIns.any((c) => c.id == 'morning-$ts'),
      isTrue,
    );

    // NOTE: we intentionally leave the user + docs in place. Cleanup is
    // manual — see the smoke-test report for the uid/email to delete.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
