# No Enemies

**Tagline:** "You've been fighting long enough."
**Business:** GymStreak Labs
**Platform:** iOS + Android (Flutter)
**Monetisation:** Premium only (hard paywall, no free tier)

## Overview

A personal peace and conflict resolution journey app inspired by Vinland Saga's "I have no enemies" transformation. The core thesis: every enemy you perceive is a reflection of a war inside you. End the inner war, and you have no enemies.

## Tech Stack

- **Framework:** Flutter 3.41.4 / Dart 3.11.1
- **State Management:** Provider
- **Navigation:** go_router (with auth-aware redirect guard)
- **Storage:** Cloud Firestore for all user-scoped data (profile, check-ins, journal). SharedPreferences for device-local flags only (onboarding complete, intro cinematic seen, last-seen title index, legacy migration guard).
- **Auth:** Firebase Auth — Apple / Google / Email+Password (Phase 1A complete)
- **AI:** Mock AiService (real Claude/Gemini mentor is Phase 1C — this phase 1B only moves the data layer)
- **Subscriptions:** UI-only paywall (RevenueCat in later phase)
- **Typography:** Google Fonts (Inter)
- **Animations:** flutter_animate

## Firebase Project

- **Project ID:** `noenemies-app`
- **Project Number:** `883331518653`
- **iOS Bundle ID:** `com.gymstreaklabs.noEnemies`
- **iOS App ID:** `1:883331518653:ios:2850990fe8dc2bc39627d4`
- **Android Package:** `com.gymstreaklabs.no_enemies`
- **Android App ID:** `1:883331518653:android:a7a2373643b81c929627d4`
- **Auth providers enabled:** Email/Password, Google, Apple
- **Config files:** `lib/firebase_options.dart` (generated), `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`
- **Debug SHA-1 (Android):** `05:0B:C8:9D:3C:30:9F:53:EC:78:76:97:0A:FB:AA:26:EC:07:A9:90` (registered)
- **Plan:** Spark (free) — upgrade to Blaze if Identity Platform admin APIs are needed.
- **Firestore location:** `nam5` (multi-region US), native mode.
- **Rules + indexes:** deployed from `firestore.rules` and `firestore.indexes.json` (composite index on `users/{uid}/journal` → `isBookmarked ASC, createdAt DESC`).

## Firestore Schema

Every user owns exactly one subtree, keyed by their Firebase `uid`. Security rules enforce that no user can touch another user's tree.

```
users/{uid}/
├─ profile/main                (single doc — UserProfile)
├─ checkIns/{yyyy-MM-dd}       (merged morning + evening per day)
├─ journal/{entryId}           (one doc per journal entry)
├─ ai/context                  (reserved for Phase 1C — rolling AI memory)
└─ credits/voiceMinutes        (reserved — voice feature)
```

Example `profile/main`:
```json
{
  "id": "<firebase-uid>",
  "primaryConflict": 1,
  "quizAnswers": [0, 1, 2, 1, 0, 2],
  "createdAt": <Timestamp>,
  "totalDaysOfPeace": 14,
  "currentStreak": 7,
  "peaceDays": 10, "warDays": 4,
  "hasCompletedOnboarding": true,
  "displayName": "Joe",
  "personalIntention": "...",
  "schemaVersion": 1
}
```

Example `checkIns/2026-04-17` (both halves present):
```json
{
  "date": "2026-04-17",
  "dateTs": <Timestamp>,
  "morning": { "id": "...", "mood": 2, "intention": "...", "timestamp": <Timestamp>, "isPeaceful": true },
  "evening": { "id": "...", "mood": 3, "reflectionAnswer": "...", "dimensions": [...], "timestamp": <Timestamp>, "isPeaceful": true }
}
```

Example `journal/{entryId}`:
```json
{
  "id": "...", "title": "...", "content": "...",
  "isBookmarked": false, "wordCount": 184,
  "createdAt": <Timestamp>, "updatedAt": <Timestamp>
}
```

### Cloud-synced vs device-local
| Data | Lives in | Why |
|---|---|---|
| `UserProfile` | Firestore (`users/{uid}/profile/main`) | User identity + stats, follows user across devices |
| Check-ins | Firestore (`users/{uid}/checkIns/{yyyy-MM-dd}`) | User content |
| Journal entries | Firestore (`users/{uid}/journal/{entryId}`) | User content |
| `intro_cinematic_seen` | SharedPreferences | Per-install UX flag — not tied to a user |
| `onboarding_complete` | SharedPreferences | Pre-auth router gate — needs to work before sign-in |
| `last_seen_title_index` | SharedPreferences | Per-device UX polish (skip cinematic on replay) |
| `legacy_migrated_to_firestore` | SharedPreferences | One-shot guard for the SharedPrefs→Firestore import |

### Security rules
Summary: `request.auth.uid == uid` for any read/write under `users/{uid}/**`. Nothing else readable. Full file: [`firestore.rules`](firestore.rules). Recursive wildcard `match /{document=**}` is required for subcollection access.

### Auth → repository → provider wiring

All of this happens in [`lib/main.dart`](lib/main.dart):
1. `Firebase.initializeApp` + `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` before `runApp`.
2. Single global `FirebaseAuth.authStateChanges()` listener.
3. **On sign-in:** construct `FirestoreRepository(uid: user.uid)`, then call `userProvider.attachRepository(repo, seedProfile: ...)`. The seed is whatever profile was built during onboarding (held in memory on `UserProvider`). If the cloud already has a profile, the seed is ignored.
4. **Legacy migration (one-shot):** if SharedPreferences has pre-Firestore user data AND this install hasn't been migrated, bulk-write it via `repo.migrateFromLegacy(...)` before attaching streams. Sets `legacy_migrated_to_firestore = true` on success.
5. **On sign-out:** call `userProvider.detachRepository()` — cancels streams, clears in-memory state.

`UserProvider` subscribes to three live streams once attached: `streamProfile()`, `streamRecentCheckIns(days: 30)`, `streamJournalEntries(limit: 50)`. UI reads via the same public getters as before (`profile`, `checkIns`, `journalEntries`) — every consumer screen continues to work without changes.

### Cost guardrails
- Journal list is limited to 50 entries per stream (pagination TODO when users exceed this).
- Check-ins stream is clamped to 30 days.
- Firestore offline persistence is on, so reads come from cache when offline and hot reads are free after the first fetch.

## Build & Run

```bash
flutter pub get
flutter run
# or flutter run -d <device_id>
```

Firebase is wired — no extra env setup required. `Firebase.initializeApp` runs in `main.dart`. Running on simulator/device requires CocoaPods on iOS (`cd ios && pod install`) if not already installed.

## Project Structure

```
NoEnemies/
├── CLAUDE.md
├── pubspec.yaml
├── docs/plans/product-plan.md
├── lib/
│   ├── main.dart                  # Entry point, provider setup, cinematic check
│   ├── app.dart                   # MaterialApp.router with theme
│   ├── theme/
│   │   ├── app_colors.dart        # Color constants
│   │   └── app_theme.dart         # ThemeData (dark theme)
│   ├── models/
│   │   ├── conflict_type.dart     # 8 conflict types with descriptions
│   │   ├── user_profile.dart      # User model with streak/title logic + onboarding fields
│   │   ├── onboarding_data.dart   # Intermediate data model for onboarding flow
│   │   ├── check_in.dart          # Morning/evening check-in model
│   │   ├── current_emotion.dart   # 3-bucket emotion (joyful/calm/troubled) driving the character aura
│   │   └── journal_entry.dart     # Journal entry model
│   ├── services/
│   │   ├── storage_service.dart         # SharedPreferences — device-local flags only post-1B
│   │   ├── auth_service.dart            # Firebase Auth wrapper (Apple/Google/Email)
│   │   ├── firestore_repository.dart    # Firestore data layer (profile, check-ins, journal)
│   │   └── ai_service.dart              # Mock AI prompts by conflict type (replaced in Phase 1C)
│   ├── providers/
│   │   ├── user_provider.dart     # User state, check-ins, journal
│   │   └── journey_provider.dart  # Peace missions, AI prompts
│   ├── router/
│   │   └── app_router.dart        # go_router config, all routes, fade transitions
│   ├── screens/
│   │   ├── onboarding/
│   │   │   ├── intro_cinematic_screen.dart    # Cinematic intro (plays once)
│   │   │   ├── onboarding_flow_screen.dart    # 24-screen unified onboarding flow
│   │   │   ├── welcome_screen.dart            # (legacy, replaced by flow)
│   │   │   ├── quiz_screen.dart               # (legacy, replaced by flow)
│   │   │   ├── conflict_reveal_screen.dart    # (legacy, replaced by flow)
│   │   │   └── paywall_screen.dart            # (legacy, replaced by standalone)
│   │   ├── paywall/
│   │   │   └── paywall_screen.dart            # Standalone paywall (GymLevels-style)
│   │   ├── auth/
│   │   │   └── auth_screen.dart               # Auth screen (social + email, MVP stubs)
│   │   ├── shell/
│   │   │   └── main_shell.dart          # Bottom nav (4 tabs)
│   │   ├── journey/
│   │   │   └── journey_tab.dart         # Home: map, cards, streak + particles
│   │   ├── reflect/
│   │   │   ├── reflect_tab.dart         # Reflect hub
│   │   │   ├── morning_check_in_screen.dart
│   │   │   └── evening_reflection_screen.dart
│   │   ├── crew/
│   │   │   └── crew_tab.dart            # Coming Soon placeholder
│   │   ├── you/
│   │   │   └── you_tab.dart             # Profile with animated glow + particles
│   │   └── journal/
│   │       ├── journal_screen.dart      # Journal list
│   │       └── journal_entry_screen.dart # New/edit entry
│   └── widgets/
│       ├── ambient_particles.dart  # Reusable floating particle effect
│       ├── stage_particles.dart    # Stage-specific ambient particles
│       ├── shader_transition.dart  # GLSL dissolve transition widget
│       ├── emotion_aura.dart       # Emotion-reactive halo + breath wrapper for character portraits
│       ├── peace_streak_card.dart
│       ├── character_avatar.dart   # CustomPainter warrior->peacemaker (legacy, unused by main tabs)
│       ├── mood_selector.dart
│       ├── dimension_slider.dart
│       ├── voyage_map.dart         # Parchment voyage map
│       └── today_card.dart
├── shaders/
│   └── dissolve.frag              # GLSL fragment shader for scene transitions
├── ios/
├── android/
└── test/
```

## App Structure (4 Tabs)

1. **Journey (Home)** — Voyage Map, today's card, peace mission, streak
2. **Reflect** — AI prompts, journal, weekly report, Book of Peace
3. **Crew** — Coming Soon placeholder (Phase 3)
4. **You** — Character evolution, stats, dimensions, conflict breakdown, settings

## Key Flows

- **Onboarding:** Cinematic Intro (once) -> 24-screen `OnboardingFlowScreen` -> `/paywall` -> `/auth` -> App
  - Phase 1: Welcome + Name Input
  - Phase 2: Quiz Q1-Q3
  - Phase 3: Value hits (testimonials, science)
  - Phase 4: Quiz Q4-Q6 + Q7 (conflict target) + Q8 (duration)
  - Phase 5: AI Mentor preview + Cost of conflict
  - Phase 6: Q9 (previous attempts) + Q10 (conflict style) + intensity slider + check-in time
  - Phase 7: Journey preview + social proof
  - Phase 8: Personal intention + processing + conflict reveal
  - Phase 9: Ready to commit + celebration -> "See Your Plan" navigates to standalone paywall
  - Paywall: `/paywall` route — hero image, pricing cards (annual/weekly), benefit showcase, social proof, fixed CTA
  - Auth: `/auth` route — Apple/Google/Email sign-in (MVP stubs), golden gradient aesthetic
- **Morning Check-in:** Mood selector -> AI prompt -> Set intention -> Done
- **Evening Reflection:** Mood selector -> Guided question -> Dimension sliders -> Done
- **Journal:** Free-write entries with bookmark support (bookmarked = Book of Peace)

## Conflict Types

8 types scored via onboarding quiz:
- Resentment, Self-Criticism, Comparison, Workplace, Relationship, Identity, Grief/Loss, Addiction Recovery

## Gamification

- Character evolution via CustomPainter: Warrior (red) -> Wanderer (gold) -> Seeker (teal) -> Peacemaker (green)
- Title progression based on total days of peace (0, 7, 30, 90 days)
- Compassionate streak — struggle days reduce streak by 1 instead of resetting to 0
- Peace vs War ratio tracked over time

## Color Palette

- Background: #0A0E1A (very dark navy)
- Surface: #141925 (dark blue-grey)
- Primary: #D4A853 (warm amber/gold)
- Accent: #5BBFBA (soft teal)
- Peace: #6BCB77 (soft green)
- War: #C75050 (muted red)
- Text: #E8E6E3 (off-white)

## Character Emotion Compositing

The four stage portraits (`warrior_portrait.png` → `peacemaker_portrait.png`) are composited over parallax backgrounds on the Journey tab and You tab. Their facial expressions don't change per mood — instead, we drive a **3-bucket `CurrentEmotion`** (`joyful` / `calm` / `troubled`) that controls:

- **Aura colour** — green for joyful, stage colour for calm, muted red-amber for troubled
- **Breath pace** — slower when joyful (5s), default (4s), tenser when troubled (2.8s)
- **Halo intensity** — joyful glows more brightly, calm shows no extra halo, troubled adds a warm but dim vignette

`CurrentEmotion` is derived from the **last 5 days of check-ins** via `UserProvider.currentEmotion()` (average of `Mood.peaceScore`: ≥0.7 = joyful, ≤0.35 = troubled, else calm). Defaults to `calm` when there's no data. The reusable `EmotionAura` widget (lib/widgets/emotion_aura.dart) wraps any character portrait and handles both the glow and the breath animation — it's the single source of truth so the Journey header and the You tab stay visually consistent.

Chosen over generating 12 separate face-layer PNGs (4 stages × 3 emotions) because (a) pixel-accurate face alignment across hand-painted portraits is fragile, and (b) the aura/breath signal reads more clearly at the portrait sizes we composite at. Leaves the door open to swap in face-layer PNGs later by replacing the `EmotionAura.child` contents with a `Stack` of base + emotion face — no callsite changes needed.

## UI/UX Design

- **Cinematic Intro:** Plays once on first launch. 5-scene anime artwork sequence with GLSL shader dissolve transitions (procedural noise with amber edge glow). Skippable. Stored via SharedPreferences `intro_cinematic_seen`.
- **Shader Dissolve Transitions:** GLSL fragment shader (`shaders/dissolve.frag`) creates an organic dissolve effect between intro scenes. Uses multi-octave procedural noise to create an ink-spreading pattern with an amber (#D4A853) glow at the dissolve edge. Applied via `ShaderMask` with `BlendMode.dstIn`. Falls back to simple crossfade if shader fails to load.
- **Ambient Particles:** Reusable `AmbientParticles` widget (CustomPainter) creates floating glowing embers. Used on welcome, quiz, conflict reveal, paywall, journey tab, and you tab.
- **Dark Aesthetic:** All screens use true black (#000000) backgrounds with subtle radial gradients and glass-morphism cards (white @ 3-6% opacity with matching borders).
- **Golden Gradient Text:** Key headers use ShaderMask with amber/gold LinearGradient.
- **Fade Transitions:** All onboarding routes use `CustomTransitionPage` with `FadeTransition` for cinematic feel.
- **Buttons:** Primary CTA buttons use gradient DecoratedBox with golden box-shadow glow.
- **Cards:** Frosted glass style — `Colors.white.withValues(alpha: 0.03)` background with `Colors.white.withValues(alpha: 0.06)` border, rounded to 18-20px.
- **Character Glow:** Animated pulsing radial gradient behind character avatar on You tab and conflict reveal.
- **Section Labels:** Uppercase, letter-spacing 2-4, small text for category headers.
- **Journal (The Tome):** Entries are grouped by "Book of Peace" (bookmarked — gold border, amber halo, ember bookmark rune, golden serif title) vs regular entries (neutral glass card). Header uses `THE TOME` kicker + gold ShaderMask serif title. Entry screen has amber-on-black cursor, Cormorant Garamond title field, Inter body with 1.75 line-height, live word count footer, and an animated "Keep / Kept" bookmark pill that glows gold when active. Auto-saves on back/nav; delete uses Norse-tinged copy ("The ink cannot be restored once washed away").

## Gotchas

- Hard paywall: no free tier. Close button on paywall routes to `/auth` (auth is always required before entering app).
- No monthly plan by design — force annual commitment or weekly trial.
- All user-scoped data (profile, check-ins, journal) lives in Firestore under `users/{uid}/...`. SharedPreferences only holds device-local flags (onboarding complete, intro seen, last-seen title index, legacy migration guard). See the "Firestore Schema" section above.
- `UserProvider` holds a nullable `FirestoreRepository`. It's attached by the auth state listener in `main.dart` on sign-in and detached on sign-out. Existing screens read via the same public getters (`profile`, `checkIns`, `journalEntries`) — the swap is transparent to the UI.
- `createProfile(...)` is kept as a back-compat wrapper over `buildOnboardingProfile(...)`. It no longer writes to SharedPreferences — the profile is held in memory until sign-in, then the auth listener persists it via `repo.saveProfile(seed.copyWith(id: uid))`. The uuid `id` generated during onboarding is REPLACED by the Firebase `uid` on first persist.
- Firestore offline persistence is enabled in `main.dart` (`Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`) so the UX doesn't regress vs SharedPrefs when the user is offline.
- Legacy SharedPreferences data is migrated to Firestore on first post-upgrade sign-in via `StorageService.legacyProfile/legacyCheckIns/legacyJournalEntries` + `FirestoreRepository.migrateFromLegacy`. The guard `legacy_migrated_to_firestore` stops re-running. Legacy keys are cleared after a successful import.
- AiService returns pre-written prompts keyed by conflict type + mood — not real AI.
- go_router creates new router instance on every build via `AppRouter.router(userProvider)` — acceptable for MVP but should be cached in Phase 2.
- Cinematic intro uses manual opacity stepping (not AnimationController) for text fade timing. Scene transitions use a 1.4s AnimationController with easeInOut curve driving the GLSL dissolve shader.
- Fragment shaders are registered under `flutter: shaders:` in pubspec.yaml (not `assets:`). The dissolve shader is loaded once via `DissolveShaderCache` and reused across all transitions.
- `AppRouter.cinematicSeen` is set in `main.dart` before app runs — static field on the router class.
- Onboarding is a single `/onboarding` route with 24 internal pages managed by a `PageView`. Paywall and auth are separate routes (`/paywall`, `/auth`).
- `OnboardingData` model collects all answers during the flow. `UserProvider.createProfile(...)` is called on "See Your Plan" — this now builds the profile in memory and flips the local `onboarding_complete` flag, but the Firestore write only happens once the user signs in on `/auth`. The auth state listener in `main.dart` picks up the in-memory seed and writes it to `users/{uid}/profile/main` with `id` swapped to the Firebase `uid`.
- Paywall screen at `/paywall` is a standalone GymLevels-style paywall with hero image, shimmer offer banner, annual/weekly pricing cards, benefit showcase, quick features, social proof, and fixed bottom CTA. UI-only for MVP.
- Auth screen at `/auth` uses real Firebase Auth via `AuthService`. Apple, Google, and Email+Password flows are all wired. Email form tries sign-in first, then falls back to sign-up on user-not-found/invalid-credential. Errors surface via `_friendlyError()` which maps FirebaseAuthException codes to user-readable strings. Loading overlay disables all buttons during network calls.
- Paywall close (X) button routes to `/auth` — users must authenticate before entering the app. No skip-to-journey shortcut remains.
- `AuthService` generates a SHA256-hashed nonce for Apple sign-in (required for Firebase ID token exchange). First-time Apple sign-in writes the given+family name into `FirebaseAuth.currentUser.displayName` (Apple only returns the name on first auth).
- Router has an auth-aware redirect: unauthenticated users are forced to `/auth` for all app routes. Public routes: `/intro`, `/onboarding`, `/paywall`, `/auth`, `/debug`. The router uses `refreshListenable: _AuthStateListenable()` which wraps `FirebaseAuth.authStateChanges()` so sign-in/sign-out triggers immediate redirect re-evaluation. `_isSignedIn()` is wrapped in try/catch for safety when Firebase hasn't initialised.
- Sign out lives in the You tab settings sheet (last item). Calls `AuthService.signOut()` then pushes `/auth`.
- iOS 15.0 minimum (Firebase Auth requirement). Android minSdk is 23. Debug SHA-1 is registered with Firebase — Google Sign-In works on debug builds.
- `Runner.entitlements` contains `com.apple.developer.applesignin`. Referenced via `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in all three build configs (Debug/Release/Profile). Apple Sign-In capability must ALSO be enabled on the App ID in Apple Developer portal before TestFlight/App Store builds.
- Google Sign-In URL scheme (`REVERSED_CLIENT_ID` from GoogleService-Info.plist) is registered in `ios/Runner/Info.plist` under `CFBundleURLTypes`.
- `UserProfile` now has extra onboarding fields: `displayName`, `conflictTarget`, `conflictDuration`, `conflictIntensity`, `conflictStyle`, `preferredCheckInTime`, `personalIntention`, `previousAttempts`.
- Processing screen (page 21) runs conflict type calculation and auto-advances after ~7s.
- Reveal screen (page 22) runs a timed sequence showing content progressively. Back button is hidden on processing, reveal, and celebration pages.

## Phase 1B (complete — 2026-04-17)

- [x] Firestore data layer swap — profile, check-ins, journal move to `users/{uid}/...`
- [x] `FirestoreRepository` in `lib/services/firestore_repository.dart` with live streams
- [x] `UserProvider` rewired to attach/detach repo on sign-in/sign-out
- [x] Security rules (`firestore.rules`) deployed to `noenemies-app`
- [x] Indexes (`firestore.indexes.json`) deployed — composite `journal.isBookmarked + createdAt`
- [x] Offline persistence enabled
- [x] One-shot migration from SharedPreferences to Firestore on first post-upgrade sign-in
- [x] JSON round-trip tests (`test/firestore_repository_test.dart`)

## Phase 1C TODO (next — AI mentor)

- Replace mock `AiService` with `AiMentorService` backed by `firebase_ai` + Gemini 2.5 Flash
- Rolling `users/{uid}/ai/context` summary, rebuilt every ~10 check-ins
- App Check (DeviceCheck on iOS, Play Integrity on Android) — required before the proxy is publicly hittable
- Loading states in `MorningCheckInScreen`, `EveningReflectionScreen`, `JournalEntryScreen`
- Fallback to the existing Dart string library on Gemini failures

## Phase 2 TODO

- Real Claude/Gemini AI mentor integration via `firebase_ai`
- RevenueCat subscription integration (hook paywall CTA up to real purchase flow)
- App Check enforcement (currently added to pubspec but not initialised)
- Weekly insight reports (card stack format)
- Voyage Map with real data visualization
- Push notifications (morning + evening)
- Multiple conflict types per user

## Phase 1A Release Checklist (do before TestFlight)

- [ ] Enable "Sign In with Apple" capability on the App ID in Apple Developer portal
- [ ] Register the **release** keystore SHA-1 (and SHA-256) with the Firebase Android app
- [ ] Add release keystore SHA fingerprints to OAuth 2.0 client in Google Cloud Console
- [ ] Decide on Blaze upgrade if Identity Platform admin APIs are needed
- [ ] Configure Firebase Auth email templates (verification, password reset) with branded copy
- [ ] Add `Firebase.initializeApp` error handling that fails loudly in release mode (currently silently swallows for dev convenience)
