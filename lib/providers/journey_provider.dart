import 'package:flutter/foundation.dart';

import '../models/ai_context.dart';
import '../models/check_in.dart';
import '../models/conflict_type.dart';
import '../models/user_profile.dart';
import '../services/ai_mentor_service.dart';
import '../services/ai_service.dart';

/// Manages journey-related state: peace missions, AI prompts, etc.
///
/// Phase 1C: the provider now delegates to [AiMentorService] for anything the
/// model can meaningfully improve (morning prompts, evening questions, journal
/// reflections). The synchronous Dart-string library [AiService] remains the
/// back-stop used both as a fallback and for cheap content (`getPeaceMission`,
/// for now).
///
/// Public synchronous getters (`getMorningPrompt`, `getEveningQuestion`) are
/// kept alongside async variants so existing callers don't break — they still
/// resolve immediately from the fallback library, which is indistinguishable
/// from the pre-Phase-1C behaviour when Gemini is offline.
class JourneyProvider extends ChangeNotifier {
  JourneyProvider(this._aiService, {AiMentorService? mentor})
      : _mentor = mentor ?? AiMentorService(fallback: _aiService);

  final AiService _aiService;
  final AiMentorService _mentor;

  AiMentorService get mentor => _mentor;

  /// Get today's peace mission for the given conflict type.
  String getPeaceMission(ConflictType conflictType) {
    return _aiService.getPeaceMission(conflictType);
  }

  // ---------------------------------------------------------------------------
  // Synchronous (fallback) prompt getters — retained for back-compat with
  // any caller that needs a string today.
  // ---------------------------------------------------------------------------

  String getMorningPrompt(ConflictType conflictType, {required dynamic mood}) {
    return _aiService.getMorningPrompt(conflictType, mood);
  }

  String getEveningQuestion(ConflictType conflictType) {
    return _aiService.getEveningQuestion(conflictType);
  }

  // ---------------------------------------------------------------------------
  // Async (AI-backed) prompt methods — UI screens should prefer these.
  // Each has a guaranteed fallback and will never throw.
  // ---------------------------------------------------------------------------

  Future<String> generateMorningPrompt({
    required UserProfile profile,
    required Mood mood,
    AiContext? context,
    List<CheckIn> last7Days = const [],
  }) async {
    return _mentor.morningPrompt(
      profile: profile,
      mood: mood,
      contextSummary: context,
      last7Days: last7Days,
    );
  }

  Future<String> generateEveningQuestion({
    required UserProfile profile,
    CheckIn? todayMorning,
    AiContext? context,
  }) async {
    return _mentor.eveningQuestion(
      profile: profile,
      todayMorning: todayMorning,
      contextSummary: context,
    );
  }

  Future<String> generateJournalReflection({
    required UserProfile profile,
    required String entryText,
    AiContext? context,
  }) async {
    return _mentor.journalReflection(
      profile: profile,
      entryText: entryText,
      contextSummary: context,
    );
  }

  /// Get the voyage map data (placeholder for MVP).
  List<VoyageDay> getVoyageMapData(int totalDays) {
    final days = <VoyageDay>[];
    for (var i = 0; i < totalDays && i < 30; i++) {
      days.add(VoyageDay(
        day: i + 1,
        isPeaceful: i % 3 != 2, // Mock: every 3rd day is a struggle
        date: DateTime.now().subtract(Duration(days: totalDays - 1 - i)),
      ));
    }
    return days;
  }
}

class VoyageDay {
  final int day;
  final bool isPeaceful;
  final DateTime date;

  const VoyageDay({
    required this.day,
    required this.isPeaceful,
    required this.date,
  });
}
