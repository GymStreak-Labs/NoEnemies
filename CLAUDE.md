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
- **Navigation:** go_router 17.2.1 (with auth-aware redirect guard). 14→17 bump was a straight drop-in — the APIs we rely on (`GoRouter`, `GoRoute`, `ShellRoute`, `CustomTransitionPage`, `NoTransitionPage`, `refreshListenable`, `state.uri`, `state.pageKey`, `state.pathParameters`, `state.extra`, `GoRouter.of(context).go/pop/canPop`) are unchanged across 14/15/16/17.
- **Storage:** Cloud Firestore for all user-scoped data (profile, check-ins, journal). SharedPreferences for device-local flags only (onboarding complete, intro cinematic seen, last-seen title index, legacy migration guard).
- **Auth:** Firebase Auth — Apple / Google / Email+Password (Phase 1A complete). Firebase iOS SDK 12.12 (Core 4.7, Auth 6.4, Firestore 6.3). `google_sign_in` 7.x singleton API (`GoogleSignIn.instance.initialize()` + `authenticate()`); user cancel is now a thrown `GoogleSignInException(code: canceled)` rather than a null return.
- **AI:** Gemini 2.5 Flash via `firebase_ai` 3.11 (Google AI / Gemini Developer API backend). Firebase AI Logic is configured on the `noenemies-app` project (Firebase console → Build → AI Logic → Gemini Developer API). Falls back to a hand-written Dart string library when the model is unreachable. See "AI Mentor (Phase 1C)" below.
- **Subscriptions:** RevenueCat via `purchases_flutter` 10.0.1. Hard paywall, no free tier. Entitlement `premium`; offerings `default` (`$rc_annual`, `$rc_weekly`) and `special_offer` (`special_annual`). See "Subscriptions / RevenueCat" below.
- **Typography:** `google_fonts` 8.0.2 (Inter, Cinzel, Cormorant Garamond). 6→8 bump had no source-level impact on our callsites (`GoogleFonts.inter()`, `GoogleFonts.cinzel()`, `GoogleFonts.cormorantGaramond()` factories are stable).
- **Animations:** flutter_animate
- **Page indicator:** `smooth_page_indicator` 2.0.1 (currently declared but not imported — kept for onboarding polish work).

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
│   │   ├── journal_entry.dart     # Journal entry model
│   │   └── ai_context.dart        # Rolling AI memory summary (Phase 1C)
│   ├── services/
│   │   ├── storage_service.dart         # SharedPreferences — device-local flags only post-1B
│   │   ├── auth_service.dart            # Firebase Auth wrapper (Apple/Google/Email)
│   │   ├── firestore_repository.dart    # Firestore data layer (profile, check-ins, journal, ai/context)
│   │   ├── subscription_service.dart     # RevenueCat SDK config, offerings, purchase/restore, premium gate state
│   │   ├── ai_service.dart              # Dart string fallback library (formerly "mock AI")
│   │   ├── ai_mentor_service.dart       # Real Gemini 2.5 Flash mentor via firebase_ai (Phase 1C) + audio transcription (Phase 2)
│   │   └── voice_recording_service.dart # Press-and-hold WAV recorder + amplitude stream (Phase 2)
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
│   │       ├── journal_screen.dart             # Journal list (with mic entry point)
│   │       ├── journal_entry_screen.dart       # New/edit entry + audio player bar
│   │       └── voice_journal_entry_screen.dart # Phase 2 voice flow (press-and-hold)
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
│       ├── recording_waveform.dart # Amplitude-driven waveform bars (Phase 2)
│       ├── journal_audio_player.dart # Compact amber audio player for voice entries (Phase 2)
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

## AI Mentor (Phase 1C)

The mentor is a small layer over [`firebase_ai`](https://pub.dev/packages/firebase_ai) using Google's Gemini Developer API (NOT Vertex — see gotchas). Entry point: [`lib/services/ai_mentor_service.dart`](lib/services/ai_mentor_service.dart). `init()` is called once in `main.dart` after `Firebase.initializeApp`.

**Model config**
- `gemini-2.5-flash` (NOT Pro, NOT flash-lite — Flash is the right trade-off for latency + cost on short mentor replies)
- `temperature: 0.8`, `maxOutputTokens: 200`
- `FirebaseAI.googleAI()` — uses the consumer Gemini endpoint, no Vertex project config required
- App Check wired client-side on init (debug providers in dev, DeviceCheck/Play Integrity in release). Enforcement is NOT turned on in the Firebase console yet — that's a launch-time task.

**Voice**
The system prompt (single `Content.text` block passed as `systemInstruction`) tells the mentor:
- 1–3 sentences max, no markdown, no emojis, no lists
- Speak to the user as "you", never use their name
- Never diagnose, never prescribe treatment
- If the user seems in crisis, gently point at professional help in one sentence

**What the mentor can do**
1. `morningPrompt` — 1–2 sentence prompt grounded in current mood + streak + intention + rolling memory
2. `eveningQuestion` — one reflection question, referencing the morning intention if present
3. `journalReflection` — 1–3 sentence reflection on a journal entry (one question max, optional)

**Rolling memory**
Stored at `users/{uid}/ai/context` as `AiContext { summary, themes, lastRebuiltAt, checkInsCount, checkInsSinceLastRebuild, tokenEstimate }`. Rebuilt every 10 check-ins by `AiMentorService.rebuildContext`, fed the last 20 check-ins + profile intention. The summary prompt asks for "3–4 sentences, third person, no names, max 400 chars." The rebuild is fire-and-forget from `UserProvider._maybeRebuildAiContext()` — failures are logged and the existing context stays.

**The trigger is anchored to a persisted `checkInsSinceLastRebuild` counter on `AiContext`**, NOT to the size of the windowed `_checkIns` list. This matters: the check-in stream is capped to 30 days, so a long-term user's `_checkIns.length` saturates at ~30 and any `length % N` trigger would misfire on every new entry. The counter increments on every saved check-in (persisted on each bump so we don't lose progress across app launches) and resets to 0 when a rebuild succeeds. Tests in `test/firestore_repository_test.dart > AiContext rebuild counter` cover the reset + migration paths.

**Fallback strategy (critical)**
Every AI call is wrapped in `_safeGenerate`, which on exception OR empty response returns a handwritten Dart string from `AiService` (promoted from the old mock to a permanent fallback library). The UI never sees a broken prompt. `JourneyProvider` keeps both sync (fallback) and async (mentor) methods so callers can pick the right one.

**UI integration**
- `MorningCheckInScreen`: mood selection kicks off async `generateMorningPrompt`. While loading, a soft "the mentor is listening…" placeholder shows in the mentor card. CTA ("Set Today's Intention") is gated until the prompt lands.
- `EveningReflectionScreen`: same pattern, but passes today's morning check-in (if any) so the question can reference the morning intention. Fallback question shows on failure.
- `JournalEntryScreen`: journal reflection is OPT-IN — users tap "Ask the mentor" in the footer to trigger `_save(pop: false)` + `generateJournalReflection`. The reflection appears in a card below the entry with a mentor kicker and italic serif body. Non-blocking — users can exit without waiting.

## Subscriptions / RevenueCat

NoEnemies is premium-only. RevenueCat is configured in [`lib/services/subscription_service.dart`](lib/services/subscription_service.dart) and injected via Provider from [`lib/main.dart`](lib/main.dart).

**RevenueCat project**
- Project ID: `e1cbc9d7`
- Credential file: `~/.mission-control/credentials/noenemies-revenuecat.env` (secret key stays local; never embed `sk_...` keys in the app)
- iOS app: `app59ae701630`, bundle `com.gymstreaklabs.noEnemies`, public SDK key `appl_...`
- Android app: `appfda3285758`, package `com.gymstreaklabs.no_enemies`, public SDK key `goog_...`

**Catalog shape (mirrors GymLevels, without `default_notrial`)**
- Entitlement: `premium` / Premium Access
- Offering `default`: packages `$rc_annual` + `$rc_weekly`
- Offering `special_offer`: package `special_annual`
- `special_offer` metadata: `title=Special Offer`, `badge_text=BEST VALUE`, `countdown_seconds=900`
- iOS products:
  - `com.gymstreaklabs.noenemies.special_annual` ($29.99/year)
  - `com.gymstreaklabs.noenemies.annual` ($59.99/year)
  - `com.gymstreaklabs.noenemies.weekly` ($4.99/week)
- Android products/base plans:
  - `noenemies_pro:special-annual` ($29.99/year)
  - `noenemies_pro:annual` ($59.99/year)
  - `noenemies_pro:weekly` ($4.99/week)

**App flow**
1. RevenueCat is configured on boot with the platform public SDK key. Public RevenueCat SDK keys are safe to embed; secret keys are not.
2. `/paywall` loads the live offerings. The annual card prefers `special_offer/special_annual` when present, falling back to `default/$rc_annual`.
3. Purchase/restore uses `Purchases.purchase(PurchaseParams.package(...))` / `Purchases.restorePurchases()`.
4. On Firebase sign-in, `SubscriptionService.logIn(uid)` aliases the anonymous RevenueCat subscriber to the Firebase uid so paywall-before-auth purchases transfer cleanly.
5. `AppRouter` gates all in-app routes on the active `premium` entitlement after onboarding + auth. `/intro`, `/onboarding`, `/paywall`, `/auth`, and `/debug` remain public.
6. Build-time escape hatch for internal screenshots only: `--dart-define=FORCE_PREMIUM=true`.

**Apple / store-side config**
- App Store Connect app ID: `6762665587`
- RevenueCat App Store Connect API key + in-app purchase subscription key are configured.
- Apple server notification URL has been added in App Store Connect (production + sandbox).

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

- Hard paywall: no free tier. Close button on paywall routes to `/auth`, but signed-in non-premium users are routed back to `/paywall` until RevenueCat's `premium` entitlement is active.
- No monthly plan by design — force special annual / annual commitment or weekly trial.
- All user-scoped data (profile, check-ins, journal) lives in Firestore under `users/{uid}/...`. SharedPreferences only holds device-local flags (onboarding complete, intro seen, last-seen title index, legacy migration guard). See the "Firestore Schema" section above.
- `UserProvider` holds a nullable `FirestoreRepository`. It's attached by the auth state listener in `main.dart` on sign-in and detached on sign-out. Existing screens read via the same public getters (`profile`, `checkIns`, `journalEntries`) — the swap is transparent to the UI.
- `createProfile(...)` is kept as a back-compat wrapper over `buildOnboardingProfile(...)`. It no longer writes to SharedPreferences — the profile is held in memory until sign-in, then the auth listener persists it via `repo.saveProfile(seed.copyWith(id: uid))`. The uuid `id` generated during onboarding is REPLACED by the Firebase `uid` on first persist.
- Firestore offline persistence is enabled in `main.dart` (`Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`) so the UX doesn't regress vs SharedPrefs when the user is offline.
- Legacy SharedPreferences data is migrated to Firestore on first post-upgrade sign-in via `StorageService.legacyProfile/legacyCheckIns/legacyJournalEntries` + `FirestoreRepository.migrateFromLegacy`. The guard `legacy_migrated_to_firestore` stops re-running. Legacy keys are cleared after a successful import.
- `AiService` is now the **fallback** library — it returns pre-written Dart strings keyed by conflict type + mood. Used when `AiMentorService` can't reach Gemini. Do not delete it; do not rename it (callers reference it by type).
- `AiMentorService` uses the `firebase_ai` package (NOT the deprecated `firebase_vertexai`). As of 2026-04-17 we're on `firebase_ai` 3.11 / `firebase_core` 4.7 / `firebase_auth` 6.4 / `cloud_firestore` 6.3 (Firebase iOS SDK 12.12). The full stack bump happened in one commit — see `chore/firebase-sdk-bump`.
- `firebase_app_check` 0.4.x **renamed** the `androidProvider` / `appleProvider` params (enum) to `providerAndroid` / `providerApple` (concrete provider classes: `AndroidDebugProvider`, `AndroidPlayIntegrityProvider`, `AppleDebugProvider`, `AppleDeviceCheckProvider`). The enum versions still compile but emit a deprecation.
- **Firebase AI Logic must be explicitly configured on the Firebase project** before any `firebase_ai` request succeeds. Not done → calls throw `FirebaseAIException` with `"Firebase AI Logic is missing a configured Gemini Developer API key"` or `"API has not been used in project XXX before"`. One-time setup: Firebase console → `noenemies-app` → Build → AI Logic → Get started → **Gemini Developer API** (left column; no Blaze needed) → Enable APIs → Continue. This provisions a Gemini API key into the project and flips the correct flags. Code-side: just `FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash', ...)` — no API key in our app.
- `google_sign_in` 7.x breaking changes: `GoogleSignIn()` constructor removed (use `GoogleSignIn.instance`). Must call `initialize()` once before any auth. `signIn()` replaced with `authenticate()`. User cancellation is now a thrown `GoogleSignInException(code: GoogleSignInExceptionCode.canceled)` rather than a null return — `AuthService` remaps it to the existing `sign-in-cancelled` FirebaseAuth code so UI error handling is unchanged. `GoogleSignInAuthentication` now only exposes `idToken` (no `accessToken`); Firebase's `GoogleAuthProvider.credential(idToken: ...)` works fine with just the ID token.
- App Check is activated client-side in `AiMentorService.init()` but enforcement is NOT turned on in the Firebase console. The client will silently ignore the absence of enforcement; when we flip the server-side switch at launch, the client is already ready.
- `AiMentorService.init()` is wrapped in try/catch — if it fails (e.g. no Firebase app, model creation error), the service falls into "fallback-only" mode and everything else continues to work. Critical for test harness behaviour and offline dev.
- AI rolling context (`users/{uid}/ai/context`) is rebuilt every 10 check-ins. The trigger is anchored to the persisted `AiContext.checkInsSinceLastRebuild` counter — NOT `_checkIns.length % 10` — because the 30-day windowed check-in stream saturates and any length-based modulo trigger would misfire on every new entry once the cap is reached.
- `JourneyProvider` keeps BOTH sync (fallback-only) and async (AI-backed) prompt methods. Existing callers using `getMorningPrompt` / `getEveningQuestion` still resolve synchronously from the fallback library — that's intentional so nothing breaks. New UI code should use `generateMorningPrompt` / `generateEveningQuestion` / `generateJournalReflection`.
- go_router creates new router instance on every build via `AppRouter.router(userProvider)` — acceptable for MVP but should be cached in Phase 2.
- Cinematic intro uses manual opacity stepping (not AnimationController) for text fade timing. Scene transitions use a 1.4s AnimationController with easeInOut curve driving the GLSL dissolve shader.
- Fragment shaders are registered under `flutter: shaders:` in pubspec.yaml (not `assets:`). The dissolve shader is loaded once via `DissolveShaderCache` and reused across all transitions.
- `AppRouter.cinematicSeen` is set in `main.dart` before app runs — static field on the router class.
- Onboarding is a single `/onboarding` route with 24 internal pages managed by a `PageView`. Paywall and auth are separate routes (`/paywall`, `/auth`).
- `OnboardingData` model collects all answers during the flow. `UserProvider.createProfile(...)` is called on "See Your Plan" — this now builds the profile in memory and flips the local `onboarding_complete` flag, but the Firestore write only happens once the user signs in on `/auth`. The auth state listener in `main.dart` picks up the in-memory seed and writes it to `users/{uid}/profile/main` with `id` swapped to the Firebase `uid`.
- Paywall screen at `/paywall` is a standalone GymLevels-style paywall with hero image, shimmer offer banner, annual/weekly pricing cards, benefit showcase, quick features, social proof, and fixed bottom CTA. It is RevenueCat-backed via `SubscriptionService`; purchase and restore both update the `premium` entitlement state.
- Auth screen at `/auth` uses real Firebase Auth via `AuthService`. Apple, Google, and Email+Password flows are all wired. Email has an explicit Sign in / Create account mode toggle — do NOT reintroduce silent auto-signup fallback on `invalid-credential` because Firebase returns that for both wrong-password and user-not-found under account enumeration protection. Errors surface via `_friendlyError()` which maps FirebaseAuthException codes to user-readable strings. Loading overlay disables all buttons during network calls.
- Paywall close (X) button routes to `/auth` — users must authenticate before entering the app. No skip-to-journey shortcut remains.
- `AuthService` generates a SHA256-hashed nonce for Apple sign-in (required for Firebase ID token exchange). First-time Apple sign-in writes the given+family name into `FirebaseAuth.currentUser.displayName` (Apple only returns the name on first auth).
- Router has an auth + subscription-aware redirect: unauthenticated users are forced to `/auth` for app routes, and signed-in non-premium users are forced to `/paywall`. Public routes: `/intro`, `/onboarding`, `/paywall`, `/auth`, `/debug`. The router uses `_RouterRefreshListenable`, which wraps `FirebaseAuth.authStateChanges()` plus `SubscriptionService` notifications so sign-in/sign-out/purchase/restore all trigger immediate redirect re-evaluation. `_isSignedIn()` is wrapped in try/catch for safety when Firebase hasn't initialised.
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

## Phase 1C (complete — 2026-04-17)

- [x] Real `AiMentorService` backed by `firebase_ai` + Gemini 2.5 Flash (Google AI, not Vertex)
- [x] System prompt wires in the mentor voice (calm/kind/direct, 1–3 sentences, no markdown/emojis, gentle crisis pointer)
- [x] Three AI methods: `morningPrompt`, `eveningQuestion`, `journalReflection`
- [x] Rolling `users/{uid}/ai/context` summary, rebuilt every 10th check-in (based on the loaded 30-day window)
- [x] App Check wired client-side (`FirebaseAppCheck.activate` with debug providers in dev, DeviceCheck/Play Integrity in release). Enforcement NOT enabled in the Firebase console yet — that's a launch task.
- [x] Loading states in `MorningCheckInScreen`, `EveningReflectionScreen`
- [x] Optional "Ask the mentor" reflection card in `JournalEntryScreen` (surfaces after save, non-blocking)
- [x] Guaranteed fallback to the Dart string library on any failure — users never see a broken prompt
- [x] Unit tests for fallback behaviour (`test/ai_mentor_service_test.dart`)

## Voice Journaling (Phase 2 MVP — complete 2026-04-17 on `voice-journal-mvp`)

Press-and-hold voice journal entries that transcribe on-device via `firebase_ai` (Gemini 2.5 Flash) and persist as regular `JournalEntry` docs, with the original WAV optionally stored in Firebase Storage for playback.

### UI flow
1. User taps the mic icon in the journal header (next to the quill) → `/journal/voice` route opens `VoiceJournalEntryScreen`.
2. Press-and-hold the mic → `record` captures WAV 16 kHz mono PCM16 to a temp file while a rolling waveform (`RecordingWaveform`) shows peak amplitudes every 100 ms. Hard cap at 3:00.
3. Release → state moves to `transcribing`, `AiMentorService.transcribeAudio` sends the clip to Gemini 2.5 Flash as an `InlineDataPart('audio/wav', bytes)`.
4. Transcript lands in an editable text field (title auto-derived from first sentence); user can tweak and hit Save entry.
5. On save:
   - `UserProvider.newJournalEntryId()` returns the entryId + pre-computed storage path.
   - If `StorageService.saveVoiceAudio` is on AND Firebase Storage is reachable, `FirestoreRepository.uploadJournalAudio` pushes the WAV to `users/{uid}/audio/journal/{entryId}.wav`. Failures don't block the save — the transcript is always persisted.
   - Entry is written to Firestore with `audioStoragePath` + `audioDurationSeconds` populated (or null if upload was skipped/failed).
6. Journal list marks voice entries with a mic icon next to the word count.
7. Opening a voice entry renders `JournalAudioPlayer` above the title (amber play/pause button, progress bar, `m:ss / m:ss` counter). Falls back gracefully to "Audio unavailable" if the URL can't be resolved.

### Architecture
- **`VoiceRecordingService`** (`lib/services/voice_recording_service.dart`) — `ChangeNotifier` state machine (`idle` → `recording` → `stopping` → `idle`). Owns an `AudioRecorder`, polls amplitude at 100 ms, auto-stops at 3:00, cleans temp files on cancel/dispose.
- **`AiMentorService.transcribeAudio(File)`** — single-shot Gemini call with `thinkingBudget: 0` (transcription doesn't benefit from reasoning tokens). Returns `''` on any failure so the UI can show an error state rather than crashing.
- **`FirestoreRepository.uploadJournalAudio / downloadJournalAudioUrl / deleteJournalAudio`** — thin wrapper over `FirebaseStorage`. Path scheme mirrors the Firestore tree so `storage.rules` can reuse the `request.auth.uid == uid` check.
- **`JournalEntry.audioStoragePath` / `audioDurationSeconds`** — nullable, only serialised when present. Old text-only entries decode unchanged; `hasAudio` is a convenience getter.
- **`UserProvider.newJournalEntryId()`** — helper so the voice screen can mint an ID, upload the audio, then save the entry with the correct storage path already populated.

### Audio storage schema
```
users/{uid}/audio/journal/{entryId}.wav
```
- 16 kHz mono PCM16 WAV (Gemini-native — no re-encode needed before transcription)
- `storage.rules` mirrors Firestore's uid-ownership rule (`request.auth.uid == uid`)
- Firebase Storage requires the Blaze plan — **currently the project is on Spark**, so uploads fail silently and voice entries land as transcript-only. Flip to Blaze + `firebase deploy --only storage` to enable playback.

### Settings toggle
`You → Settings → Save audio with voice entries` (`StorageService.saveVoiceAudio`, default on). When off, the transcript is kept but the WAV is deleted after transcription completes.

### Platform permissions
- iOS: `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`.
- Android: `android.permission.RECORD_AUDIO` in `android/app/src/main/AndroidManifest.xml`. `FOREGROUND_SERVICE_MICROPHONE` NOT declared — recording auto-stops on app backgrounding via `WidgetsBindingObserver`.

### Gotchas
- **Firebase Storage is not enabled on `noenemies-app` yet** (Spark plan limitation). Voice journaling works end-to-end without it — transcript saves, audio upload no-ops with a debugPrint. Flip to Blaze to unblock playback.
- Amplitude is polled from `record`'s `getAmplitude()` in dBFS and normalised to [0..1] with a −60 dBFS floor. Silence below that reads as 0.
- `WidgetsBindingObserver` in `VoiceJournalEntryScreen` cancels any in-flight recording when the app is backgrounded — prevents a rogue recorder holding the mic across lifecycle events.
- Press-and-hold has a 500 ms tap-guard so accidental taps don't register as recordings.
- The mentor reflection card on regular journal entries is NOT shown on voice entries by default — the voice flow already gave the user a chance to edit the transcript, which is its own form of reflection.

### Files touched
- `lib/services/voice_recording_service.dart` (new)
- `lib/services/ai_mentor_service.dart` (+`transcribeAudio`)
- `lib/services/firestore_repository.dart` (+audio upload/download/delete, Storage injection)
- `lib/services/storage_service.dart` (+`saveVoiceAudio` toggle)
- `lib/models/journal_entry.dart` (+audio fields, `clearAudio` copyWith flag)
- `lib/providers/user_provider.dart` (+`newJournalEntryId`, audio-aware addJournalEntry/delete)
- `lib/screens/journal/voice_journal_entry_screen.dart` (new)
- `lib/screens/journal/journal_screen.dart` (mic button in header, mic icon on voice entries)
- `lib/screens/journal/journal_entry_screen.dart` (audio player bar above title)
- `lib/screens/you/you_tab.dart` (save-audio toggle)
- `lib/widgets/recording_waveform.dart` (new)
- `lib/widgets/journal_audio_player.dart` (new)
- `lib/router/app_router.dart` (`/journal/voice` route)
- `lib/main.dart` (expose `StorageService` + `AiMentorService` via Provider)
- `pubspec.yaml` (+`firebase_storage`, `record`, `just_audio`, `permission_handler`, `path_provider`)
- `ios/Runner/Info.plist` (+mic usage string)
- `android/app/src/main/AndroidManifest.xml` (+RECORD_AUDIO permission)
- `storage.rules` (new), `firebase.json` (storage block)
- `test/firestore_repository_test.dart`, `test/ai_mentor_service_test.dart`, `test/voice_recording_service_test.dart`

## Phase 2 TODO

- RevenueCat sandbox purchase smoke test on a physical device / TestFlight build (SDK wiring is in place)
- App Check ENFORCEMENT — enable on the Firebase console for the `gemini-2.5-flash` endpoint once client-side is rolled out to enough users
- Weekly insight reports (card stack format)
- Voyage Map with real data visualization
- Push notifications (morning + evening)
- Multiple conflict types per user
- **Blaze upgrade + `firebase deploy --only storage`** to unblock voice journal audio playback (transcript-only works today without it)
- Voice mentor (credits at `users/{uid}/credits/voiceMinutes` — Firestore slot reserved)
- ~~Upgrade `firebase_core` 3.x → 4.x~~ (done 2026-04-17 on `chore/firebase-sdk-bump` — full Firebase stack is on the current major versions; iOS Firebase SDK 12.12)

## Legal Compliance (App Store 5.1.1 + 3.1.2 + 5.1.1(v) / Play equivalent)

Landed on `legal-compliance` (2026-04-22). Closes the App Store review gaps that the ASC Privacy URL field alone cannot satisfy.

**Hosted documents (AppStore Copilot — slug shared iOS+Android):**
- Privacy Policy: `https://appstorecopilot.com/legal/8inqwejl/privacy`
- Terms of Use: `https://appstorecopilot.com/legal/8inqwejl/terms`
- Single source of truth in code: [`lib/services/legal_urls.dart`](lib/services/legal_urls.dart). Update there + in `update_legal_document` / `push_legal_to_appstore` to keep everything aligned.

**In-app access points (Guideline 5.1.1):**
- *Paywall footer* — `Terms · Privacy · Restore` text buttons at the bottom of [`lib/screens/paywall/paywall_screen.dart`](lib/screens/paywall/paywall_screen.dart). `Terms` + `Privacy` call `_openLegalUrl` → `launchUrl(LaunchMode.externalApplication)`.
- *You-tab settings sheet* — `Privacy Policy` + `Terms of Use` rows above Sign out. Same `url_launcher` flow in `_openLegalUrl`.
- External-browser launch is intentional: keeps the dark paywall/tab context intact and matches iOS/Android convention for legal links.

**Account deletion (Guideline 5.1.1(v) — mandatory since Jun 2022):**
Flow: *You tab → Settings → Delete account* (red row, below Sign out).
1. Confirmation dialog with destructive "Delete forever" action.
2. `UserProvider.wipeAllUserDataAndDetach()` cancels streams, calls `FirestoreRepository.deleteAllUserData()` — batches all `users/{uid}/**` Firestore docs in chunks of 400, then recursively deletes `users/{uid}/audio/journal/*.wav` in Firebase Storage. Storage recursion gracefully no-ops when the bucket isn't provisioned (Spark plan).
3. `AuthService.deleteAccount()` clears the Google session (if any) and calls `FirebaseAuth.currentUser.delete()`.
4. Routes to `/auth`.
5. `requires-recent-login` is surfaced as a friendly "sign out, sign back in, try again" message — Firestore is already wiped at that point, and the wipe is idempotent, so the retry is safe.

**Store description footers:** Both the iOS description and Play full description now end with hosted PP + ToU URLs (required for Apple 3.1.2 subscription apps; harmless on Play).

**Dependency added:** `url_launcher: ^6.3.1` in `pubspec.yaml`.

**Compliance tool quirks (AppStore Copilot `check_metadata_compliance`):**
- Stale-read bug on iOS — `legalStatus.privacyPolicy.exists` reports `false` even when `read_legal_documents` and `asc localizations list` both confirm the URL is set. Bug is client-side in the tool, not a real rejection risk.
- False-positive on `2.3 External URLs in description` for subscription apps — Apple 3.1.2 explicitly requires the EULA/PP URLs in the description footer. Ignore.

**What still needs doing before submission (NOT in this branch):**
- Select "Standard Apple License Agreement" on ASC App Information (or host a custom EULA and push via a future `push_legal_to_appstore` EULA slot).
- Verify the dedicated Play Console Privacy Policy URL slot is populated (Copilot MCP doesn't currently expose a `push_privacy_url_to_play` tool).
- Complete the App Privacy questionnaire in ASC (email, UUID, journal content, voice audio, purchase records).

## Phase 1A Release Checklist (do before TestFlight)

- [ ] Enable "Sign In with Apple" capability on the App ID in Apple Developer portal
- [ ] Register the **release** keystore SHA-1 (and SHA-256) with the Firebase Android app
- [ ] Add release keystore SHA fingerprints to OAuth 2.0 client in Google Cloud Console
- [ ] Decide on Blaze upgrade if Identity Platform admin APIs are needed
- [ ] Configure Firebase Auth email templates (verification, password reset) with branded copy
- [ ] Add `Firebase.initializeApp` error handling that fails loudly in release mode (currently silently swallows for dev convenience)
- [ ] ASC: select "Standard Apple License Agreement" on App Information (Guideline 3.1.2)
- [ ] ASC: complete App Privacy questionnaire for all data types collected
- [ ] Play Console: set dedicated Privacy Policy URL field on Store Listing
