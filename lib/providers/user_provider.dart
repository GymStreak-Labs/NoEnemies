import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/conflict_type.dart';
import '../models/current_emotion.dart';
import '../models/user_profile.dart';
import '../models/check_in.dart';
import '../models/journal_entry.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  final StorageService _storage;

  UserProfile? _profile;
  List<CheckIn> _checkIns = [];
  List<JournalEntry> _journalEntries = [];

  UserProvider(this._storage);

  UserProfile? get profile => _profile;
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);
  List<JournalEntry> get journalEntries => List.unmodifiable(_journalEntries);

  bool get isOnboardingComplete => _storage.isOnboardingComplete;
  bool get hasProfile => _profile != null;

  /// Returns the user's dominant mood across the last [days] days, or null if
  /// they haven't checked in. Used to tint the character's aura on the You tab.
  Mood? recentDominantMood({int days = 7}) {
    if (_checkIns.isEmpty) return null;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = _checkIns.where((c) => c.date.isAfter(cutoff)).toList();
    if (recent.isEmpty) return null;
    final counts = <Mood, int>{};
    for (final c in recent) {
      counts[c.mood] = (counts[c.mood] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Derives a 3-bucket emotion from the last [days] days of check-ins.
  /// Returns [CurrentEmotion.calm] when there's no data, so the character
  /// always has a sensible default. The classification uses the average
  /// [Mood.peaceScore] across recent check-ins:
  ///   avg >= 0.7 → joyful
  ///   avg <= 0.35 → troubled
  ///   else → calm
  CurrentEmotion currentEmotion({int days = 5}) {
    if (_checkIns.isEmpty) return CurrentEmotion.calm;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = _checkIns.where((c) => c.date.isAfter(cutoff)).toList();
    if (recent.isEmpty) return CurrentEmotion.calm;
    final avg = recent.map((c) => c.mood.peaceScore).reduce((a, b) => a + b) /
        recent.length;
    if (avg >= 0.7) return CurrentEmotion.joyful;
    if (avg <= 0.35) return CurrentEmotion.troubled;
    return CurrentEmotion.calm;
  }

  /// Returns the previous title (if any) when the user has just unlocked a new
  /// stage that hasn't been visually acknowledged yet. Returns null when no
  /// new transition is pending.
  ({UserTitle from, UserTitle to})? pendingStageTransition() {
    final p = _profile;
    if (p == null) return null;
    final lastSeenIndex = _storage.lastSeenTitleIndex;
    final currentIndex = p.currentTitle.index;
    // First-time view post-onboarding: seed lastSeen to current, no transition.
    if (lastSeenIndex < 0) {
      // Fire-and-forget seed; doesn't trigger a transition.
      _storage.setLastSeenTitleIndex(currentIndex);
      return null;
    }
    if (currentIndex > lastSeenIndex) {
      return (
        from: UserTitle.values[lastSeenIndex],
        to: UserTitle.values[currentIndex],
      );
    }
    return null;
  }

  /// Mark the user's current title as visually acknowledged after the
  /// cinematic plays. Call this when the user taps Continue on the
  /// stage transition screen.
  Future<void> acknowledgeCurrentTitle() async {
    final p = _profile;
    if (p == null) return;
    await _storage.setLastSeenTitleIndex(p.currentTitle.index);
    notifyListeners();
  }

  /// Load all persisted data from storage.
  Future<void> loadData() async {
    _profile = _storage.getProfile();
    _checkIns = _storage.getCheckIns();
    _journalEntries = _storage.getJournalEntries();
    notifyListeners();
  }

  /// Create a new user after completing onboarding quiz.
  Future<void> createProfile({
    required ConflictType conflictType,
    required List<int> quizAnswers,
    String? displayName,
    String? conflictTarget,
    String? conflictDuration,
    int conflictIntensity = 5,
    String? conflictStyle,
    String? preferredCheckInTime,
    String? personalIntention,
    List<String> previousAttempts = const [],
  }) async {
    _profile = UserProfile(
      id: const Uuid().v4(),
      primaryConflict: conflictType,
      quizAnswers: quizAnswers,
      createdAt: DateTime.now(),
      hasCompletedOnboarding: true,
      displayName: displayName,
      conflictTarget: conflictTarget,
      conflictDuration: conflictDuration,
      conflictIntensity: conflictIntensity,
      conflictStyle: conflictStyle,
      preferredCheckInTime: preferredCheckInTime,
      personalIntention: personalIntention,
      previousAttempts: previousAttempts,
    );
    await _storage.saveProfile(_profile!);
    await _storage.setOnboardingComplete(true);
    notifyListeners();
  }

  /// Debug: override totalDaysOfPeace for stage simulation.
  /// Also backdates createdAt so daysSinceStart reflects the simulation.
  Future<void> debugSetPeaceDays(int days) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      totalDaysOfPeace: days,
      currentStreak: days,
      longestStreak: days,
      peaceDays: days,
      createdAt: DateTime.now().subtract(Duration(days: days)),
    );
    await _storage.saveProfile(_profile!);
    notifyListeners();
  }

  /// Record a morning check-in.
  Future<void> recordMorningCheckIn({
    required Mood mood,
    required String intention,
    String? aiPrompt,
  }) async {
    final checkIn = CheckIn(
      id: const Uuid().v4(),
      date: DateTime.now(),
      type: CheckInType.morning,
      mood: mood,
      intention: intention,
      aiPrompt: aiPrompt,
      isPeaceful: mood.peaceScore >= 0.5,
    );

    _checkIns.add(checkIn);
    await _storage.saveCheckIns(_checkIns);

    // Update streak and stats
    await _updateStats(checkIn);
    notifyListeners();
  }

  /// Record an evening reflection.
  Future<void> recordEveningReflection({
    required Mood mood,
    required String reflectionAnswer,
    required List<DimensionRating> dimensions,
  }) async {
    final checkIn = CheckIn(
      id: const Uuid().v4(),
      date: DateTime.now(),
      type: CheckInType.evening,
      mood: mood,
      reflectionAnswer: reflectionAnswer,
      dimensions: dimensions,
      isPeaceful: mood.peaceScore >= 0.5,
    );

    _checkIns.add(checkIn);
    await _storage.saveCheckIns(_checkIns);

    await _updateStats(checkIn);
    notifyListeners();
  }

  Future<void> _updateStats(CheckIn checkIn) async {
    if (_profile == null) return;

    final isPeaceful = checkIn.isPeaceful;
    var newPeaceDays = _profile!.peaceDays;
    var newWarDays = _profile!.warDays;
    var newTotalDays = _profile!.totalDaysOfPeace;
    var newCurrentStreak = _profile!.currentStreak;
    var newLongestStreak = _profile!.longestStreak;

    if (isPeaceful) {
      newPeaceDays++;
      newTotalDays++;
      newCurrentStreak++;
      if (newCurrentStreak > newLongestStreak) {
        newLongestStreak = newCurrentStreak;
      }
    } else {
      newWarDays++;
      // Compassionate streak — don't fully reset, reduce by 1
      // (minimum 0)
      newCurrentStreak = (newCurrentStreak - 1).clamp(0, newCurrentStreak);
    }

    _profile = _profile!.copyWith(
      peaceDays: newPeaceDays,
      warDays: newWarDays,
      totalDaysOfPeace: newTotalDays,
      currentStreak: newCurrentStreak,
      longestStreak: newLongestStreak,
      lastCheckInDate: DateTime.now(),
    );

    await _storage.saveProfile(_profile!);
  }

  // --- Journal ---

  Future<void> addJournalEntry({
    required String title,
    required String content,
  }) async {
    final entry = JournalEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      title: title,
      content: content,
    );
    _journalEntries.insert(0, entry);
    await _storage.saveJournalEntries(_journalEntries);
    notifyListeners();
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    final index = _journalEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _journalEntries[index] = entry;
      await _storage.saveJournalEntries(_journalEntries);
      notifyListeners();
    }
  }

  Future<void> deleteJournalEntry(String id) async {
    _journalEntries.removeWhere((e) => e.id == id);
    await _storage.saveJournalEntries(_journalEntries);
    notifyListeners();
  }

  Future<void> toggleBookmark(String id) async {
    final index = _journalEntries.indexWhere((e) => e.id == id);
    if (index != -1) {
      final entry = _journalEntries[index];
      _journalEntries[index] =
          entry.copyWith(isBookmarked: !entry.isBookmarked);
      await _storage.saveJournalEntries(_journalEntries);
      notifyListeners();
    }
  }

  /// Get today's check-ins.
  List<CheckIn> get todayCheckIns {
    final now = DateTime.now();
    return _checkIns.where((c) {
      return c.date.year == now.year &&
          c.date.month == now.month &&
          c.date.day == now.day;
    }).toList();
  }

  bool get hasMorningCheckInToday {
    return todayCheckIns.any((c) => c.type == CheckInType.morning);
  }

  bool get hasEveningReflectionToday {
    return todayCheckIns.any((c) => c.type == CheckInType.evening);
  }
}
