import 'package:cloud_firestore/cloud_firestore.dart';

/// Who the Peace Letter is addressed to.
enum PeaceRecipientArchetype {
  someoneICantForgive,
  versionOfMeIHate,
  personIMiss,
  enemyInMyHead,
  anyoneWhoUnderstands;

  String get label {
    switch (this) {
      case PeaceRecipientArchetype.someoneICantForgive:
        return 'Someone I can’t forgive';
      case PeaceRecipientArchetype.versionOfMeIHate:
        return 'The version of me I hate';
      case PeaceRecipientArchetype.personIMiss:
        return 'The person I miss';
      case PeaceRecipientArchetype.enemyInMyHead:
        return 'The enemy in my head';
      case PeaceRecipientArchetype.anyoneWhoUnderstands:
        return 'Anyone who understands';
    }
  }

  String get prompt {
    switch (this) {
      case PeaceRecipientArchetype.someoneICantForgive:
        return 'Write to the person your heart still argues with.';
      case PeaceRecipientArchetype.versionOfMeIHate:
        return 'Write to the part of you that still needs mercy.';
      case PeaceRecipientArchetype.personIMiss:
        return 'Write what grief never got to say out loud.';
      case PeaceRecipientArchetype.enemyInMyHead:
        return 'Name the voice that keeps turning you against yourself.';
      case PeaceRecipientArchetype.anyoneWhoUnderstands:
        return 'Let the letter find whoever knows this ache.';
    }
  }
}

/// What kind of witness/support the writer is asking for.
enum PeaceIntent {
  needToBeHeard,
  needForgiveness,
  needPerspective,
  needToLetGo,
  wantToHelp;

  String get label {
    switch (this) {
      case PeaceIntent.needToBeHeard:
        return 'I need to be heard';
      case PeaceIntent.needForgiveness:
        return 'I need forgiveness';
      case PeaceIntent.needPerspective:
        return 'I need perspective';
      case PeaceIntent.needToLetGo:
        return 'I need to let go';
      case PeaceIntent.wantToHelp:
        return 'I want to help someone else';
    }
  }
}

enum PeaceTheme {
  anger,
  guilt,
  grief,
  envy,
  shame,
  heartbreak,
  resentment,
  loneliness;

  String get label {
    switch (this) {
      case PeaceTheme.anger:
        return 'Anger';
      case PeaceTheme.guilt:
        return 'Guilt';
      case PeaceTheme.grief:
        return 'Grief';
      case PeaceTheme.envy:
        return 'Envy';
      case PeaceTheme.shame:
        return 'Shame';
      case PeaceTheme.heartbreak:
        return 'Heartbreak';
      case PeaceTheme.resentment:
        return 'Resentment';
      case PeaceTheme.loneliness:
        return 'Loneliness';
    }
  }
}

enum PeaceLetterStatus {
  draft,
  sealed,
  pendingModeration,
  approved,
  needsEdit,
  privateOnly,
  crisis,
  rejected;

  String get label {
    switch (this) {
      case PeaceLetterStatus.draft:
        return 'Draft';
      case PeaceLetterStatus.sealed:
        return 'Sealed';
      case PeaceLetterStatus.pendingModeration:
        return 'Pending review';
      case PeaceLetterStatus.approved:
        return 'In the exchange';
      case PeaceLetterStatus.needsEdit:
        return 'Needs edit';
      case PeaceLetterStatus.privateOnly:
        return 'Private only';
      case PeaceLetterStatus.crisis:
        return 'Needs support';
      case PeaceLetterStatus.rejected:
        return 'Not sent';
    }
  }
}

class PeaceLetter {
  const PeaceLetter({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.rawText,
    required this.recipientArchetype,
    required this.intent,
    this.refinedText,
    this.themes = const [],
    this.status = PeaceLetterStatus.draft,
    this.submittedAt,
    this.moderationNote,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String rawText;
  final String? refinedText;
  final PeaceRecipientArchetype recipientArchetype;
  final PeaceIntent intent;
  final List<PeaceTheme> themes;
  final PeaceLetterStatus status;
  final DateTime? submittedAt;
  final String? moderationNote;

  String get publicText => (refinedText?.trim().isNotEmpty ?? false)
      ? refinedText!.trim()
      : rawText.trim();

  int get wordCount {
    final trimmed = publicText;
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  bool get isSealed => status != PeaceLetterStatus.draft;

  PeaceLetter copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawText,
    String? refinedText,
    PeaceRecipientArchetype? recipientArchetype,
    PeaceIntent? intent,
    List<PeaceTheme>? themes,
    PeaceLetterStatus? status,
    DateTime? submittedAt,
    String? moderationNote,
    bool clearRefinedText = false,
    bool clearSubmittedAt = false,
    bool clearModerationNote = false,
  }) {
    return PeaceLetter(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawText: rawText ?? this.rawText,
      refinedText: clearRefinedText ? null : (refinedText ?? this.refinedText),
      recipientArchetype: recipientArchetype ?? this.recipientArchetype,
      intent: intent ?? this.intent,
      themes: themes ?? this.themes,
      status: status ?? this.status,
      submittedAt: clearSubmittedAt ? null : (submittedAt ?? this.submittedAt),
      moderationNote: clearModerationNote
          ? null
          : (moderationNote ?? this.moderationNote),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'rawText': rawText,
      if (refinedText != null) 'refinedText': refinedText,
      'recipientArchetype': recipientArchetype.name,
      'intent': intent.name,
      'themes': themes.map((theme) => theme.name).toList(),
      'status': status.name,
      'wordCount': wordCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (moderationNote != null) 'moderationNote': moderationNote,
    };
  }

  factory PeaceLetter.fromFirestore(Map<String, dynamic> data) {
    return PeaceLetter(
      id: data['id'] as String? ?? '',
      rawText: data['rawText'] as String? ?? '',
      refinedText: data['refinedText'] as String?,
      recipientArchetype: _enumByName(
        PeaceRecipientArchetype.values,
        data['recipientArchetype'] as String?,
        PeaceRecipientArchetype.anyoneWhoUnderstands,
      ),
      intent: _enumByName(
        PeaceIntent.values,
        data['intent'] as String?,
        PeaceIntent.needToBeHeard,
      ),
      themes:
          (data['themes'] as List<dynamic>?)
              ?.whereType<String>()
              .map(
                (name) =>
                    _enumByName(PeaceTheme.values, name, PeaceTheme.loneliness),
              )
              .toList() ??
          const [],
      status: _enumByName(
        PeaceLetterStatus.values,
        data['status'] as String?,
        PeaceLetterStatus.draft,
      ),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      submittedAt: _parseDate(data['submittedAt']),
      moderationNote: data['moderationNote'] as String?,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}
