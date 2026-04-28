import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/peace_letter.dart';
import '../services/firestore_repository.dart';

class PeaceLettersProvider extends ChangeNotifier {
  FirestoreRepository? _repo;
  StreamSubscription<List<PeaceLetter>>? _lettersSub;

  List<PeaceLetter> _letters = const [];
  bool _isSaving = false;
  String? _lastError;

  List<PeaceLetter> get letters => List.unmodifiable(_letters);
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;
  bool get hasRepository => _repo != null;

  List<PeaceLetter> get drafts => _letters
      .where((letter) => letter.status == PeaceLetterStatus.draft)
      .toList(growable: false);

  List<PeaceLetter> get sealedLetters => _letters
      .where((letter) => letter.status != PeaceLetterStatus.draft)
      .toList(growable: false);

  Future<void> attachRepository(FirestoreRepository repo) async {
    if (_repo?.uid == repo.uid) return;
    await detachRepository();
    _repo = repo;
    _lettersSub = repo.streamPeaceLetters().listen(
      (letters) {
        _letters = letters;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        _lastError = 'Peace Letters could not be loaded.';
        debugPrint('[PeaceLettersProvider] stream error: $e\n$st');
        notifyListeners();
      },
    );
  }

  Future<void> detachRepository() async {
    await _lettersSub?.cancel();
    _lettersSub = null;
    _repo = null;
    _letters = const [];
    _isSaving = false;
    _lastError = null;
    notifyListeners();
  }

  PeaceLetter? letterById(String id) {
    for (final letter in _letters) {
      if (letter.id == id) return letter;
    }
    return null;
  }

  Future<PeaceLetter?> saveDraft({
    required String rawText,
    required PeaceRecipientArchetype recipientArchetype,
    required PeaceIntent intent,
    required List<PeaceTheme> themes,
  }) async {
    return _saveLetter(
      PeaceLetter(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        rawText: rawText.trim(),
        recipientArchetype: recipientArchetype,
        intent: intent,
        themes: themes,
      ),
    );
  }

  Future<PeaceLetter?> updateDraft(PeaceLetter letter) async {
    return _saveLetter(letter.copyWith(updatedAt: DateTime.now()));
  }

  /// Launch V1: seal the letter as a private ritual.
  Future<PeaceLetter?> sealPrivately(PeaceLetter letter) async {
    return _saveLetter(
      letter.copyWith(
        status: PeaceLetterStatus.sealed,
        sealedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteLetter(String id) async {
    final repo = _repo;
    if (repo == null) return;
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    try {
      await repo.deletePeaceLetter(id);
    } catch (e, st) {
      _lastError = 'Could not delete this letter.';
      debugPrint('[PeaceLettersProvider] deleteLetter failed: $e\n$st');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<PeaceLetter?> _saveLetter(PeaceLetter letter) async {
    final repo = _repo;
    if (repo == null) {
      _lastError = 'Sign in before saving Peace Letters.';
      notifyListeners();
      return null;
    }
    _isSaving = true;
    _lastError = null;
    notifyListeners();
    try {
      await repo.savePeaceLetter(letter);
      return letter;
    } catch (e, st) {
      _lastError = 'Could not save this Peace Letter.';
      debugPrint('[PeaceLettersProvider] saveLetter failed: $e\n$st');
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _lettersSub?.cancel();
    super.dispose();
  }
}
