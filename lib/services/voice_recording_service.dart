import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

/// State machine for [VoiceRecordingService].
enum VoiceRecorderState {
  /// Not recording, nothing in flight.
  idle,

  /// Actively capturing audio.
  recording,

  /// [stop] was called; waiting for the native side to flush the WAV.
  stopping,
}

/// Snapshot of a finished recording.
class VoiceRecordingResult {
  const VoiceRecordingResult({
    required this.audioFile,
    required this.length,
    this.maxLengthReached = false,
  });

  /// The on-disk WAV file. Always in the app's cache directory — safe to
  /// delete after the caller is done with it.
  final File audioFile;

  /// Duration of the recording. Capped at [VoiceRecordingService.maxDuration].
  final Duration length;

  /// True if the 3-minute hard cap auto-stopped the recording.
  final bool maxLengthReached;
}

/// Press-and-hold voice recorder for the journal.
///
/// Responsibilities:
/// - Ask for / check microphone permission (via `permission_handler`).
/// - Capture WAV 16kHz mono PCM16 to a temp file — Gemini-native format so
///   we don't need a re-encode step before transcription.
/// - Stream normalized peak amplitude [0..1] every 100ms for the waveform viz.
/// - Hard-stop at [maxDuration] (3 minutes) and flag the result.
/// - Clean up temp files on [cancel] or explicit [cleanup] calls so we never
///   leak audio.
///
/// Exposed as a [ChangeNotifier] so the screen can rebuild on state changes.
class VoiceRecordingService extends ChangeNotifier {
  VoiceRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// Hard cap for a single recording. Matches the UX copy ("3:00").
  static const Duration maxDuration = Duration(minutes: 3);

  /// Polling interval for peak amplitude / elapsed-time updates. 100ms gives
  /// a smooth-enough waveform without hammering the platform channel.
  static const Duration _tickInterval = Duration(milliseconds: 100);

  final AudioRecorder _recorder;

  VoiceRecorderState _state = VoiceRecorderState.idle;
  VoiceRecorderState get state => _state;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  /// Latest peak amplitude in [0..1], mapped from dBFS.
  double _amplitude = 0;
  double get amplitude => _amplitude;

  /// True when the current recording was forced to stop at [maxDuration].
  bool _maxLengthReached = false;
  bool get maxLengthReached => _maxLengthReached;

  /// Temp WAV path for the in-flight recording. Null once cleaned up.
  String? _currentPath;

  DateTime? _startedAt;
  Timer? _tickTimer;

  final StreamController<double> _amplitudeCtrl =
      StreamController<double>.broadcast();
  Stream<double> amplitudeStream() => _amplitudeCtrl.stream;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  /// Check without prompting. Safe to call at any time.
  Future<bool> hasPermission() async {
    final status = await ph.Permission.microphone.status;
    return status.isGranted;
  }

  /// Prompt the user for mic permission. Returns true if granted (or already
  /// granted). On a permanent denial on iOS we return false but don't try to
  /// re-prompt — the UI should surface a "Settings" affordance.
  Future<bool> requestPermission() async {
    final status = await ph.Permission.microphone.request();
    return status.isGranted;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Begin recording to a temp file. No-op if already recording.
  Future<void> start() async {
    if (_state != VoiceRecorderState.idle) {
      debugPrint('[VoiceRecordingService] start() called in state $_state');
      return;
    }

    // Guarantees the native layer has permission. `record` will also check,
    // but running it via permission_handler first keeps the UX consistent.
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw const VoiceRecordingException('Microphone permission denied.');
      }
    }

    final dir = await getTemporaryDirectory();
    final filename =
        'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = '${dir.path}/$filename';

    // 16 kHz mono PCM16 WAV — Gemini-native audio format. Echo cancel on,
    // noise suppress on for cleaner transcripts.
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
    );

    await _recorder.start(config, path: path);

    _currentPath = path;
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _amplitude = 0;
    _maxLengthReached = false;
    _state = VoiceRecorderState.recording;
    notifyListeners();

    _startTicker();
  }

  /// Stop recording and return the resulting file. Throws if called while idle.
  Future<VoiceRecordingResult> stop() async {
    if (_state == VoiceRecorderState.idle) {
      throw const VoiceRecordingException('Nothing is recording.');
    }
    _state = VoiceRecorderState.stopping;
    notifyListeners();

    _tickTimer?.cancel();
    _tickTimer = null;

    final path = await _recorder.stop();
    final length = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    _startedAt = null;

    final resolvedPath = path ?? _currentPath;
    if (resolvedPath == null) {
      _state = VoiceRecorderState.idle;
      notifyListeners();
      throw const VoiceRecordingException('Recorder produced no output file.');
    }

    final file = File(resolvedPath);
    final result = VoiceRecordingResult(
      audioFile: file,
      length: length > maxDuration ? maxDuration : length,
      maxLengthReached: _maxLengthReached,
    );

    _state = VoiceRecorderState.idle;
    _amplitude = 0;
    notifyListeners();

    // NB: we don't clear _currentPath here — caller may still want to upload
    // or replay. Call [cleanup] when done with the file.
    _currentPath = resolvedPath;
    return result;
  }

  /// Discard the recording — stop native capture AND delete the temp file.
  /// Called when the user releases the mic button too quickly to count as a
  /// real recording.
  Future<void> cancel() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _startedAt = null;

    if (_state != VoiceRecorderState.idle) {
      try {
        await _recorder.cancel();
      } catch (e, st) {
        debugPrint('[VoiceRecordingService] cancel() native failure: $e\n$st');
      }
    }

    final path = _currentPath;
    _currentPath = null;
    _state = VoiceRecorderState.idle;
    _amplitude = 0;
    _elapsed = Duration.zero;
    _maxLengthReached = false;
    notifyListeners();

    if (path != null) {
      await _safeDelete(path);
    }
  }

  /// Delete a temp file created by [stop]. Safe to call with a file that's
  /// already gone. Use this after upload to release disk.
  Future<void> cleanup(File file) async {
    await _safeDelete(file.path);
    if (_currentPath == file.path) {
      _currentPath = null;
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e, st) {
      debugPrint('[VoiceRecordingService] delete failed ($path): $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Ticker
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tickInterval, (_) async {
      if (_state != VoiceRecorderState.recording) return;
      final started = _startedAt;
      if (started != null) {
        _elapsed = DateTime.now().difference(started);
      }

      try {
        final amp = await _recorder.getAmplitude();
        _amplitude = _normalizeAmplitude(amp.current);
        if (!_amplitudeCtrl.isClosed) {
          _amplitudeCtrl.add(_amplitude);
        }
      } catch (_) {
        // Swallow — amplitude polling is best-effort.
      }

      notifyListeners();

      if (_elapsed >= maxDuration) {
        _maxLengthReached = true;
        // Stop asynchronously but don't surface the result — the screen
        // watches state transitions and will react.
        unawaited(() async {
          try {
            await stop();
          } catch (e, st) {
            debugPrint('[VoiceRecordingService] auto-stop failed: $e\n$st');
          }
        }());
      }
    });
  }

  /// Map a dBFS amplitude (typically [-160..0]) to [0..1].
  /// Values below -60 dBFS clamp to 0 — below human speech noise floor.
  double _normalizeAmplitude(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0;
    const floor = -60.0;
    if (dbfs <= floor) return 0;
    if (dbfs >= 0) return 1;
    return ((dbfs - floor) / -floor).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _amplitudeCtrl.close();
    // Don't await — ChangeNotifier.dispose is sync.
    () async {
      try {
        await _recorder.dispose();
      } catch (_) {}
      final path = _currentPath;
      if (path != null) {
        await _safeDelete(path);
      }
    }();
    super.dispose();
  }
}

class VoiceRecordingException implements Exception {
  const VoiceRecordingException(this.message);
  final String message;

  @override
  String toString() => 'VoiceRecordingException: $message';
}
