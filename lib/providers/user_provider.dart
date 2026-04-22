import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_context.dart';
import '../models/check_in.dart';
import '../models/conflict_type.dart';
import '../models/current_emotion.dart';
import '../models/journal_entry.dart';
import '../models/user_profile.dart';
import '../services/ai_mentor_service.dart';
import '../services/firestore_repository.dart';
import '../services/storage_service.dart';

/// Top-level user state — profile + check-ins + journal, backed by Firestore.
///
/// [StorageService] is kept around only for device-local flags that are NOT
/// user-scoped (onboarding completed, last-seen title index, intro cinematic
/// seen). All user content (profile, check-ins, journal) comes from Firestore.
///
/// The [FirestoreRepository] is nullable — it's only set once a user is
/// authenticated. See [attachRepository]/[detachRepository], wired from the
/// auth state listener in [main.dart].
class UserProvider extends ChangeNotifier {
  UserProvider(this._storage, {AiMentorService? mentor}) : _mentor = mentor;

  final StorageService _storage;

  /// Optional — when provided, the rolling AI context is rebuilt every 10th
  /// check-in. Wired up from `main.dart`. Not required for the provider to
  /// function.
  AiMentorService? _mentor;

  void attachMentor(AiMentorService mentor) {
    _mentor = mentor;
  }

  FirestoreRepository? _repo;
  FirestoreRepository? get repo => _repo;

  UserProfile? _profile;
  List<CheckIn> _checkIns = [];
  List<JournalEntry> _journalEntries = [];
  AiContext _aiContext = AiContext.empty;

  /// Rolling AI memory summary (cached). Refreshed after
  /// [attachRepository] and after each rebuild trigger.
  AiContext get aiContext => _aiContext;

  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<List<JournalEntry>>? _journalSub;

  UserProfile? get profile => _profile;
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);
  List<JournalEntry> get journalEntries => List.unmodifiable(_journalEntries);

  bool get isOnboardingComplete => _storage.isOnboardingComplete;
  bool get hasProfile => _profile != null;
  bool get hasRepository => _repo != null;

  // ---------------------------------------------------------------------------
  // Derived state (unchanged from SharedPreferences era).
  // ---------------------------------------------------------------------------

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

  ({UserTitle from, UserTitle to})? pendingStageTransition() {
    final p = _profile;
    if (p == null) return null;
    final lastSeenIndex = _storage.lastSeenTitleIndex;
    final currentIndex = p.currentTitle.index;
    if (lastSeenIndex < 0) {
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

  Future<void> acknowledgeCurrentTitle() async {
    final p = _profile;
    if (p == null) return;
    await _storage.setLastSeenTitleIndex(p.currentTitle.index);
    notifyListeners();
  }

  /// Today's check-ins from the in-memory cache.
  List<CheckIn> get todayCheckIns {
    final now = DateTime.now();
    return _checkIns.where((c) {
      return c.date.year == now.year &&
          c.date.month == now.month &&
          c.date.day == now.day;
    }).toList();
  }

  bool get hasMorningCheckInToday =>
      todayCheckIns.any((c) => c.type == CheckInType.morning);

  bool get hasEveningReflectionToday =>
      todayCheckIns.any((c) => c.type == CheckInType.evening);

  // ---------------------------------------------------------------------------
  // Repository lifecycle — called from auth state listener.
  // ---------------------------------------------------------------------------

  /// Attach a Firestore repository (sign-in). Subscribes to profile,
  /// check-ins, and journal streams so the UI reflects cloud state live.
  ///
  /// If [seedProfile] is provided AND the user has no Firestore profile yet,
  /// the seed is written as the initial profile (first sign-in after
  /// onboarding). This replaces the old "createProfile on celebration tap"
  /// flow.
  Future<void> attachRepository(
    FirestoreRepository repo, {
    UserProfile? seedProfile,
  }) async {
    // If we're swapping between users, clear first.
    if (_repo != null && _repo!.uid != repo.uid) {
      await _detachStreams();
      _profile = null;
      _checkIns = [];
      _journalEntries = [];
    }

    _repo = repo;

    // Check if cloud already has a profile. If not and we have a seed,
    // write it as the initial profile.
    final existing = await repo.loadProfile();
    if (existing == null && seedProfile != null) {
      final seeded = seedProfile.copyWith(
        id: repo.uid,
        hasCompletedOnboarding: true,
      );
      await repo.saveProfile(seeded);
      _profile = seeded;
    } else if (existing != null) {
      _profile = existing;
    }

    // Subscribe to live updates after the initial seed (so we don't race).
    await _subscribeStreams(repo);

    // Warm the AI context cache. Safe to fail silently.
    try {
      _aiContext = await repo.loadAiContext();
    } catch (_) {
      _aiContext = AiContext.empty;
    }

    notifyListeners();
  }

  /// Detach the repository (sign-out). Clears in-memory state.
  Future<void> detachRepository() async {
    await _detachStreams();
    _repo = null;
    _profile = null;
    _checkIns = [];
    _journalEntries = [];
    _aiContext = AiContext.empty;
    notifyListeners();
  }

  Future<void> _subscribeStreams(FirestoreRepository repo) async {
    await _detachStreams();
    _profileSub = repo.streamProfile().listen((profile) {
      _profile = profile;
      notifyListeners();
    }, onError: (Object e, StackTrace st) {
      debugPrint('[UserProvider] profile stream error: $e');
    });
    _checkInsSub = repo.streamRecentCheckIns().listen((list) {
      _checkIns = list;
      notifyListeners();
    }, onError: (Object e, StackTrace st) {
      debugPrint('[UserProvider] checkIns stream error: $e');
    });
    _journalSub = repo.streamJournalEntries().listen((list) {
      _journalEntries = list;
      notifyListeners();
    }, onError: (Object e, StackTrace st) {
      debugPrint('[UserProvider] journal stream error: $e');
    });
  }

  Future<void> _detachStreams() async {
    await _profileSub?.cancel();
    await _checkInsSub?.cancel();
    await _journalSub?.cancel();
    _profileSub = null;
    _checkInsSub = null;
    _journalSub = null;
  }

  @override
  void dispose() {
    _detachStreams();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Onboarding / profile creation
  // ---------------------------------------------------------------------------

  /// Build a [UserProfile] from quiz answers WITHOUT writing it to Firestore.
  /// The caller (onboarding flow) holds this in memory until the user
  /// completes auth, then it's passed to [attachRepository] as a seed.
  ///
  /// Marks local `onboarding_complete` to `true` so the app treats the quiz
  /// as done from this point forward. The profile itself only materializes
  /// in Firestore once a Firebase user exists.
  Future<UserProfile> buildOnboardingProfile({
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
    final profile = UserProfile(
      id: const Uuid().v4(), // Replaced with Firebase uid on attach.
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
    _profile = profile;
    await _storage.setOnboardingComplete(true);

    // If a repo is already attached (e.g. debug flows), write through.
    final repo = _repo;
    if (repo != null) {
      await repo.saveProfile(profile.copyWith(id: repo.uid));
    }
    notifyListeners();
    return profile;
  }

  /// Back-compat wrapper — old code called `createProfile` and expected the
  /// side effect of writing to storage + flipping `hasCompletedOnboarding`.
  /// We keep the signature so existing onboarding screens don't break, but
  /// under Firestore the "write" either goes to the repo (if attached) or
  /// is deferred until auth completes.
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
    await buildOnboardingProfile(
      conflictType: conflictType,
      quizAnswers: quizAnswers,
      displayName: displayName,
      conflictTarget: conflictTarget,
      conflictDuration: conflictDuration,
      conflictIntensity: conflictIntensity,
      conflictStyle: conflictStyle,
      preferredCheckInTime: preferredCheckInTime,
      personalIntention: personalIntention,
      previousAttempts: previousAttempts,
    );
  }

  /// Debug: simulate stage progression.
  Future<void> debugSetPeaceDays(int days) async {
    final p = _profile;
    if (p == null) return;
    _profile = p.copyWith(
      totalDaysOfPeace: days,
      currentStreak: days,
      longestStreak: days,
      peaceDays: days,
      createdAt: DateTime.now().subtract(Duration(days: days)),
    );
    final repo = _repo;
    if (repo != null) {
      await repo.saveProfile(_profile!);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Check-ins
  // ---------------------------------------------------------------------------

  Future<void> recordMorningCheckIn({
    required Mood mood,
    required String intention,
    String? aiPrompt,
  }) async {
    final repo = _repo;
    if (repo == null) {
      debugPrint('[UserProvider] recordMorningCheckIn: no repo attached');
      return;
    }
    final checkIn = CheckIn(
      id: const Uuid().v4(),
      date: DateTime.now(),
      type: CheckInType.morning,
      mood: mood,
      intention: intention,
      aiPrompt: aiPrompt,
      isPeaceful: mood.peaceScore >= 0.5,
    );

    await repo.saveCheckIn(checkIn);
    await _updateStats(checkIn);
    // Streams update _checkIns; nothing else to do locally.
  }

  Future<void> recordEveningReflection({
    required Mood mood,
    required String reflectionAnswer,
    required List<DimensionRating> dimensions,
  }) async {
    final repo = _repo;
    if (repo == null) {
      debugPrint('[UserProvider] recordEveningReflection: no repo attached');
      return;
    }
    final checkIn = CheckIn(
      id: const Uuid().v4(),
      date: DateTime.now(),
      type: CheckInType.evening,
      mood: mood,
      reflectionAnswer: reflectionAnswer,
      dimensions: dimensions,
      isPeaceful: mood.peaceScore >= 0.5,
    );
    await repo.saveCheckIn(checkIn);
    await _updateStats(checkIn);
  }

  Future<void> _updateStats(CheckIn checkIn) async {
    final p = _profile;
    final repo = _repo;
    if (p == null || repo == null) return;

    final isPeaceful = checkIn.isPeaceful;
    var newPeaceDays = p.peaceDays;
    var newWarDays = p.warDays;
    var newTotalDays = p.totalDaysOfPeace;
    var newCurrentStreak = p.currentStreak;
    var newLongestStreak = p.longestStreak;

    if (isPeaceful) {
      newPeaceDays++;
      newTotalDays++;
      newCurrentStreak++;
      if (newCurrentStreak > newLongestStreak) {
        newLongestStreak = newCurrentStreak;
      }
    } else {
      newWarDays++;
      newCurrentStreak = (newCurrentStreak - 1).clamp(0, newCurrentStreak);
    }

    final updated = p.copyWith(
      peaceDays: newPeaceDays,
      warDays: newWarDays,
      totalDaysOfPeace: newTotalDays,
      currentStreak: newCurrentStreak,
      longestStreak: newLongestStreak,
      lastCheckInDate: DateTime.now(),
    );
    _profile = updated;
    await repo.saveProfile(updated);

    _maybeRebuildAiContext();
  }

  /// Rolling-context rebuild trigger. Fires every 10 check-ins, anchored to
  /// the persisted [AiContext.checkInsSinceLastRebuild] counter — NOT the
  /// windowed `_checkIns` list size, which would misfire once the 30-day
  /// window saturates (length stays at the cap even as new entries arrive).
  ///
  /// Increments the counter on every call, persists it, and fires a rebuild
  /// when it reaches the threshold. The rebuild itself writes a fresh
  /// [AiContext] (with `checkInsSinceLastRebuild: 0`) to Firestore — see
  /// [AiMentorService.rebuildContext].
  ///
  /// Fire-and-forget — failures are logged and the existing context is
  /// retained.
  static const _kRebuildThreshold = 10;

  void _maybeRebuildAiContext() {
    final mentor = _mentor;
    final repo = _repo;
    final profile = _profile;
    if (mentor == null || repo == null || profile == null) return;
    if (_checkIns.isEmpty) return;

    final next = _aiContext.checkInsSinceLastRebuild + 1;
    final bumped = _aiContext.copyWith(checkInsSinceLastRebuild: next);
    _aiContext = bumped;

    // Persist the bumped counter immediately so we don't lose progress if
    // the app is killed before the next check-in. Cheap single-field write.
    unawaited(repo.saveAiContext(bumped).catchError((Object e, StackTrace st) {
      debugPrint('[UserProvider] persist AiContext counter failed: $e\n$st');
    }));

    if (next < _kRebuildThreshold) return;

    // Fire-and-forget — don't block the UI on a network call.
    unawaited(() async {
      try {
        final rebuilt = await mentor.rebuildContext(
          repo: repo,
          profile: profile,
          recentCheckIns: _checkIns,
        );
        _aiContext = rebuilt;
        notifyListeners();
      } catch (e, st) {
        debugPrint('[UserProvider] AI context rebuild failed: $e\n$st');
      }
    }());
  }

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  Future<void> addJournalEntry({
    required String title,
    required String content,
    String? audioStoragePath,
    int? audioDurationSeconds,
  }) async {
    final repo = _repo;
    if (repo == null) {
      debugPrint('[UserProvider] addJournalEntry: no repo attached');
      return;
    }
    final entry = JournalEntry(
      id: const Uuid().v4(),
      date: DateTime.now(),
      title: title,
      content: content,
      audioStoragePath: audioStoragePath,
      audioDurationSeconds: audioDurationSeconds,
    );
    await repo.saveJournalEntry(entry);
  }

  /// Create a [JournalEntry] id up-front so the caller (voice entry screen)
  /// can upload audio to the correct Storage path before the Firestore doc
  /// exists. Returns both the id and the pre-built storage path.
  ({String entryId, String storagePath}) newJournalEntryId() {
    final id = const Uuid().v4();
    final repo = _repo;
    final path =
        repo == null ? '' : repo.audioStoragePath(id);
    return (entryId: id, storagePath: path);
  }

  /// Save an already-constructed entry (id + audio fields set). Used by the
  /// voice entry flow so the provider doesn't need to know about temp files.
  Future<void> saveJournalEntry(JournalEntry entry) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.saveJournalEntry(entry);
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.saveJournalEntry(entry);
  }

  Future<void> deleteJournalEntry(String id) async {
    final repo = _repo;
    if (repo == null) return;
    // Find the entry first so we can clean up its audio clip (if any) before
    // dropping the Firestore doc. Order matters: if Storage delete fails we'd
    // rather retry via a re-delete than orphan the audio.
    final entry = _journalEntries.where((e) => e.id == id).firstOrNull;
    final audioPath = entry?.audioStoragePath;
    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        await repo.deleteJournalAudio(audioPath);
      } catch (e, st) {
        debugPrint('[UserProvider] delete audio failed (ignoring): $e\n$st');
      }
    }
    await repo.deleteJournalEntry(id);
  }

  Future<void> toggleBookmark(String id) async {
    final repo = _repo;
    if (repo == null) return;
    final index = _journalEntries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final entry = _journalEntries[index];
    final updated = entry.copyWith(isBookmarked: !entry.isBookmarked);
    await repo.saveJournalEntry(updated);
  }

  // ---------------------------------------------------------------------------
  // Legacy compatibility
  // ---------------------------------------------------------------------------

  /// Back-compat noop — callers used to call this to load from SharedPref.
  /// Under Firestore, data loads via stream subscriptions triggered by
  /// [attachRepository]. Kept so we don't have to audit every caller.
  Future<void> loadData() async {
    // Streams handle this now. Left as a no-op for backward compatibility.
    return;
  }
}
