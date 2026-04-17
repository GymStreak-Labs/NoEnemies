import 'package:cloud_firestore/cloud_firestore.dart';

/// Rolling AI memory for a single user.
///
/// Stored at `users/{uid}/ai/context`. Rebuilt every ~10 check-ins by
/// `AiMentorService.rebuildContext`, then read on every future prompt so the
/// mentor can reference recurring themes / wins / blockers without pushing
/// the full check-in history into each call's context window.
class AiContext {
  final String summary;
  final List<String> themes;
  final DateTime? lastRebuiltAt;

  /// Size of the slice used to build [summary] at the last rebuild. Informational.
  final int checkInsCount;

  /// Monotonic counter of check-ins recorded since the last successful rebuild.
  /// Incremented by [UserProvider] on every saved check-in, reset to 0 when
  /// the context is rebuilt. Anchored here (not to the windowed check-in
  /// stream) so the trigger stays correct for long-term users whose 30-day
  /// window has saturated.
  final int checkInsSinceLastRebuild;

  final int tokenEstimate;

  const AiContext({
    this.summary = '',
    this.themes = const [],
    this.lastRebuiltAt,
    this.checkInsCount = 0,
    this.checkInsSinceLastRebuild = 0,
    this.tokenEstimate = 0,
  });

  static const AiContext empty = AiContext();

  bool get isEmpty => summary.isEmpty;

  AiContext copyWith({
    String? summary,
    List<String>? themes,
    DateTime? lastRebuiltAt,
    int? checkInsCount,
    int? checkInsSinceLastRebuild,
    int? tokenEstimate,
  }) {
    return AiContext(
      summary: summary ?? this.summary,
      themes: themes ?? this.themes,
      lastRebuiltAt: lastRebuiltAt ?? this.lastRebuiltAt,
      checkInsCount: checkInsCount ?? this.checkInsCount,
      checkInsSinceLastRebuild:
          checkInsSinceLastRebuild ?? this.checkInsSinceLastRebuild,
      tokenEstimate: tokenEstimate ?? this.tokenEstimate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'summary': summary,
      'themes': themes,
      'lastRebuiltAt': lastRebuiltAt == null
          ? null
          : Timestamp.fromDate(lastRebuiltAt!),
      'checkInsCount': checkInsCount,
      'checkInsSinceLastRebuild': checkInsSinceLastRebuild,
      'tokenEstimate': tokenEstimate,
    };
  }

  static AiContext fromFirestore(Map<String, dynamic> data) {
    final ts = data['lastRebuiltAt'];
    return AiContext(
      summary: (data['summary'] as String?) ?? '',
      themes: (data['themes'] as List?)?.cast<String>() ?? const <String>[],
      lastRebuiltAt: ts is Timestamp ? ts.toDate() : null,
      checkInsCount: (data['checkInsCount'] as num?)?.toInt() ?? 0,
      checkInsSinceLastRebuild:
          (data['checkInsSinceLastRebuild'] as num?)?.toInt() ?? 0,
      tokenEstimate: (data['tokenEstimate'] as num?)?.toInt() ?? 0,
    );
  }
}
