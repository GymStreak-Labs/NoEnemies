import 'package:cloud_firestore/cloud_firestore.dart';

/// A structured support mode for replying to someone else's Peace Letter.
enum PeaceResponseMode {
  iHearYou,
  feltThisToo,
  softerWay,
  letterBack,
  quietBlessing;

  String get label {
    switch (this) {
      case PeaceResponseMode.iHearYou:
        return 'I hear you';
      case PeaceResponseMode.feltThisToo:
        return 'I’ve felt this too';
      case PeaceResponseMode.softerWay:
        return 'A softer way to see this';
      case PeaceResponseMode.letterBack:
        return 'A letter back';
      case PeaceResponseMode.quietBlessing:
        return 'A quiet blessing';
    }
  }
}

class PeaceOffering {
  const PeaceOffering({
    required this.id,
    required this.letterId,
    required this.responseMode,
    required this.body,
    required this.createdAt,
    this.savedToBook = false,
  });

  final String id;
  final String letterId;
  final PeaceResponseMode responseMode;
  final String body;
  final DateTime createdAt;
  final bool savedToBook;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'letterId': letterId,
      'responseMode': responseMode.name,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'savedToBook': savedToBook,
    };
  }

  factory PeaceOffering.fromFirestore(Map<String, dynamic> data) {
    return PeaceOffering(
      id: data['id'] as String? ?? '',
      letterId: data['letterId'] as String? ?? '',
      responseMode: _responseModeByName(data['responseMode'] as String?),
      body: data['body'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      savedToBook: data['savedToBook'] as bool? ?? false,
    );
  }
}

PeaceResponseMode _responseModeByName(String? name) {
  for (final value in PeaceResponseMode.values) {
    if (value.name == name) return value;
  }
  return PeaceResponseMode.iHearYou;
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}
