import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'models/conflict_type.dart';
import 'models/user_profile.dart';
import 'providers/journey_provider.dart';
import 'providers/user_provider.dart';
import 'router/app_router.dart';
import 'screens/onboarding/intro_cinematic_screen.dart';
import 'services/ai_mentor_service.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_repository.dart';
import 'services/storage_service.dart';

/// Global subscription so the auth listener survives hot restart without
/// stacking duplicates.
StreamSubscription<User?>? _authSub;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Firebase init ---
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Enable offline persistence so the UX doesn't regress vs. SharedPrefs.
    // (On iOS/Android the default cache is small — unlimited keeps the user's
    // history available offline until their disk pressure forces eviction.)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    firebaseReady = true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[main] Firebase init failed — app boots in offline-only mode. '
        'Error: $e',
      );
    }
  }

  // Lock to portrait + dark status bar.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Device-local storage (onboarding flag, title index, legacy migration).
  final storageService = StorageService();
  await storageService.init();

  final aiService = AiService();
  final aiMentor = AiMentorService(fallback: aiService);
  if (firebaseReady) {
    // Non-blocking — if init fails, the mentor falls back to the Dart
    // string library transparently.
    await aiMentor.init();
  }
  final authService = AuthService();

  AppRouter.cinematicSeen = await IntroCinematicScreen.hasBeenSeen();

  // DEBUG: Set debugPeaceDays to simulate different stages.
  //   0  = Warrior (default)
  //   7  = Wanderer
  //   30 = Seeker
  //   90 = Peacemaker
  const int debugPeaceDays = 0;

  final userProvider = UserProvider(storageService, mentor: aiMentor);

  // Hook up auth state → repository attach/detach. This is the ONE place in
  // the app where Firestore repositories are created; every other layer
  // reads from [UserProvider].
  if (firebaseReady) {
    await _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final repo = FirestoreRepository(uid: user.uid);

        // Pick a seed profile: prefer the one built during onboarding (held
        // in-memory on [UserProvider]) so first-time users land with all
        // their quiz answers intact.
        UserProfile? seed = userProvider.profile?.copyWith(id: user.uid);

        // Legacy migration path — if SharedPreferences has pre-Firestore
        // data AND we haven't migrated this install yet, import it.
        final shouldMigrate = !storageService.isLegacyMigrated &&
            storageService.hasLegacyUserData;
        if (shouldMigrate) {
          try {
            final existing = await repo.loadProfile();
            if (existing == null) {
              final legacyProfile = storageService.legacyProfile();
              final legacyCheckIns = storageService.legacyCheckIns();
              final legacyJournal = storageService.legacyJournalEntries();
              if (legacyProfile != null) {
                await repo.migrateFromLegacy(
                  profile: legacyProfile.copyWith(id: user.uid),
                  checkIns: legacyCheckIns,
                  journal: legacyJournal,
                );
                // Seed becomes the legacy profile so attachRepository doesn't
                // overwrite it with a stale in-memory onboarding seed.
                seed = null;
                if (kDebugMode) {
                  debugPrint(
                    '[main] Migrated ${legacyCheckIns.length} check-ins + '
                    '${legacyJournal.length} journal entries from SharedPrefs '
                    'to Firestore for uid=${user.uid}',
                  );
                }
              }
            }
            await storageService.markLegacyMigrated();
            await storageService.clearLegacyUserData();
          } catch (e, st) {
            debugPrint('[main] Legacy migration failed: $e\n$st');
            // Don't flip the migrated flag — retry next launch.
          }
        }

        await userProvider.attachRepository(repo, seedProfile: seed);
      } else {
        await userProvider.detachRepository();
      }
    });
  }

  // Debug mode: force a dummy profile so /journey has data. Only applies
  // when the developer uses debugStartPage == -3 to bypass auth.
  if (kDebugMode && AppRouter.debugStartPage == -3) {
    await userProvider.createProfile(
      conflictType: ConflictType.selfHatred,
      quizAnswers: [0, 1, 2, 1, 0, 2],
      displayName: 'Peace Seeker',
      conflictTarget: 'Myself',
      conflictDuration: 'Years',
      conflictIntensity: 7,
      conflictStyle: 'Fighter',
      preferredCheckInTime: 'Morning',
      personalIntention: 'I want to treat myself with kindness',
      previousAttempts: ['Therapy', 'Meditation'],
    );
    if (debugPeaceDays > 0) {
      await userProvider.debugSetPeaceDays(debugPeaceDays);
    }
    await userProvider.acknowledgeCurrentTitle();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => JourneyProvider(aiService, mentor: aiMentor),
        ),
      ],
      child: const NoEnemiesApp(),
    ),
  );
}
