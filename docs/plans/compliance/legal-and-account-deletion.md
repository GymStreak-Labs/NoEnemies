# Legal Compliance + Account Deletion (App Store 5.1.1 / 3.1.2 / 5.1.1(v))

## Overview
Close the App Store / Play Store review gaps that the ASC "Privacy Policy URL" field alone cannot satisfy. This branch adds in-app access points for the hosted Privacy Policy + Terms of Use, and implements the mandatory account-deletion flow required by Apple Guideline 5.1.1(v).

## Current State
- Privacy Policy + Terms of Use are hosted via AppStore Copilot (`update_legal_document`) at:
  - `https://appstorecopilot.com/legal/8inqwejl/privacy`
  - `https://appstorecopilot.com/legal/8inqwejl/terms`
- ASC app-info `privacyPolicyUrl` is set via the new `push_legal_to_appstore` MCP tool.
- Both iOS + Play description footers include both URLs.
- Before this branch: no in-app link to either doc; no account-deletion flow.

## Goals
1. **5.1.1(i) — In-app privacy policy access.** Tappable links to both docs on the paywall and in the You-tab settings.
2. **3.1.2 — Subscription-app legal surfaces.** EULA/PP accessible both from the paywall (pre-purchase) and Settings (post-purchase).
3. **5.1.1(v) — Account deletion in-app.** Single Settings row that wipes all user data + deletes the Firebase Auth user.
4. **Make the policy URL a single source of truth.** One constants file so future edits don't drift across paywall / You-tab / store listings.

## Implementation

### New: `lib/services/legal_urls.dart`
Constants `LegalUrls.privacyPolicy` + `LegalUrls.termsOfUse`. Referenced by paywall + You-tab. Slug `8inqwejl` is the Copilot-hosted URL shared across iOS + Android.

### New dependency: `url_launcher ^6.3.1`
Used for external-browser launches. External mode intentional — preserves our dark paywall context and matches platform convention for legal links.

### `AuthService.deleteAccount()` (new)
- Clears Google session (best-effort, ignored if user never Google-auth'd).
- Calls `FirebaseAuth.currentUser.delete()`.
- `requires-recent-login` bubbles up so UI can surface "sign out, sign back in, try again."

### `FirestoreRepository.deleteAllUserData()` (new)
- Collects journal audio paths first (so referenced blobs are cleaned up explicitly).
- Batches sub-collection wipes (`checkIns`, `journal`, `profile`, `ai`, `credits`) in chunks of 400.
- Deletes the user doc itself last.
- Recursive Storage list under `users/{uid}/audio/journal/*` as a catch-all for orphaned audio.
- Best-effort: individual failures are logged, don't abort the whole wipe.
- No-ops cleanly when Storage isn't provisioned (Spark plan).

### `UserProvider.wipeAllUserDataAndDetach()` (new)
Orchestrator:
1. Cancel streams (so in-flight snapshots don't re-populate state mid-delete).
2. Call `repo.deleteAllUserData()`.
3. Clear in-memory caches (`_profile`, `_checkIns`, `_journalEntries`, `_aiContext`).
4. Notify listeners.

Called BEFORE `AuthService.deleteAccount()` so a failing auth-delete still leaves Firestore/Storage wiped. Idempotent.

### UI changes
- **`lib/screens/paywall/paywall_screen.dart`** — wires the existing `Terms` / `Privacy` TextButtons to `_openLegalUrl` (external browser).
- **`lib/screens/you/you_tab.dart`** — settings sheet gets:
  - `Privacy Policy` row (new)
  - `Terms of Use` row (new)
  - `Delete account` row (new, destructive red styling)
  - `_SettingsItem` extended with `isDestructive: bool` for the red variant.
  - `_handleDeleteAccount()` — confirmation dialog → progress dialog → wipe → auth delete → `/auth`.
  - `_DeletingDialog` widget — amber spinner + "Deleting your account…" copy.

## Files affected
- `pubspec.yaml` — added `url_launcher: ^6.3.1`
- `lib/services/legal_urls.dart` — new
- `lib/services/auth_service.dart` — `deleteAccount()` added
- `lib/services/firestore_repository.dart` — `deleteAllUserData()` added
- `lib/providers/user_provider.dart` — `wipeAllUserDataAndDetach()` added
- `lib/screens/paywall/paywall_screen.dart` — `_openLegalUrl` + footer wiring
- `lib/screens/you/you_tab.dart` — settings rows + delete-account flow + `_DeletingDialog`
- `CLAUDE.md` — documented compliance surfaces + open launch items

## Verification
- `flutter analyze` — clean on every touched file (pre-existing warnings in integration_test / today_card / insights untouched).
- `flutter test` — 27/27 pass.
- Manual smoke (recommended before merge):
  - Paywall → tap `Privacy` → external browser opens the hosted PP.
  - Paywall → tap `Terms` → external browser opens the hosted ToU.
  - You tab → Settings → `Privacy Policy` / `Terms of Use` → same.
  - You tab → Settings → `Delete account` → confirmation dialog → confirm → spinner → redirected to `/auth`. Verify Firestore `users/{uid}` tree is gone and Firebase Auth shows no user.
  - Delete-account with stale session → expect the "sign out, sign back in, try again" snackbar and a redirect to `/auth`.

## Not in this branch (flagged in CLAUDE.md)
- Select "Standard Apple License Agreement" on ASC App Information (3.1.2).
- Verify Play Console dedicated Privacy Policy URL field is populated (Copilot MCP doesn't currently expose a `push_privacy_url_to_play` tool).
- Complete ASC App Privacy questionnaire for all data types collected.
