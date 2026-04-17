import 'dart:convert';

class JournalEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final bool isBookmarked;

  const JournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    this.isBookmarked = false,
  });

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? content,
    bool? isBookmarked,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'content': content,
      'isBookmarked': isBookmarked,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory JournalEntry.fromJsonString(String source) =>
      JournalEntry.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
