# NoEnemies — Peace Letters Launch Plan

**Product area:** Peace tab / former Crew tab
**Scope decision:** Launch as a **private ritual**, not an anonymous social network.
**Why:** Peace Letters is emotionally strong, but a live anonymous exchange adds moderation, abuse, matching, cold-start, App Store, and operational complexity. Ship the personal ritual first; validate usage before building the human witness network.

## Product thesis

Peace Letters helps a user write down the inner war they keep carrying:

> anger, guilt, grief, envy, shame, heartbreak, resentment, loneliness.

The launch loop is deliberately simple:

> **Write raw → choose intent → seal privately → revisit → soften/release/save wisdom**

This keeps the feature native to NoEnemies without turning the app into anonymous social media.

## What ships in V1

### Peace tab

The old Crew placeholder becomes **Peace Letters**:

```
Peace Letters
├─ Write a Peace Letter
├─ Private drafts
├─ Sealed letters
├─ Peace Alchemy (next step)
└─ Release / save to Book of Peace (next step)
```

### Write flow

1. Choose who the letter is to:
   - Someone I can’t forgive
   - The version of me I hate
   - The person I miss
   - The enemy in my head
   - The part of me that understands
2. Choose what the user needs:
   - I need to be heard
   - I need forgiveness
   - I need perspective
   - I need to let go
   - I want to become softer
3. Choose emotional themes:
   - Anger, guilt, grief, envy, shame, heartbreak, resentment, loneliness
4. Write the raw letter privately.
5. Save as draft or seal privately.

### Firestore

Only private user-scoped data is written:

```text
users/{uid}/peaceLetters/{letterId}
```

No shared anonymous pool exists in V1.

## Explicit non-goals for launch

Do **not** build these yet:

- Anonymous user-to-user delivery
- Nightly letters from strangers
- Peace Offerings / replies
- Peace Given / Peace Received stats
- Public/community feed
- DMs
- Profiles
- Identity reveal mechanics
- Client-readable global letter pool
- Client-writable global letter pool

## Why this is safer

Private Peace Letters keep the emotional differentiation while avoiding the heavy risks of anonymous UGC:

- No moderation queue needed for launch.
- No cold-start problem.
- No abuse/report workflow required before launch.
- No user-to-user safety burden.
- No App Store anonymous-social risk at MVP.
- No Cloud Functions dependency for V1.

## Future: Peace Exchange

If usage proves that people repeatedly write, seal, revisit, and value Peace Letters, then we can build **Peace Exchange** later as a server-mediated human witness network.

That later version must use Cloud Functions/Admin SDK for:

- moderation
- assignment
- identity protection
- report/quarantine flows
- App Check
- rate limits
- premium entitlement checks

The future exchange should still avoid:

- DMs
- profiles
- public comments
- likes/upvotes
- identity reveals
- friend graph mechanics

## Implementation phases

### Phase A — Private ritual skeleton

- Replace Crew placeholder with Peace Letters dashboard.
- Add private letter models and provider.
- Add `/peace/write` route.
- Add `/peace/letter/:id` detail route.
- Save drafts and sealed letters under `users/{uid}/peaceLetters`.

### Phase B — Peace Alchemy

- Add AI rewrite/preflight: raw draft → softened private letter.
- Detect obvious crisis/self-harm and show support copy.
- Warn about personal info.
- Keep fallback local copy if AI unavailable.

### Phase C — Release / Book of Peace

- Let user save a line/insight to Book of Peace.
- Add a small release ritual animation for sealed letters.
- Track private stats: letters written, sealed, released.

### Phase D — Decide on network

Only after V1 usage data:

- Do people write letters?
- Do they seal them?
- Do they come back to reread/release?
- Do they ask for human witness?

If yes, plan Peace Exchange as a separate backend-heavy phase.

## Acceptance criteria for V1

- Signed-in premium user can write a Peace Letter.
- User can save a private draft.
- User can seal a private letter.
- User can view saved/sealed letters.
- No global anonymous pool exists.
- No user can read another user’s letters.
- Account deletion wipes `peaceLetters`.
- Tests cover model serialization.
