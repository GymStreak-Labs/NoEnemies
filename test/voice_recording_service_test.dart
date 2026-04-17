// Lightweight unit tests for the [VoiceRecordingService] public surface.
//
// Constructing the real [AudioRecorder] hits a platform channel, which isn't
// available in unit tests. Rather than install a full plugin mock, we cover
// the parts of the API that matter most for correctness and don't require
// the native side:
//   1. [VoiceRecordingResult] preserves the fields the UI reads
//   2. [VoiceRecordingException] has a useful toString
//   3. [VoiceRecorderState] enumerates every state the UI switches on
//
// The state-machine invariants that DO need a recorder (start → recording →
// stop → idle) are exercised end-to-end in the simulator smoke test instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_enemies/services/voice_recording_service.dart';

void main() {
  group('VoiceRecorderState', () {
    test('has exactly the three states the UI branches on', () {
      // If you add a new state, update [VoiceJournalEntryScreen]._flowState
      // mapping first — otherwise the UI will silently ignore it.
      expect(VoiceRecorderState.values, [
        VoiceRecorderState.idle,
        VoiceRecorderState.recording,
        VoiceRecorderState.stopping,
      ]);
    });
  });

  group('VoiceRecordingResult', () {
    test('holds file, length, and maxLengthReached flag', () {
      final f = File('/tmp/test.wav');
      final r = VoiceRecordingResult(
        audioFile: f,
        length: const Duration(seconds: 30),
        maxLengthReached: false,
      );
      expect(r.audioFile, f);
      expect(r.length, const Duration(seconds: 30));
      expect(r.maxLengthReached, isFalse);
    });

    test('maxLengthReached defaults to false', () {
      final r = VoiceRecordingResult(
        audioFile: File('/tmp/x.wav'),
        length: const Duration(seconds: 10),
      );
      expect(r.maxLengthReached, isFalse);
    });
  });

  group('VoiceRecordingException', () {
    test('toString includes the message for debugging', () {
      const e = VoiceRecordingException('Microphone permission denied.');
      expect(e.toString(), contains('Microphone permission denied.'));
    });
  });
}
