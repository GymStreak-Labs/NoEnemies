import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/check_in.dart';
import '../models/journal_entry.dart';

class StorageService {
  static const String _profileKey = 'user_profile';
  static const String _checkInsKey = 'check_ins';
  static const String _journalKey = 'journal_entries';
  static const String _onboardingKey = 'onboarding_complete';
  static const String _lastSeenTitleKey = 'last_seen_title_index';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Onboarding ---

  bool get isOnboardingComplete => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_onboardingKey, value);
  }

  // --- Stage transition tracking ---

  /// Index of the last UserTitle the user has visually acknowledged.
  /// Returns -1 if they've never opened the app post-onboarding.
  int get lastSeenTitleIndex => _prefs.getInt(_lastSeenTitleKey) ?? -1;

  Future<void> setLastSeenTitleIndex(int index) async {
    await _prefs.setInt(_lastSeenTitleKey, index);
  }

  // --- User Profile ---

  UserProfile? getProfile() {
    final json = _prefs.getString(_profileKey);
    if (json == null) return null;
    return UserProfile.fromJsonString(json);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_profileKey, profile.toJsonString());
  }

  // --- Check-ins ---

  List<CheckIn> getCheckIns() {
    final json = _prefs.getString(_checkInsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => CheckIn.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCheckIns(List<CheckIn> checkIns) async {
    final json = jsonEncode(checkIns.map((c) => c.toJson()).toList());
    await _prefs.setString(_checkInsKey, json);
  }

  Future<void> addCheckIn(CheckIn checkIn) async {
    final checkIns = getCheckIns();
    checkIns.add(checkIn);
    await saveCheckIns(checkIns);
  }

  // --- Journal ---

  List<JournalEntry> getJournalEntries() {
    final json = _prefs.getString(_journalKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveJournalEntries(List<JournalEntry> entries) async {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_journalKey, json);
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    final entries = getJournalEntries();
    entries.add(entry);
    await saveJournalEntries(entries);
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    final entries = getJournalEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      entries[index] = entry;
      await saveJournalEntries(entries);
    }
  }

  Future<void> deleteJournalEntry(String id) async {
    final entries = getJournalEntries();
    entries.removeWhere((e) => e.id == id);
    await saveJournalEntries(entries);
  }

  // --- Reset ---

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
