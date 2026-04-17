import 'package:flutter/foundation.dart';
import '../models/conflict_type.dart';
import '../services/ai_service.dart';

/// Manages journey-related state: peace missions, AI prompts, etc.
class JourneyProvider extends ChangeNotifier {
  final AiService _aiService;

  JourneyProvider(this._aiService);

  /// Get today's peace mission for the given conflict type.
  String getPeaceMission(ConflictType conflictType) {
    return _aiService.getPeaceMission(conflictType);
  }

  /// Get a morning prompt for the given conflict type and mood.
  String getMorningPrompt(ConflictType conflictType,
      {required dynamic mood}) {
    return _aiService.getMorningPrompt(conflictType, mood);
  }

  /// Get an evening question for the given conflict type.
  String getEveningQuestion(ConflictType conflictType) {
    return _aiService.getEveningQuestion(conflictType);
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
