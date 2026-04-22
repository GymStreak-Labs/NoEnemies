import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/ai_context.dart';
import '../models/check_in.dart';
import '../models/journal_entry.dart';
import '../models/user_profile.dart';

/// Firestore data layer for a single authenticated user.
///
/// Tree owned by this repository:
///
///   users/{uid}/profile/main          — single profile doc
///   users/{uid}/checkIns/{yyyy-MM-dd} — merged morning + evening per day
///   users/{uid}/journal/{entryId}     — one doc per journal entry
///   users/{uid}/ai/context            — rolling AI memory (reserved, Phase C)
///   users/{uid}/credits/voiceMinutes  — reserved, voice feature
///
/// All reads are scoped to `uid` — security rules (`firestore.rules`) enforce
/// that no user can touch another user's tree.
class FirestoreRepository {
  FirestoreRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final String uid;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static final DateFormat _dayIdFormat = DateFormat('yyyy-MM-dd');

  // ---------------------------------------------------------------------------
  // References
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> get _profileDoc =>
      _userDoc.collection('profile').doc('main');

  CollectionReference<Map<String, dynamic>> get _checkInsCol =>
      _userDoc.collection('checkIns');

  CollectionReference<Map<String, dynamic>> get _journalCol =>
      _userDoc.collection('journal');

  DocumentReference<Map<String, dynamic>> get _aiContextDoc =>
      _userDoc.collection('ai').doc('context');

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// One-shot read of the profile doc. Returns null if the user has never
  /// created a profile yet (first sign-in).
  Future<UserProfile?> loadProfile() async {
    try {
      final snap = await _profileDoc.get();
      final data = snap.data();
      if (data == null) return null;
      return UserProfile.fromFirestore(data);
    } catch (e, st) {
      debugPrint('[FirestoreRepository] loadProfile failed: $e\n$st');
      return null;
    }
  }

  /// Write the profile doc. Uses `SetOptions(merge: true)` so the caller can
  /// update partial fields without clobbering the document.
  Future<void> saveProfile(UserProfile profile) async {
    await _profileDoc.set(profile.toFirestore(), SetOptions(merge: true));
  }

  /// Live profile stream — `UserProvider` subscribes to this so any
  /// Firestore update (even from another device) propagates to the UI.
  Stream<UserProfile?> streamProfile() {
    return _profileDoc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserProfile.fromFirestore(data);
    });
  }

  // ---------------------------------------------------------------------------
  // Check-ins — merged morning+evening doc per day, keyed by yyyy-MM-dd
  // ---------------------------------------------------------------------------

  String _dayId(DateTime date) => _dayIdFormat.format(date.toLocal());

  /// Merge a morning or evening half into today's check-in doc.
  /// Uses `SetOptions(merge: true)` so the two halves don't clobber each other.
  Future<void> saveCheckIn(CheckIn checkIn) async {
    final dayId = _dayId(checkIn.date);
    final half = checkIn.type == CheckInType.morning ? 'morning' : 'evening';

    await _checkInsCol.doc(dayId).set({
      'date': dayId,
      'dateTs': Timestamp.fromDate(
        DateTime(
          checkIn.date.toLocal().year,
          checkIn.date.toLocal().month,
          checkIn.date.toLocal().day,
        ),
      ),
      half: checkIn.toFirestoreHalf(),
    }, SetOptions(merge: true));
  }

  /// Load today's (or any specific date's) check-in doc. Returns both
  /// morning and evening halves as separate [CheckIn] objects if present.
  Future<List<CheckIn>> loadCheckIn(DateTime date) async {
    final snap = await _checkInsCol.doc(_dayId(date)).get();
    return _checkInsFromDoc(snap);
  }

  /// Stream of the last [days] days of check-ins (defaults to 30). Returns
  /// a flat list of [CheckIn] objects (morning + evening flattened).
  ///
  /// Keeps the window small on purpose — `UserProvider` uses these for UI
  /// (dominant mood, today's state), not for bulk analytics. A larger window
  /// is reserved for a Phase C analytics/insights read.
  Stream<List<CheckIn>> streamRecentCheckIns({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffTs = Timestamp.fromDate(
      DateTime(cutoff.year, cutoff.month, cutoff.day),
    );
    return _checkInsCol
        .where('dateTs', isGreaterThanOrEqualTo: cutoffTs)
        .orderBy('dateTs', descending: true)
        .snapshots()
        .map((query) {
      final out = <CheckIn>[];
      for (final doc in query.docs) {
        out.addAll(_checkInsFromDoc(doc));
      }
      return out;
    });
  }

  List<CheckIn> _checkInsFromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return const [];
    final out = <CheckIn>[];
    final fallbackDate =
        (data['dateTs'] as Timestamp?)?.toDate() ?? DateTime.now();

    final morning = data['morning'];
    if (morning is Map<String, dynamic>) {
      out.add(CheckIn.fromFirestoreHalf(
        morning,
        type: CheckInType.morning,
        fallbackDate: fallbackDate,
      ));
    }
    final evening = data['evening'];
    if (evening is Map<String, dynamic>) {
      out.add(CheckIn.fromFirestoreHalf(
        evening,
        type: CheckInType.evening,
        fallbackDate: fallbackDate,
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  /// One-shot read of the most recent [limit] entries. Good for initial load
  /// and tests; prefer [streamJournalEntries] for live UI.
  Future<List<JournalEntry>> listJournalEntries({int limit = 50}) async {
    final query = await _journalCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return query.docs
        .map((d) => JournalEntry.fromFirestore(d.data()))
        .toList();
  }

  /// Live journal stream, most-recent first. Limited to [limit] entries so
  /// we don't hammer Firestore as users accumulate more history. Pagination
  /// (`load more`) can be added later — for MVP, 50 is plenty.
  Stream<List<JournalEntry>> streamJournalEntries({int limit = 50}) {
    return _journalCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) =>
            query.docs.map((d) => JournalEntry.fromFirestore(d.data())).toList());
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    await _journalCol
        .doc(entry.id)
        .set(entry.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteJournalEntry(String id) async {
    await _journalCol.doc(id).delete();
  }

  // ---------------------------------------------------------------------------
  // Journal audio — Firebase Storage.
  //
  // Path scheme: `users/{uid}/audio/journal/{entryId}.wav` mirrors the
  // Firestore tree so the storage rules can reuse the same uid-ownership check.
  // ---------------------------------------------------------------------------

  String audioStoragePath(String entryId) =>
      'users/$uid/audio/journal/$entryId.wav';

  /// Upload a recorded WAV to Firebase Storage. Returns the storage path,
  /// which the caller should persist on the [JournalEntry]. The caller is
  /// responsible for deleting the local temp file afterward.
  Future<String> uploadJournalAudio(String entryId, File audioFile) async {
    final path = audioStoragePath(entryId);
    final ref = _storage.ref(path);
    await ref.putFile(
      audioFile,
      SettableMetadata(contentType: 'audio/wav'),
    );
    return path;
  }

  /// Fetch a time-limited download URL for a stored clip so [just_audio] can
  /// stream it. Callers should guard this with a try/catch — network failures
  /// and deleted clips both surface as [FirebaseException].
  Future<Uri> downloadJournalAudioUrl(String storagePath) async {
    final ref = _storage.ref(storagePath);
    final urlString = await ref.getDownloadURL();
    return Uri.parse(urlString);
  }

  /// Remove a clip from Storage. Idempotent — ignores "object not found".
  Future<void> deleteJournalAudio(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // AI context — rolling summary rebuilt every ~10 check-ins (see
  // `AiMentorService.rebuildContext`). Safe to call before any context exists.
  // ---------------------------------------------------------------------------

  Future<AiContext> loadAiContext() async {
    try {
      final snap = await _aiContextDoc.get();
      final data = snap.data();
      if (data == null) return AiContext.empty;
      return AiContext.fromFirestore(data);
    } catch (e, st) {
      debugPrint('[FirestoreRepository] loadAiContext failed: $e\n$st');
      return AiContext.empty;
    }
  }

  Future<void> saveAiContext(AiContext context) async {
    try {
      await _aiContextDoc.set(context.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[FirestoreRepository] saveAiContext failed: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Bulk migration helpers (used once on first post-Firestore launch if
  // legacy SharedPreferences data is present).
  // ---------------------------------------------------------------------------

  /// Write an entire initial snapshot from legacy SharedPreferences data in
  /// one batch. Safe to call more than once — uses `SetOptions(merge: true)`.
  Future<void> migrateFromLegacy({
    required UserProfile profile,
    required List<CheckIn> checkIns,
    required List<JournalEntry> journal,
  }) async {
    final batch = _db.batch();

    batch.set(_profileDoc, profile.toFirestore(), SetOptions(merge: true));

    // Group check-ins by day so we write one doc per day (merging halves).
    final perDay = <String, Map<String, dynamic>>{};
    for (final c in checkIns) {
      final dayId = _dayId(c.date);
      final existing = perDay.putIfAbsent(dayId, () {
        final localDay = DateTime(
          c.date.toLocal().year,
          c.date.toLocal().month,
          c.date.toLocal().day,
        );
        return <String, dynamic>{
          'date': dayId,
          'dateTs': Timestamp.fromDate(localDay),
        };
      });
      final key = c.type == CheckInType.morning ? 'morning' : 'evening';
      existing[key] = c.toFirestoreHalf();
    }
    for (final entry in perDay.entries) {
      batch.set(
        _checkInsCol.doc(entry.key),
        entry.value,
        SetOptions(merge: true),
      );
    }

    for (final j in journal) {
      batch.set(
        _journalCol.doc(j.id),
        j.toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
