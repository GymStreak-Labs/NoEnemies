import 'dart:convert';

enum Mood {
  struggling,
  uneasy,
  neutral,
  calm,
  peaceful;

  String get emoji {
    switch (this) {
      case Mood.struggling:
        return '😔';
      case Mood.uneasy:
        return '😟';
      case Mood.neutral:
        return '😐';
      case Mood.calm:
        return '😌';
      case Mood.peaceful:
        return '🕊️';
    }
  }

  String get label {
    switch (this) {
      case Mood.struggling:
        return 'Struggling';
      case Mood.uneasy:
        return 'Uneasy';
      case Mood.neutral:
        return 'Neutral';
      case Mood.calm:
        return 'Calm';
      case Mood.peaceful:
        return 'At Peace';
    }
  }

  /// 0.0 to 1.0 — higher is more peaceful
  double get peaceScore {
    switch (this) {
      case Mood.struggling:
        return 0.1;
      case Mood.uneasy:
        return 0.3;
      case Mood.neutral:
        return 0.5;
      case Mood.calm:
        return 0.75;
      case Mood.peaceful:
        return 1.0;
    }
  }
}

enum CheckInType { morning, evening }

class DimensionRating {
  final String name;
  final double value; // 0.0 to 1.0

  const DimensionRating({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory DimensionRating.fromJson(Map<String, dynamic> json) {
    return DimensionRating(
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

class CheckIn {
  final String id;
  final DateTime date;
  final CheckInType type;
  final Mood mood;
  final String? intention; // morning
  final String? reflectionAnswer; // evening
  final List<DimensionRating> dimensions; // evening
  final String? aiPrompt;
  final bool isPeaceful;

  const CheckIn({
    required this.id,
    required this.date,
    required this.type,
    required this.mood,
    this.intention,
    this.reflectionAnswer,
    this.dimensions = const [],
    this.aiPrompt,
    this.isPeaceful = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.index,
      'mood': mood.index,
      'intention': intention,
      'reflectionAnswer': reflectionAnswer,
      'dimensions': dimensions.map((d) => d.toJson()).toList(),
      'aiPrompt': aiPrompt,
      'isPeaceful': isPeaceful,
    };
  }

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: CheckInType.values[json['type'] as int],
      mood: Mood.values[json['mood'] as int],
      intention: json['intention'] as String?,
      reflectionAnswer: json['reflectionAnswer'] as String?,
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map(
                  (d) => DimensionRating.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      aiPrompt: json['aiPrompt'] as String?,
      isPeaceful: json['isPeaceful'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory CheckIn.fromJsonString(String source) =>
      CheckIn.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
