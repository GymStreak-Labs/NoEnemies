import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'models/conflict_type.dart';
import 'providers/user_provider.dart';
import 'providers/journey_provider.dart';
import 'router/app_router.dart';
import 'screens/onboarding/intro_cinematic_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Firebase init ---
  // If the generated firebase_options.dart is still the placeholder, we skip
  // initialization so the app can still boot for UI-only development. Once
  // `flutterfire configure` is run, real options replace the placeholder and
  // Firebase boots normally.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[main] Firebase init failed — this is expected until '
        'flutterfire configure has been run. Error: $e',
      );
    }
  }

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize storage
  final storageService = StorageService();
  await storageService.init();

  final aiService = AiService();
  final authService = AuthService();

  // Check if cinematic intro has been seen
  AppRouter.cinematicSeen = await IntroCinematicScreen.hasBeenSeen();

  // In debug mode with debugStartPage -3, create a dummy profile
  // so the main app tabs have data to display.
  // DEBUG: Set debugPeaceDays to simulate different stages:
  //   0  = Warrior (default)
  //   7  = Wanderer
  //   30 = Seeker
  //   90 = Peacemaker
  const int debugPeaceDays = 0;

  final userProvider = UserProvider(storageService);
  await userProvider.loadData();
  if (kDebugMode && AppRouter.debugStartPage == -3) {
    // Always recreate profile in debug mode to apply debugPeaceDays
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
    // Override totalDaysOfPeace for stage simulation
    if (debugPeaceDays > 0) {
      await userProvider.debugSetPeaceDays(debugPeaceDays);
    }
    // In debug mode, pre-acknowledge the current title so the cinematic
    // doesn't auto-fire on every hot restart while we're working.
    await userProvider.acknowledgeCurrentTitle();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(
          value: userProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => JourneyProvider(aiService),
        ),
      ],
      child: const NoEnemiesApp(),
    ),
  );
}
