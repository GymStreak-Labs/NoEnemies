import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/check_in.dart';
import '../models/journal_entry.dart';
import '../models/user_profile.dart';

/// Device-local key/value store. Post-Firestore migration this class owns
/// ONLY device-scoped flags that are NOT tied to a specific user account:
///
///   - `intro_cinematic_seen`    — per-install flag (hidden elsewhere via
///                                 [IntroCinematicScreen.hasBeenSeen]).
///   - `onboarding_complete`     — used pre-auth to gate the router.
///   - `last_seen_title_index`   — UX polish (skip stage cinematic on replay).
///   - `legacy_migrated_to_firestore` — one-shot guard for the legacy import.
///
/// The read-only accessors for profile/check-ins/journal are retained so the
/// migration path in [UserProvider]/[main.dart] can import any pre-existing
/// local data into Firestore on first post-upgrade launch. All WRITES to
/// profile/check-ins/journal now go through [FirestoreRepository] — those
/// SharedPrefs keys are never written again.
class StorageService {
  static const String _profileKey = 'user_profile';
  static const String _checkInsKey = 'check_ins';
  static const String _journalKey = 'journal_entries';
  static const String _onboardingKey = 'onboarding_complete';
  static const String _lastSeenTitleKey = 'last_seen_title_index';
  static const String _legacyMigratedKey = 'legacy_migrated_to_firestore';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Device flags ---

  bool get isOnboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingKey, value);
  }

  /// Index of the last [UserTitle] the user has visually acknowledged.
  /// Returns -1 if they've never opened the app post-onboarding.
  int get lastSeenTitleIndex => _prefs.getInt(_lastSeenTitleKey) ?? -1;

  Future<void> setLastSeenTitleIndex(int index) async {
    await _prefs.setInt(_lastSeenTitleKey, index);
  }

  // --- Legacy migration guard ---

  bool get isLegacyMigrated => _prefs.getBool(_legacyMigratedKey) ?? false;

  Future<void> markLegacyMigrated() async {
    await _prefs.setBool(_legacyMigratedKey, true);
  }

  /// True when SharedPreferences holds pre-Firestore user data that should be
  /// migrated to the cloud on first authenticated launch.
  bool get hasLegacyUserData =>
      _prefs.getString(_profileKey) != null ||
      _prefs.getString(_checkInsKey) != null ||
      _prefs.getString(_journalKey) != null;

  // --- Legacy read-only accessors (migration path only) ---

  UserProfile? legacyProfile() {
    final json = _prefs.getString(_profileKey);
    if (json == null) return null;
    return UserProfile.fromJsonString(json);
  }

  List<CheckIn> legacyCheckIns() {
    final json = _prefs.getString(_checkInsKey);
    if (json == null) return const [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => CheckIn.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<JournalEntry> legacyJournalEntries() {
    final json = _prefs.getString(_journalKey);
    if (json == null) return const [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Remove all legacy user content from SharedPreferences after a successful
  /// migration to Firestore. Device flags (onboarding, title index) stay.
  Future<void> clearLegacyUserData() async {
    await _prefs.remove(_profileKey);
    await _prefs.remove(_checkInsKey);
    await _prefs.remove(_journalKey);
  }

  // --- Reset ---

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
