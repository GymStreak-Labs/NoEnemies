import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final bool isBookmarked;

  /// Phase 2 voice journaling — Firebase Storage path, e.g.
  /// `users/{uid}/audio/journal/{entryId}.wav`. Null for plain text entries
  /// and for voice entries where the user opted out of audio persistence.
  final String? audioStoragePath;

  /// Duration of the saved audio in seconds, if any. Used to show the
  /// scrubber's total length without fetching the file first.
  final int? audioDurationSeconds;

  const JournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    this.isBookmarked = false,
    this.audioStoragePath,
    this.audioDurationSeconds,
  });

  /// True when the entry has a playable audio clip attached.
  bool get hasAudio =>
      audioStoragePath != null && audioStoragePath!.isNotEmpty;

  /// Convenience: word count derived from [content]. Firestore stores this
  /// alongside the entry so we can sort/aggregate without re-tokenizing on
  /// every read.
  int get wordCount {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? content,
    bool? isBookmarked,
    String? audioStoragePath,
    int? audioDurationSeconds,
    // Explicit clears — nullable-override support without a sentinel.
    bool clearAudio = false,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      audioStoragePath:
          clearAudio ? null : (audioStoragePath ?? this.audioStoragePath),
      audioDurationSeconds: clearAudio
          ? null
          : (audioDurationSeconds ?? this.audioDurationSeconds),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'content': content,
      'isBookmarked': isBookmarked,
      if (audioStoragePath != null) 'audioStoragePath': audioStoragePath,
      if (audioDurationSeconds != null)
        'audioDurationSeconds': audioDurationSeconds,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: _parseDate(json['date'] ?? json['createdAt']) ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      audioStoragePath: json['audioStoragePath'] as String?,
      audioDurationSeconds: (json['audioDurationSeconds'] as num?)?.toInt(),
    );
  }

  /// Firestore-friendly map with [Timestamp] dates and derived [wordCount].
  Map<String, dynamic> toFirestore({DateTime? updatedAt}) {
    final now = updatedAt ?? DateTime.now();
    return {
      'id': id,
      'title': title,
      'content': content,
      'isBookmarked': isBookmarked,
      'wordCount': wordCount,
      'createdAt': Timestamp.fromDate(date),
      'updatedAt': Timestamp.fromDate(now),
      // Only include audio fields when present — keeps the doc small for
      // text-only entries and lets old entries decode unchanged.
      if (audioStoragePath != null) 'audioStoragePath': audioStoragePath,
      if (audioDurationSeconds != null)
        'audioDurationSeconds': audioDurationSeconds,
    };
  }

  /// Build from a Firestore doc payload. Handles both [Timestamp] (cloud)
  /// and [String] (legacy SharedPreferences migration) dates.
  factory JournalEntry.fromFirestore(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: _parseDate(json['createdAt'] ?? json['date']) ?? DateTime.now(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      audioStoragePath: json['audioStoragePath'] as String?,
      audioDurationSeconds: (json['audioDurationSeconds'] as num?)?.toInt(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory JournalEntry.fromJsonString(String source) =>
      JournalEntry.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}
