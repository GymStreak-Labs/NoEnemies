# No Enemies

**Tagline:** "You've been fighting long enough."
**Business:** GymStreak Labs
**Platform:** iOS + Android (Flutter)
**Monetisation:** Premium only (hard paywall, no free tier)

## Overview

A personal peace and conflict resolution journey app inspired by Vinland Saga's "I have no enemies" transformation. The core thesis: every enemy you perceive is a reflection of a war inside you. End the inner war, and you have no enemies.

## Tech Stack

- **Framework:** Flutter (cross-platform iOS + Android)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM)
- **AI:** Claude API or Gemini for the personalised mentor
- **Subscriptions:** RevenueCat
- **Pricing:** Weekly $4.99 / Annual $59.99 (no monthly)

## Project Structure

```
NoEnemies/
├── CLAUDE.md              # This file
├── docs/
│   └── plans/
│       └── product-plan.md  # Full product plan
├── lib/                   # Flutter source (TBD)
├── ios/                   # iOS platform code (TBD)
├── android/               # Android platform code (TBD)
└── pubspec.yaml           # Dependencies (TBD)
```

## App Structure (4 Tabs)

1. **Journey (Home)** — Voyage Map, today's card, peace mission, streak
2. **Reflect** — AI prompts, journal, weekly report, Book of Peace
3. **Crew** — Small group (5-8), check-ins, challenges, community feed
4. **You** — Character evolution, stats, dimensions, conflict breakdown, settings

## Key Flows

- **Onboarding:** Quiz (conflict type identification) -> Paywall
- **Morning:** Push notification -> Mood check-in (2 min) -> AI prompt -> Set intention
- **Midday:** Optional energy check -> Micro-exercise if struggling
- **Evening:** Push notification -> Guided reflection (3-5 min) -> Rate dimensions -> See map update
- **Weekly:** Sunday insight report (personalised trends, pattern detection)
- **Monthly:** Arc progression through journey stages

## Conflict Types

- Resentment (grudges, parents, exes, friends)
- Self-hatred (not forgiving past mistakes)
- Comparison (seeing others as competitors)
- Workplace conflict (toxic environments)
- Relationship conflict (partner, family)
- Identity conflict (who you are vs who you should be)
- Grief/loss (anger at unfairness)
- Addiction recovery (internal war)

## Gamification

- Character evolution: dark warrior -> peaceful figure (visual transformation)
- Days of Peace streak (breaks acknowledged, not punished)
- Peace vs War ratio trending over time
- Titles: Warrior -> Wanderer -> Seeker -> Peacemaker
- Book of Peace: collected wisdom, shareable

## Anti-Churn Mechanisms

1. Accumulating AI Mentor (irreplaceable by month 3)
2. Voyage Map (visual autobiography, sunk-cost + identity)
3. Weekly Insight Report (recurring "aha" moments)
4. Crews (5-8 people matched by conflict type, social lock-in)
5. Evolving Challenge System (AI-generated, seasonal themes)

## Build & Run

TBD — Flutter project not yet scaffolded.

## Integrations

- RevenueCat for subscriptions
- Firebase Auth / Firestore / Cloud Functions / FCM
- Claude API or Gemini for AI mentor
- Gleap for support (TBD)

## Gotchas

- Hard paywall: no free tier. Onboarding quiz IS the product demo.
- No monthly plan by design — force annual commitment or weekly trial.
