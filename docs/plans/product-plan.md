# No Enemies — Product Plan

## Overview

**App Name:** No Enemies
**Tagline:** "You've been fighting long enough."
**Business:** GymStreak Labs
**Platform:** iOS + Android (Flutter)
**Monetisation:** Premium only — no free tier
**Pricing:** Weekly $4.99 or Annual $59.99 (no monthly — force annual commitment)

## Core Philosophy

Inspired by Vinland Saga's "I have no enemies" transformation:

- Every enemy you perceive is a reflection of a war inside you
- End the inner war, and you have no enemies
- True strength is choosing peace, not winning fights
- The journey from warrior to peacemaker is the product

## Conflict Types Addressed

1. **Resentment** — grudges, parents, exes, friends
2. **Self-hatred** — not forgiving past mistakes
3. **Comparison** — seeing others as competitors
4. **Workplace conflict** — toxic environments
5. **Relationship conflict** — partner, family
6. **Identity conflict** — who you are vs who you should be
7. **Grief/loss** — anger at unfairness
8. **Addiction recovery** — internal war

## Core Daily Loop

### Morning Check-in (2 min)
- Mood tap (emoji/slider)
- AI prompt personalised to your conflict type and recent patterns
- Set daily intention

### Midday Pulse (optional)
- Energy check
- Micro-exercise if struggling (breathing, reframe, gratitude)

### Evening Reflection (3-5 min)
- Guided questions tailored to the day's intention
- Rate dimensions (peace, resentment, self-compassion, etc.)
- See Voyage Map update

### Weekly (Sunday)
- Insight report — personalised trends, pattern detection, focus suggestion
- Card stack format, swipeable

### Monthly
- Arc progression through journey stages
- Character evolution milestone

## 5 Anti-Churn Mechanisms

### 1. Accumulating AI Mentor
Builds a model of YOU over time. By month 3, it knows your triggers, patterns, and growth areas better than you do. Irreplaceable — switching apps means starting over.

### 2. Voyage Map
Visual autobiography of your peace journey. Each day adds to the map. Creates sunk-cost investment AND identity ("I'm on day 147 of my peace journey"). Shareable milestones.

### 3. Weekly Insight Report
Recurring "aha" moments that demonstrate active subscription value. "This week you handled 3 conflict triggers without spiraling — that's up from 1 last month." Makes progress tangible.

### 4. Crews
Small groups of 5-8 people, matched by conflict type. Weekly check-ins, shared challenges, accountability. Social lock-in — you don't want to let your crew down.

### 5. Evolving Challenge System
AI-generated personalised challenges based on your specific conflict patterns. Seasonal themes (holiday family stress, New Year self-reflection). Never repetitive — always relevant.

## Gamification (Simple, Not Gamey)

### 1. Character Evolution
Visual transformation from dark/armoured warrior to peaceful, light figure. Reflects actual progress. Not cartoonish — artistic, meaningful.

### 2. Days of Peace
Streak counter, but breaks are acknowledged not punished. "You had a hard day. That's okay. Your 47-day foundation doesn't disappear." Compassionate design.

### 3. Peace vs War Ratio
Trending metric over time. Not binary good/bad — shows the direction you're moving. Celebrates small shifts.

### 4. Titles
Progression through meaningful stages:
- **Warrior** — still fighting, but aware
- **Wanderer** — seeking a different path
- **Seeker** — actively working on peace
- **Peacemaker** — living it

### 5. Book of Peace
Collected wisdom from your journey — insights, breakthroughs, mantras that worked. Shareable. Becomes YOUR personal philosophy book.

## App Structure (4 Tabs)

### Tab 1: Journey (Home)
- Voyage Map (visual, interactive)
- Today's card (morning intention or evening prompt)
- Current peace mission
- Streak / Days of Peace
- Quick access to check-in

### Tab 2: Reflect
- AI-powered prompts (personalised)
- Journal (free-write or guided)
- Weekly insight report
- Book of Peace (collected wisdom)
- Dimension ratings history

### Tab 3: Peace Letters
- Private letter ritual for anger, guilt, grief, envy, shame, heartbreak, resentment, and loneliness
- Write a Peace Letter, seal it privately, revisit it, and later release/save wisdom to Book of Peace
- AI Peace Alchemy can help soften a raw vent into a clearer letter
- Longer-term: anonymous human witness exchange can layer on only after launch validation and safety infrastructure

### Tab 4: You
- Character visualization (current form)
- Stats dashboard (peace ratio, streak, dimensions)
- Conflict type breakdown
- Journey milestones
- Settings / account

## Key Screens

### Onboarding Flow
1. Welcome — "You've been fighting long enough."
2. Conflict identification quiz (5-7 questions)
3. Personalised conflict profile reveal
4. Character starting form shown
5. **Hard paywall** — Weekly $4.99 or Annual $59.99

### Morning Flow
Push notification -> App opens to check-in -> Mood tap -> AI prompt -> Set intention -> Done (2 min)

### Evening Flow
Push notification -> App opens to reflection -> Guided questions -> Rate dimensions -> See map update -> Done (3-5 min)

### Weekly Report
Card stack format (like Spotify Wrapped but weekly):
- Key stats
- Pattern detected
- Biggest win
- Focus for next week
- Shareable summary card

## Hard Paywall Justification

- **Audience self-selects:** High intent from anime/philosophy/self-improvement communities
- **UGC ads pre-sell value** before download — users arrive already convinced
- **Personalisation quiz IS the product demo** — they see their conflict profile before paying
- **Free tier would dilute, not convert** — this is a commitment product, not a sampling product
- **Weekly option reduces barrier** — $4.99/week lets people try without annual commitment

## Tech Stack

- **Framework:** Flutter (cross-platform iOS + Android)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM)
- **AI Mentor:** Claude API or Gemini for personalised prompts, insights, and mentor persona
- **Subscriptions:** RevenueCat
- **Push Notifications:** Firebase Cloud Messaging
- **Analytics:** Firebase Analytics
- **Crash Reporting:** Firebase Crashlytics
- **Support:** Gleap SDK

## Implementation Phases

### Phase 1: MVP
- Onboarding quiz + paywall
- Morning check-in + evening reflection
- Basic AI prompts (not fully personalised yet)
- Streak tracking
- Character visualization (2 states: start + current)
- Single conflict type per user

### Phase 2: Intelligence
- Accumulating AI mentor (learns from journal + check-ins)
- Weekly insight reports
- Voyage Map (visual journey)
- Multiple conflict types per user
- Character evolution (multiple stages)

### Phase 3: Social
- Anonymous Peace Exchange / human witness network only if private Peace Letters show strong usage
- Must be moderated and server-mediated — no DMs, no profiles, no public feed at MVP
- Crews (matching, check-ins, challenges) can layer on later if the safety loop works
- Shareable milestones
- Book of Peace sharing

### Phase 4: Depth
- Evolving challenge system
- Seasonal themes
- Advanced dimension tracking
- Partner/family conflict modules
- Guided meditation/breathing integration

## Files Affected

TBD — project not yet scaffolded. This plan will be updated as development begins.

## Verification

- Onboarding flow completes without errors
- Paywall shows correct pricing (Weekly $4.99 / Annual $59.99)
- RevenueCat processes test purchases
- Morning/evening push notifications fire at correct times
- AI prompts are personalised to conflict type
- Streak tracking persists across sessions
- Character visualization updates with progress
