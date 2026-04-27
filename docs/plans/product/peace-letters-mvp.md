# NoEnemies — Peace Letters MVP Implementation Plan

**Branch:** `plan/peace-letters-mvp`  
**Product area:** Crew tab → Peace Exchange  
**Status:** Planning branch  
**Principle:** Anonymous human witness, not anonymous social media.

## 1. Product thesis

Peace Letters should become the signature social mechanic inside NoEnemies. It turns the product from:

> AI mentor + private journal

into:

> AI mentor + private journal + anonymous human witness network

The mechanic should not copy anonymous confession apps. NoEnemies owns a more specific transformation loop:

> **Raw → Refined → Sealed → Witnessed → Offered → Released**

A user writes the war down, transforms it into a letter of peace, lets a small number of strangers witness it, receives Peace Offerings, then saves or releases what helped.

## 2. Competitive positioning

### Similar products and lessons

| Product type | What works | What breaks | NoEnemies improvement |
|---|---|---|---|
| Sincerely / Honestly anonymous letters | Simple daily letter rhythm; 3 letters/night is easy to understand | Can become “vent/confess and wait for validation” | Make every letter part of a peace ritual with intent, reflection, and release |
| Kind Words / PaperPlane kindness networks | One-shot support is safer than DMs; collectibles make kindness feel rewarding | Can be lightweight/generic if detached from personal growth | Tie offerings into Book of Peace, character progression, Peace Given/Received stats |
| Slowly / Silent Ink slow letters | Delayed delivery increases thoughtfulness | Ongoing penpal threads cause ghosting, attachment, identity leakage, romance drift | Use slow delivery windows but avoid open-ended correspondence at MVP |
| 7 Cups peer support | Structure/training improves responder quality | Therapy-adjacent expectations and safety burden | Use “peer witness, not therapy” copy + guided response scaffolds |
| NGL / Tellonym / Whisper anonymous messaging | Viral anonymous curiosity loops | Cyberbullying, minors, harassment, identity reveal mechanics, regulatory risk | No profile links, no friend graph, no identity reveals, no public replies, no DMs |

### Differentiator

Most anonymous apps ask:

> “What do you want to confess?”

NoEnemies should ask:

> **“What part of the war are you ready to lay down?”**

## 3. MVP scope

### In scope

- Replace the Crew placeholder with **Peace Exchange**.
- Write a Peace Letter from guided recipient archetypes and intents.
- AI-assisted **Peace Alchemy** step: transform a raw vent into a safer, clearer Peace Letter.
- Submit letter into an anonymous moderated pool.
- Receive a small nightly bundle of letters to witness.
- Respond with structured support modes and optional custom text.
- Receive replies as **Peace Offerings**.
- Save helpful offerings into Book of Peace / journal.
- Track Peace Given, Peace Received, Offerings Saved.
- Report letters/replies.
- Crisis/self-harm handling and “peer support, not therapy” copy from day one.

### Explicitly out of scope for MVP

- No DMs.
- No profiles.
- No public feed.
- No likes/upvotes.
- No identity reveal.
- No reply-to-reply conversations.
- No friend graph or contacts import.
- No “who sent this?” monetisation.
- No unmoderated custom replies.

## 4. UX structure

### Crew tab becomes Peace Exchange

```
Peace Exchange
├─ Tonight's Letters        // letters waiting for you to witness
├─ Write a Peace Letter
├─ Peace Offerings          // replies received to your letters
├─ Book of Peace            // saved offerings + journal wisdom
└─ Peace Given / Received   // quiet stats, not public clout
```

### Primary flow: write

1. **Raw Draft**
   - User writes privately with permissive copy: “Write the messy truth first. We’ll soften it before it reaches anyone.”
2. **Choose recipient archetype**
   - Someone I can’t forgive
   - The version of me I hate
   - The person I miss
   - The enemy in my head
   - Anyone who understands
3. **Choose intent**
   - I need to be heard
   - I need forgiveness
   - I need perspective
   - I need to let go
   - I want to help someone else
4. **Peace Alchemy**
   - AI suggests a public-safe version.
   - Removes personal info.
   - Flags crisis/self-harm.
   - Softens cruelty without sanitising pain.
   - Preserves the user’s voice.
5. **Seal the Letter**
   - User reviews final letter.
   - Copy: “Once sealed, strangers can witness this. They will never see your identity.”
6. **Moderation + queue**
   - Letter enters pending moderation.
   - If approved, it can be assigned in nightly bundles.

### Primary flow: witness

1. User opens **Tonight’s Letters**.
2. They receive up to 3 assigned letters.
3. They choose a response mode:
   - `I hear you`
   - `I've felt this too`
   - `A softer way to see this`
   - `A letter back`
   - `A quiet blessing`
4. They can send a canned response or add custom text.
5. Custom text goes through moderation before delivery.
6. Writer receives it as a **Peace Offering**.

### Primary flow: receive offering

1. Writer sees “Someone witnessed your letter.”
2. They can:
   - Keep in Book of Peace.
   - Release with a small burn/sea ritual animation.
   - Write private journal follow-up.
   - Report.

## 5. Monetisation model

NoEnemies currently has a hard paywall and `premium` RevenueCat entitlement. For MVP, keep Peace Exchange premium-only.

### Premium includes

- Peace Letters access.
- Write letters.
- Receive nightly letters.
- Send structured + custom replies.
- Save offerings to Book of Peace.
- AI Peace Alchemy.
- Guided rituals.

### Optional later experiments

- Pre-paywall “sealed first letter” onboarding preview, but do not send it to real users until purchase/auth.
- Boosted delivery for more thoughtful replies, only after safety and supply quality are proven.

## 6. Safety posture

This feature is user-generated content around emotionally heavy topics. Safety is core product infrastructure, not polish.

### Launch rules

- Recommend 18+ / adult audience positioning at launch to avoid anonymous-app/minor risk.
- Copy: “Peer support, not therapy.”
- Crisis copy and emergency resources shown when self-harm risk is detected.
- No personal information rule before submission.
- Report button on every letter/offering.
- App Check required for write functions.
- Auth required.
- Premium entitlement required.
- Rate limits for new accounts.

### Moderation layers

1. **Client preflight**
   - Fast local/AI warning for PII, crisis, obvious abuse before submission.
   - This is UX guidance only, not trusted enforcement.
2. **Server enforcement**
   - Callable Cloud Function validates auth, App Check, premium entitlement, rate limits.
   - Moderates content before it enters the exchange.
3. **Report-based quarantine**
   - Reported letters/offers are hidden from future assignment after threshold or high-severity report.
4. **Admin review queue**
   - Minimum viable: Firestore-backed moderation queue + console workflow.
   - Later: internal web dashboard.

### Moderation decisions

- `approved`: can be assigned.
- `needs_edit`: returned to writer with reason.
- `private_only`: safe to save privately but not to send to strangers.
- `crisis`: block exchange submission, show resources, offer private journal/mentor support.
- `rejected`: abusive/unsafe.

## 7. Backend architecture

### Why Cloud Functions are required

A client-only Firestore implementation cannot safely run an anonymous exchange because users could tamper with assignment, see metadata, bypass moderation, or write replies directly. The MVP needs Cloud Functions/Admin SDK as the trusted layer.

**Implication:** this likely requires Firebase Blaze for Cloud Functions, scheduled delivery, and serious UGC safety. This is the same direction as voice audio storage/Cloud Functions work.

### Firestore schema

Keep sensitive identity mapping out of client-readable shared documents.

```text
users/{uid}/
├─ peaceLetters/{letterId}              // user's own drafts/submissions; private to user
├─ peaceInbox/{assignmentId}            // server-written letter snapshots assigned to this user
├─ peaceOfferingsReceived/{offeringId}  // server-written replies to user's letters
├─ peaceOfferingsSent/{offeringId}      // user's sent offerings, private record
└─ peaceStats/main                      // peaceGiven, peaceReceived, savedOfferings, reports, rate windows

peacePool/{letterId}                    // server-only; approved anonymized pool
├─ offerings/{offeringId}               // server-only canonical offerings
└─ reports/{reportId}                   // server-only report rollup

peacePrivate/{letterId}                 // server-only mapping: authorUid, raw draft metadata, moderation details
peaceAssignments/{assignmentId}         // server-only assignment index: uid + letterId + expiresAt + state
peaceModerationQueue/{itemId}           // server-only moderation audit/review queue
peaceReports/{reportId}                 // server-only global report records
```

### Client-readable snapshots

Users should not read `peacePool` directly. Instead, Cloud Functions write redacted snapshots into their own subtree:

```json
users/{uid}/peaceInbox/{assignmentId} = {
  "assignmentId": "...",
  "letterId": "...",
  "body": "redacted approved letter text",
  "recipientArchetype": "enemyInMyHead",
  "intent": "needPerspective",
  "themes": ["resentment", "shame"],
  "createdAt": <Timestamp>,
  "assignedAt": <Timestamp>,
  "expiresAt": <Timestamp>,
  "respondedAt": null,
  "status": "waiting"
}
```

The writer receives redacted offerings in their own subtree:

```json
users/{authorUid}/peaceOfferingsReceived/{offeringId} = {
  "offeringId": "...",
  "letterId": "...",
  "responseMode": "softerPerspective",
  "body": "approved offering text",
  "createdAt": <Timestamp>,
  "savedToBook": false,
  "reportedAt": null
}
```

### Security rules

- Users can read/write their own private drafts.
- Users can read their own inbox/offering/stat docs.
- Users cannot read/write `peacePool`, `peacePrivate`, `peaceAssignments`, `peaceModerationQueue`, or global report docs.
- Users cannot directly create delivered offerings; they must call a function.
- Reports can be created through callable function, not raw client writes.

## 8. Cloud Functions / callable API

### `submitPeaceLetter`

Input:

```json
{
  "draftId": "...",
  "rawText": "...",
  "finalText": "...",
  "recipientArchetype": "enemyInMyHead",
  "intent": "needPerspective",
  "themes": ["resentment", "shame"]
}
```

Responsibilities:

- Verify auth.
- Verify App Check.
- Verify RevenueCat premium entitlement or cached entitlement mirror.
- Enforce daily/user rate limits.
- Validate length.
- Run moderation/PII/crisis checks.
- Write user submission status.
- Write server-only `peacePool` + `peacePrivate` if approved.

### `assignNightlyPeaceLetters`

Scheduled function, once/day per timezone bucket initially.

Responsibilities:

- Find eligible premium users.
- Assign up to 3 letters each.
- Never assign own letter.
- Avoid assigning same letter repeatedly to same user.
- Prefer letters with low response count.
- Match by language, theme, conflict type, and selected intent.
- Write snapshots to `users/{uid}/peaceInbox`.

### `sendPeaceOffering`

Responsibilities:

- Verify auth/app check/premium.
- Ensure assignment belongs to responder and is unexpired.
- Validate response mode matches allowed intent/mode matrix.
- Moderate custom body.
- Write canonical offering to server-only pool.
- Write offering snapshot to author’s `peaceOfferingsReceived`.
- Write sent record to responder’s `peaceOfferingsSent`.
- Increment stats.

### `savePeaceOfferingToBook`

Responsibilities:

- Verify recipient owns offering.
- Mark offering saved.
- Create a Journal/Book of Peace entry or saved-offering reference.

### `reportPeaceContent`

Responsibilities:

- Verify user was assigned/received the content.
- Write global report.
- Quarantine content if severe/threshold exceeded.
- Increment safety stats.

## 9. Matching and quality system

### Assignment score

Initial score:

```text
score = freshness
      + lowResponseBoost
      + themeAffinity
      + intentNeedBoost
      - reportRisk
      - repeatedExposurePenalty
```

### Hidden responder quality

No public clout. Privately track:

- Offerings sent.
- Offerings saved by recipients.
- Reports received.
- Toxicity/PII moderation misses.
- Too-short/low-effort custom replies.

Use this to:

- Give trusted responders more letters.
- Throttle low-quality users.
- Protect vulnerable writers.

## 10. AI usage

Use existing `AiMentorService` patterns where possible, but separate generation from enforcement.

### Client-visible AI: Peace Alchemy

- Rewrite raw draft into a safer Peace Letter.
- Suggest recipient archetype, intent, and themes.
- Explain edits gently.
- Never diagnose/prescribe.
- Crisis response uses existing gentle professional-help style.

### Server moderation AI

Should be deterministic-ish and structured:

```json
{
  "decision": "approved|needs_edit|private_only|crisis|rejected",
  "risk": "low|medium|high|critical",
  "categories": ["pii", "self_harm", "harassment", "sexual", "minor_safety"],
  "reason": "short user-safe reason",
  "suggestedEdit": "optional"
}
```

## 11. App files likely touched

### New models

- `lib/models/peace_letter.dart`
- `lib/models/peace_offering.dart`
- `lib/models/peace_intent.dart`
- `lib/models/peace_recipient_archetype.dart`
- `lib/models/peace_theme.dart`
- `lib/models/peace_assignment.dart`
- `lib/models/peace_stats.dart`

### Services

- `lib/services/peace_exchange_repository.dart`
- `lib/services/peace_alchemy_service.dart`
- `lib/services/peace_safety_service.dart`

### Provider

- `lib/providers/peace_exchange_provider.dart`

### Screens

- Replace `lib/screens/crew/crew_tab.dart` with Peace Exchange dashboard.
- Add `lib/screens/peace/write_peace_letter_screen.dart`.
- Add `lib/screens/peace/peace_letter_review_screen.dart`.
- Add `lib/screens/peace/peace_inbox_screen.dart`.
- Add `lib/screens/peace/peace_letter_detail_screen.dart`.
- Add `lib/screens/peace/peace_offerings_screen.dart`.

### Widgets

- `lib/widgets/peace_letter_card.dart`
- `lib/widgets/peace_offering_card.dart`
- `lib/widgets/peace_response_mode_selector.dart`
- `lib/widgets/peace_seal_animation.dart`
- `lib/widgets/peer_support_disclaimer.dart`

### Router

- Add `/peace/write`, `/peace/inbox`, `/peace/offerings`, `/peace/letter/:id` routes.
- Keep under existing premium/auth route guard.

### Firebase

- `firestore.rules`
- `firestore.indexes.json`
- `functions/` or equivalent Firebase Functions workspace (new if not already present)

## 12. Implementation phases

### Phase A — Product/UI skeleton (1 day)

- Convert Crew tab placeholder into Peace Exchange dashboard.
- Add static route/screens with mock state.
- Add copy, disclaimers, and empty states.
- Add design language: sealed letters, amber wax mark, parchment cards, night-watch framing.

Deliverable: UI is navigable and screenshots can be reviewed before backend work.

### Phase B — Models + private drafts (1 day)

- Add Dart models/enums.
- Add repository methods for user-private drafts/status.
- Save raw drafts under user subtree only.
- Unit tests for serialization.

Deliverable: user can write and save a private Peace Letter draft.

### Phase C — Peace Alchemy client flow (1-2 days)

- Add AI rewrite/safety preflight method.
- Suggest archetype/intent/themes.
- Add crisis/PII warnings before submission.
- Fallback to deterministic local checks if AI unavailable.

Deliverable: raw draft becomes a reviewed/sealed draft locally.

### Phase D — Cloud Functions + security rules (2-3 days)

- Add callable functions for submit, offer, save, report.
- Add scheduled nightly assignment.
- Add Firestore rules denying client access to server-only pools.
- Add App Check/auth/premium checks.
- Add moderation queue schema.

Deliverable: safe server-mediated exchange is possible.

### Phase E — Inbox + offerings loop (2 days)

- Hook dashboard to live Firestore streams.
- Implement assigned letter inbox.
- Implement structured response modes.
- Implement offering delivery and save-to-Book.
- Stats increment.

Deliverable: full end-to-end letter → witness → offering → save loop.

### Phase F — Safety hardening + launch QA (2 days)

- Abuse/report test matrix.
- Rate limit tests.
- Crisis flow QA.
- PII redaction QA.
- Empty pool/cold-start handling.
- Seed/practice letter policy.

Deliverable: internal beta-ready MVP.

## 13. Cold-start plan

Do not fake real user replies. That would repeat the worst anonymous-app anti-pattern.

Acceptable cold-start tools:

- Founder-authored seed letters clearly marked as “Founding Letter”.
- Mentor practice letters clearly marked as “Reflection Exercise”.
- Let early users write letters but set expectations: “Your letter will be witnessed as the circle grows.”
- Route first cohort through a limited beta group.

## 14. Push/retention hooks

Later but designed now:

- Evening notification: “Three letters are waiting to be witnessed.”
- Offering notification: “Someone left a Peace Offering for your letter.”
- Weekly recap: “You helped 7 people feel less alone.”
- Check-in prompt: “Is there a letter you need to write tonight?”

## 15. Analytics

Track product health without exposing content:

- `peace_letter_draft_started`
- `peace_letter_alchemy_completed`
- `peace_letter_submitted`
- `peace_letter_approved`
- `peace_letter_needs_edit`
- `peace_letter_crisis_blocked`
- `peace_assignment_opened`
- `peace_offering_sent`
- `peace_offering_received`
- `peace_offering_saved`
- `peace_content_reported`
- `peace_exchange_weekly_active`

## 16. Open decisions

1. **Age posture:** recommend adult/18+ framing for anonymous UGC. Confirm store strategy.
2. **Blaze timing:** server-mediated exchange needs Cloud Functions; align with existing Blaze decision for voice audio.
3. **Human moderation:** decide whether Firestore console is enough for beta or whether to build a tiny admin page.
4. **Premium-only vs preview:** keep premium-only for launch, but decide whether onboarding can collect a sealed unsent first letter.
5. **Book of Peace integration:** save offerings as journal entries, separate saved-offering docs, or both.

## 17. MVP acceptance criteria

- A signed-in premium user can draft, refine, and submit a Peace Letter.
- Unsafe/crisis/PII-heavy letters are blocked or routed private-only.
- A user cannot read global letter pool or discover author identity.
- A user receives no more than 3 assigned letters/day.
- A user cannot receive their own letter.
- A user can send a structured offering only for assigned letters.
- Writer receives approved offerings privately.
- Writer can save an offering into Book of Peace.
- Reports quarantine content when severe or repeated.
- All server-only collections deny client access in rules.
- Unit tests cover model serialization and rule-critical access patterns.
- Integration smoke covers full happy path and at least 3 safety failures.

## 18. Recommended first implementation branch after this plan

After review, create:

```bash
git checkout -b feature/peace-letters-mvp
```

Start with Phase A + B so we can validate the ritual and UI before committing to the backend complexity.
