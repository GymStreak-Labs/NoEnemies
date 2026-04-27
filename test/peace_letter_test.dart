import 'package:flutter_test/flutter_test.dart';
import 'package:no_enemies/models/peace_letter.dart';
import 'package:no_enemies/models/peace_offering.dart';

void main() {
  group('PeaceLetter Firestore round-trip', () {
    test('preserves recipient, intent, themes, status, and word count', () {
      final letter = PeaceLetter(
        id: 'letter-1',
        createdAt: DateTime.utc(2026, 4, 27, 10),
        updatedAt: DateTime.utc(2026, 4, 27, 11),
        rawText: 'I have been carrying this anger for too long.',
        refinedText: 'I have carried this anger and I am ready to set it down.',
        recipientArchetype: PeaceRecipientArchetype.enemyInMyHead,
        intent: PeaceIntent.needToLetGo,
        themes: const [PeaceTheme.anger, PeaceTheme.resentment],
        status: PeaceLetterStatus.sealed,
        submittedAt: DateTime.utc(2026, 4, 27, 12),
        moderationNote: 'Sealed privately.',
      );

      final roundTrip = PeaceLetter.fromFirestore(letter.toFirestore());

      expect(roundTrip.id, 'letter-1');
      expect(
        roundTrip.recipientArchetype,
        PeaceRecipientArchetype.enemyInMyHead,
      );
      expect(roundTrip.intent, PeaceIntent.needToLetGo);
      expect(roundTrip.themes, [PeaceTheme.anger, PeaceTheme.resentment]);
      expect(roundTrip.status, PeaceLetterStatus.sealed);
      expect(roundTrip.publicText, letter.refinedText);
      expect(roundTrip.wordCount, 13);
      expect(roundTrip.moderationNote, 'Sealed privately.');
    });

    test('handles legacy/missing enum values with safe defaults', () {
      final roundTrip = PeaceLetter.fromFirestore({
        'id': 'legacy',
        'rawText': 'Please hear me.',
        'recipientArchetype': 'unknown',
        'intent': 'unknown',
        'themes': ['unknown'],
        'status': 'unknown',
      });

      expect(
        roundTrip.recipientArchetype,
        PeaceRecipientArchetype.anyoneWhoUnderstands,
      );
      expect(roundTrip.intent, PeaceIntent.needToBeHeard);
      expect(roundTrip.themes, [PeaceTheme.loneliness]);
      expect(roundTrip.status, PeaceLetterStatus.draft);
    });
  });

  group('PeaceOffering Firestore round-trip', () {
    test('preserves response mode and saved state', () {
      final offering = PeaceOffering(
        id: 'offering-1',
        letterId: 'letter-1',
        responseMode: PeaceResponseMode.quietBlessing,
        body: 'May this become lighter in your hands.',
        createdAt: DateTime.utc(2026, 4, 27),
        savedToBook: true,
      );

      final roundTrip = PeaceOffering.fromFirestore(offering.toFirestore());

      expect(roundTrip.id, 'offering-1');
      expect(roundTrip.letterId, 'letter-1');
      expect(roundTrip.responseMode, PeaceResponseMode.quietBlessing);
      expect(roundTrip.body, offering.body);
      expect(roundTrip.savedToBook, isTrue);
    });
  });
}
