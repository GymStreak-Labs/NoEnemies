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
- **Navigation:** go_router
- **Storage:** SharedPreferences (local, MVP — no Firebase yet)
- **AI:** Mock AiService (will be Claude/Gemini in Phase 2)
- **Subscriptions:** UI-only paywall (RevenueCat in Phase 2)
- **Typography:** Google Fonts (Inter)
- **Animations:** flutter_animate

## Build & Run

```bash
flutter pub get
flutter run
# or flutter run -d <device_id>
```

No Firebase, no API keys, no special environment setup needed for MVP.

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
│   │   ├── storage_service.dart   # SharedPreferences wrapper
│   │   └── ai_service.dart        # Mock AI prompts by conflict type
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

- Hard paywall: no free tier. Close button on paywall skips to app (MVP only).
- No monthly plan by design — force annual commitment or weekly trial.
- SharedPreferences stores all data as JSON strings — no Firebase yet.
- AiService returns pre-written prompts keyed by conflict type + mood — not real AI.
- go_router creates new router instance on every build via `AppRouter.router(userProvider)` — acceptable for MVP but should be cached in Phase 2.
- Cinematic intro uses manual opacity stepping (not AnimationController) for text fade timing. Scene transitions use a 1.4s AnimationController with easeInOut curve driving the GLSL dissolve shader.
- Fragment shaders are registered under `flutter: shaders:` in pubspec.yaml (not `assets:`). The dissolve shader is loaded once via `DissolveShaderCache` and reused across all transitions.
- `AppRouter.cinematicSeen` is set in `main.dart` before app runs — static field on the router class.
- Onboarding is a single `/onboarding` route with 24 internal pages managed by a `PageView`. Paywall and auth are separate routes (`/paywall`, `/auth`).
- `OnboardingData` model collects all answers during the flow. Profile is created when tapping "See Your Plan" on the celebration page, before navigating to `/paywall`.
- Paywall screen at `/paywall` is a standalone GymLevels-style paywall with hero image, shimmer offer banner, annual/weekly pricing cards, benefit showcase, quick features, social proof, and fixed bottom CTA. UI-only for MVP.
- Auth screen at `/auth` has Apple/Google/Email sign-in buttons. All are stubs for MVP — they just navigate to `/journey`. Email form is expandable with validation.
- Paywall close (X) button skips auth and goes directly to `/journey` (MVP only — remove before App Store submission).
- `UserProfile` now has extra onboarding fields: `displayName`, `conflictTarget`, `conflictDuration`, `conflictIntensity`, `conflictStyle`, `preferredCheckInTime`, `personalIntention`, `previousAttempts`.
- Processing screen (page 21) runs conflict type calculation and auto-advances after ~7s.
- Reveal screen (page 22) runs a timed sequence showing content progressively. Back button is hidden on processing, reveal, and celebration pages.

## Phase 2 TODO

- Firebase Auth + Firestore backend
- Real Claude/Gemini AI mentor integration
- RevenueCat subscription integration
- Weekly insight reports (card stack format)
- Voyage Map with real data visualization
- Push notifications (morning + evening)
- Multiple conflict types per user
