import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'conflict_type.dart';

enum UserTitle {
  warrior,
  wanderer,
  seeker,
  peacemaker;

  String get displayName {
    switch (this) {
      case UserTitle.warrior:
        return 'Warrior';
      case UserTitle.wanderer:
        return 'Wanderer';
      case UserTitle.seeker:
        return 'Seeker';
      case UserTitle.peacemaker:
        return 'Peacemaker';
    }
  }

  String get description {
    switch (this) {
      case UserTitle.warrior:
        return 'Still fighting, but aware';
      case UserTitle.wanderer:
        return 'Seeking a different path';
      case UserTitle.seeker:
        return 'Actively working on peace';
      case UserTitle.peacemaker:
        return 'Living it';
    }
  }

  int get requiredDays {
    switch (this) {
      case UserTitle.warrior:
        return 0;
      case UserTitle.wanderer:
        return 7;
      case UserTitle.seeker:
        return 30;
      case UserTitle.peacemaker:
        return 90;
    }
  }
}

class UserProfile {
  final String id;
  final ConflictType primaryConflict;
  final List<int> quizAnswers;
  final DateTime createdAt;
  final int totalDaysOfPeace;
  final int currentStreak;
  final int longestStreak;
  final int peaceDays;
  final int warDays;
  final DateTime? lastCheckInDate;
  final bool hasCompletedOnboarding;
  final String? displayName;
  final String? conflictTarget;
  final String? conflictDuration;
  final int conflictIntensity;
  final String? conflictStyle;
  final String? preferredCheckInTime;
  final String? personalIntention;
  final List<String> previousAttempts;

  const UserProfile({
    required this.id,
    required this.primaryConflict,
    this.quizAnswers = const [],
    required this.createdAt,
    this.totalDaysOfPeace = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.peaceDays = 0,
    this.warDays = 0,
    this.lastCheckInDate,
    this.hasCompletedOnboarding = false,
    this.displayName,
    this.conflictTarget,
    this.conflictDuration,
    this.conflictIntensity = 5,
    this.conflictStyle,
    this.preferredCheckInTime,
    this.personalIntention,
    this.previousAttempts = const [],
  });

  UserTitle get currentTitle {
    if (totalDaysOfPeace >= UserTitle.peacemaker.requiredDays) {
      return UserTitle.peacemaker;
    } else if (totalDaysOfPeace >= UserTitle.seeker.requiredDays) {
      return UserTitle.seeker;
    } else if (totalDaysOfPeace >= UserTitle.wanderer.requiredDays) {
      return UserTitle.wanderer;
    }
    return UserTitle.warrior;
  }

  double get peaceRatio {
    final total = peaceDays + warDays;
    if (total == 0) return 0.5;
    return peaceDays / total;
  }

  int get daysSinceStart {
    return DateTime.now().difference(createdAt).inDays;
  }

  bool get hasCheckedInToday {
    if (lastCheckInDate == null) return false;
    final now = DateTime.now();
    return lastCheckInDate!.year == now.year &&
        lastCheckInDate!.month == now.month &&
        lastCheckInDate!.day == now.day;
  }

  UserProfile copyWith({
    String? id,
    ConflictType? primaryConflict,
    List<int>? quizAnswers,
    DateTime? createdAt,
    int? totalDaysOfPeace,
    int? currentStreak,
    int? longestStreak,
    int? peaceDays,
    int? warDays,
    DateTime? lastCheckInDate,
    bool? hasCompletedOnboarding,
    String? displayName,
    String? conflictTarget,
    String? conflictDuration,
    int? conflictIntensity,
    String? conflictStyle,
    String? preferredCheckInTime,
    String? personalIntention,
    List<String>? previousAttempts,
  }) {
    return UserProfile(
      id: id ?? this.id,
      primaryConflict: primaryConflict ?? this.primaryConflict,
      quizAnswers: quizAnswers ?? this.quizAnswers,
      createdAt: createdAt ?? this.createdAt,
      totalDaysOfPeace: totalDaysOfPeace ?? this.totalDaysOfPeace,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      peaceDays: peaceDays ?? this.peaceDays,
      warDays: warDays ?? this.warDays,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      displayName: displayName ?? this.displayName,
      conflictTarget: conflictTarget ?? this.conflictTarget,
      conflictDuration: conflictDuration ?? this.conflictDuration,
      conflictIntensity: conflictIntensity ?? this.conflictIntensity,
      conflictStyle: conflictStyle ?? this.conflictStyle,
      preferredCheckInTime: preferredCheckInTime ?? this.preferredCheckInTime,
      personalIntention: personalIntention ?? this.personalIntention,
      previousAttempts: previousAttempts ?? this.previousAttempts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'primaryConflict': primaryConflict.index,
      'quizAnswers': quizAnswers,
      'createdAt': createdAt.toIso8601String(),
      'totalDaysOfPeace': totalDaysOfPeace,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'peaceDays': peaceDays,
      'warDays': warDays,
      'lastCheckInDate': lastCheckInDate?.toIso8601String(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'displayName': displayName,
      'conflictTarget': conflictTarget,
      'conflictDuration': conflictDuration,
      'conflictIntensity': conflictIntensity,
      'conflictStyle': conflictStyle,
      'preferredCheckInTime': preferredCheckInTime,
      'personalIntention': personalIntention,
      'previousAttempts': previousAttempts,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      primaryConflict: ConflictType.values[json['primaryConflict'] as int],
      quizAnswers: (json['quizAnswers'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      totalDaysOfPeace: json['totalDaysOfPeace'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      peaceDays: json['peaceDays'] as int? ?? 0,
      warDays: json['warDays'] as int? ?? 0,
      lastCheckInDate: _parseDate(json['lastCheckInDate']),
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      displayName: json['displayName'] as String?,
      conflictTarget: json['conflictTarget'] as String?,
      conflictDuration: json['conflictDuration'] as String?,
      conflictIntensity: json['conflictIntensity'] as int? ?? 5,
      conflictStyle: json['conflictStyle'] as String?,
      preferredCheckInTime: json['preferredCheckInTime'] as String?,
      personalIntention: json['personalIntention'] as String?,
      previousAttempts: (json['previousAttempts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Firestore-friendly map — uses [Timestamp] for dates so queries like
  /// `orderBy('createdAt')` work as expected.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      ...toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastCheckInDate':
          lastCheckInDate == null ? null : Timestamp.fromDate(lastCheckInDate!),
      'schemaVersion': 1,
    };
    return map;
  }

  /// Build a [UserProfile] from a Firestore document payload. Accepts both
  /// [Timestamp] and ISO-8601 string dates so the same parser handles cloud
  /// reads AND legacy SharedPreferences migration.
  factory UserProfile.fromFirestore(Map<String, dynamic> json) {
    return UserProfile.fromJson(json);
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String source) =>
      UserProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Accepts Firestore [Timestamp], ISO-8601 [String], or [DateTime] and
/// returns a [DateTime]. Returns null if the value is null/empty.
DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
