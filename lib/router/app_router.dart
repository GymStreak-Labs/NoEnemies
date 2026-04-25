import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/onboarding/intro_cinematic_screen.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import '../screens/paywall/paywall_screen.dart';
import '../screens/shell/main_shell.dart';
import '../models/user_profile.dart';
import '../screens/insights/weekly_insights_screen.dart';
import '../screens/journey/journey_tab.dart';
import '../screens/stage_transition_screen.dart';
import '../screens/reflect/reflect_tab.dart';
import '../screens/reflect/morning_check_in_screen.dart';
import '../screens/reflect/evening_reflection_screen.dart';
import '../screens/crew/crew_tab.dart';
import '../screens/you/you_tab.dart';
import '../screens/journal/journal_screen.dart';
import '../screens/journal/journal_entry_screen.dart';
import '../screens/journal/voice_journal_entry_screen.dart';
import '../services/ai_mentor_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Whether the cinematic intro has been seen.
  /// Set during app initialization.
  static bool cinematicSeen = false;

  // -----------------------------------------------------------------------
  // DEBUG: Set this to a page number (0–23) to jump straight to that
  // onboarding page on launch. Set to -1 for normal flow.
  //
  //   -1  = normal flow (intro → onboarding → ...)
  //    0  = Name Input
  //   17  = Journey Preview
  //   18  = Social Proof
  //   21  = Conflict Reveal
  //   23  = Celebration
  //
  // The picker is still available via the Debug button on the intro screen.
  // -----------------------------------------------------------------------
  static const int debugStartPage = -1;

  static GoRouter router(
    UserProvider userProvider,
    SubscriptionService subscriptionService,
  ) {
    // Determine initial location:
    // 1. If onboarding complete -> app
    // 2. Debug override -> jump to specific page
    // 3. If cinematic not seen -> intro cinematic
    // 4. Else -> onboarding flow
    String initialLocation;
    if (debugStartPage == -2) {
      initialLocation = '/paywall'; // DEBUG: jump to paywall
    } else if (debugStartPage == -3) {
      initialLocation = '/journey'; // DEBUG: jump to main app
    } else if (debugStartPage == -4) {
      initialLocation = '/stage-transition'; // DEBUG: preview cinematic
    } else if (userProvider.isOnboardingComplete) {
      initialLocation = '/journey';
    } else if (debugStartPage >= 0) {
      initialLocation = '/onboarding?page=$debugStartPage';
    } else if (!cinematicSeen) {
      initialLocation = '/intro';
    } else {
      initialLocation = '/onboarding';
    }

    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation,
      refreshListenable: _RouterRefreshListenable(subscriptionService),
      routes: [
        // --- Cinematic Intro ---
        GoRoute(
          path: '/intro',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const IntroCinematicScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        ),

        // --- Onboarding (single unified flow) ---
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) {
            // Support ?page=N query param for debug quick-navigation
            final pageParam = state.uri.queryParameters['page'];
            final startPage = pageParam != null
                ? int.tryParse(pageParam) ?? 0
                : 0;
            return CustomTransitionPage(
              key: state.pageKey,
              child: OnboardingFlowScreen(startPage: startPage),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 600),
            );
          },
        ),

        // --- Debug Screen Picker (dev only) ---
        GoRoute(
          path: '/debug',
          builder: (context, state) => const _DebugScreenPicker(),
        ),

        // --- Paywall (standalone, shown after onboarding) ---
        GoRoute(
          path: '/paywall',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const PaywallScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        ),

        // --- Auth (shown after paywall) ---
        GoRoute(
          path: '/auth',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const AuthScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        ),

        // --- Main App (Shell with Bottom Nav) ---
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/journey',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: JourneyTab()),
            ),
            GoRoute(
              path: '/reflect',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReflectTab()),
            ),
            GoRoute(
              path: '/crew',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CrewTab()),
            ),
            GoRoute(
              path: '/you',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: YouTab()),
            ),
          ],
        ),

        // --- Full-screen routes ---
        GoRoute(
          path: '/stage-transition',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final from = extra?['from'] as UserTitle? ?? UserTitle.warrior;
            final to = extra?['to'] as UserTitle? ?? UserTitle.wanderer;
            return StageTransitionScreen(
              previousStage: from,
              newStage: to,
              onContinue: () async {
                // Mark the new title as acknowledged so we don't replay
                await context.read<UserProvider>().acknowledgeCurrentTitle();
                if (context.mounted) {
                  if (GoRouter.of(context).canPop()) {
                    GoRouter.of(context).pop();
                  } else {
                    GoRouter.of(context).go('/journey');
                  }
                }
              },
            );
          },
        ),
        GoRoute(
          path: '/insights/weekly',
          builder: (context, state) => const WeeklyInsightsScreen(),
        ),
        GoRoute(
          path: '/morning-check-in',
          builder: (context, state) => const MorningCheckInScreen(),
        ),
        GoRoute(
          path: '/evening-reflection',
          builder: (context, state) => const EveningReflectionScreen(),
        ),
        GoRoute(
          path: '/journal',
          builder: (context, state) => const JournalScreen(),
        ),
        GoRoute(
          path: '/journal/new',
          builder: (context, state) => const JournalEntryScreen(),
        ),
        GoRoute(
          path: '/journal/voice',
          builder: (context, state) => VoiceJournalEntryScreen(
            storage: context.read<StorageService>(),
            mentor: context.read<AiMentorService>(),
          ),
        ),
        GoRoute(
          path: '/journal/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return JournalEntryScreen(entryId: id);
          },
        ),
      ],
      redirect: (context, state) {
        final path = state.uri.path;
        final isOnboarding = !context.read<UserProvider>().isOnboardingComplete;
        final hasPremium = subscriptionService.hasPremium;

        // Paths that never require auth — they're part of the pre-sign-in flow.
        const unauthPaths = <String>{
          '/intro',
          '/onboarding',
          '/paywall',
          '/auth',
          '/debug',
        };
        final isUnauthPath = unauthPaths.contains(path);

        final bool isSignedIn = _isSignedIn();
        final isDebugMainBypass = debugStartPage == -3;

        // If the user already has premium, don't leave them parked on the
        // paywall. Anonymous purchasers still need to authenticate so the
        // purchase can be aliased to their Firebase uid.
        if (path == '/paywall' && hasPremium && debugStartPage == -1) {
          return isSignedIn ? '/journey' : '/auth';
        }

        // If a signed-in user reaches auth, send them to the right locked or
        // unlocked destination. This keeps the close-X -> auth flow honest:
        // sign-in without premium bounces back to the paywall.
        if (path == '/auth' &&
            isSignedIn &&
            !isOnboarding &&
            debugStartPage == -1) {
          return hasPremium ? '/journey' : '/paywall';
        }

        // --- Onboarding gate ---
        // If onboarding not done and not on an onboarding path, redirect
        // into the onboarding flow (intro first if cinematic hasn't been seen).
        if (isOnboarding && !isUnauthPath && debugStartPage >= -1) {
          if (!cinematicSeen) {
            return '/intro';
          }
          return '/onboarding';
        }

        // --- Auth guard ---
        // If we have Firebase initialized and the user isn't signed in, they
        // can't access any of the in-app routes (/journey, /reflect, /you,
        // /journal, etc.). Redirect them to /auth. We wrap in try/catch so
        // the app still runs before `flutterfire configure` has been run
        // (Firebase.instance throws if not initialized).
        if (!isSignedIn && !isUnauthPath && debugStartPage == -1) {
          // Debug override still works (debugStartPage >= 0 jumps to a
          // specific onboarding page).
          return '/auth';
        }

        // --- Premium guard ---
        // NoEnemies has no free tier. Once onboarding and auth are done,
        // every in-app route requires RevenueCat's `premium` entitlement.
        if (!hasPremium &&
            !isUnauthPath &&
            !isDebugMainBypass &&
            debugStartPage == -1) {
          return '/paywall';
        }

        return null;
      },
    );
  }

  /// Returns true if a Firebase user is signed in. Safe to call before
  /// `Firebase.initializeApp` — returns false on any error.
  static bool _isSignedIn() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppRouter] FirebaseAuth not ready yet: $e');
      }
      return false;
    }
  }
}

/// Rebroadcasts Firebase auth + RevenueCat entitlement changes as one
/// [Listenable] so [GoRouter] re-evaluates redirects on sign-in/sign-out and
/// immediately after purchases/restores. Safe before Firebase is initialized.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this._subscriptionService) {
    try {
      _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppRouter] Could not subscribe to authStateChanges: $e');
      }
    }
    _subscriptionService.addListener(notifyListeners);
  }

  final SubscriptionService _subscriptionService;
  StreamSubscription<User?>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _subscriptionService.removeListener(notifyListeners);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Debug Screen Picker — jump to any onboarding page
// ---------------------------------------------------------------------------

class _DebugScreenPicker extends StatelessWidget {
  const _DebugScreenPicker();

  static const _phaseColors = <int, Color>{
    0: Color(0xFFD4A853), // Phase 1 — name
    1: Color(0xFFC75050), // Phase 2 — quiz
    4: Color(0xFF5BBFBA), // Phase 3 — value
    6: Color(0xFFC75050), // Phase 4 — quiz
    9: Color(0xFFE8C87A), // Phase 4 — targets
    11: Color(0xFF5BBFBA), // Phase 5 — value
    13: Color(0xFFC75050), // Phase 6 — quiz
    17: Color(0xFF6BCB77), // Phase 7 — journey
    19: Color(0xFFD4A853), // Phase 8 — intention
    20: Color(0xFF5BBFBA), // Phase 8 — processing
  };

  Color _colorForPage(int page) {
    Color c = const Color(0xFFD4A853);
    for (final entry in _phaseColors.entries) {
      if (page >= entry.key) c = entry.value;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141925),
        title: const Text(
          'DEBUG — Screen Picker',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE8E6E3),
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFE8E6E3)),
          onPressed: () => GoRouter.of(context).go('/intro'),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount:
            OnboardingFlowScreen.pageNames.length +
            3, // +3 for paywall, auth, app
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          // Onboarding pages
          if (index < OnboardingFlowScreen.pageNames.length) {
            final name = OnboardingFlowScreen.pageNames[index];
            final color = _colorForPage(index);
            return _tile(context, name, color, () {
              GoRouter.of(context).go('/onboarding?page=$index');
            });
          }
          // Extra routes
          final extraIndex = index - OnboardingFlowScreen.pageNames.length;
          if (extraIndex == 0) {
            return _tile(context, 'Paywall', const Color(0xFFD4A853), () {
              GoRouter.of(context).go('/paywall');
            });
          }
          if (extraIndex == 1) {
            return _tile(context, 'Auth', const Color(0xFF5BBFBA), () {
              GoRouter.of(context).go('/auth');
            });
          }
          return _tile(
            context,
            'App (Journey Tab)',
            const Color(0xFF6BCB77),
            () {
              GoRouter.of(context).go('/journey');
            },
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFFE8E6E3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
