import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../services/firestore_repository.dart';
import '../theme/app_colors.dart';

/// Compact amber-on-black audio player for voice journal entries.
///
/// Fetches a download URL from [FirestoreRepository.downloadJournalAudioUrl]
/// on mount, then streams playback via [just_audio]. Handles all three failure
/// modes gracefully (storage unavailable, clip deleted, offline) by rendering
/// a disabled-looking row with an explanatory line — the transcript below the
/// player is always the source of truth.
class JournalAudioPlayer extends StatefulWidget {
  const JournalAudioPlayer({
    super.key,
    required this.repository,
    required this.storagePath,
    required this.knownDuration,
  });

  final FirestoreRepository repository;
  final String storagePath;

  /// Duration the entry claimed when saved (from [JournalEntry.audioDurationSeconds]).
  /// Used as a fallback while we wait for the real duration from the decoder.
  final Duration knownDuration;

  @override
  State<JournalAudioPlayer> createState() => _JournalAudioPlayerState();
}

class _JournalAudioPlayerState extends State<JournalAudioPlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _ready = false;
  bool _playing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = widget.knownDuration;
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
    });
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durSub = _player.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _duration = d);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await widget.repository.downloadJournalAudioUrl(
        widget.storagePath,
      );
      await _player.setUrl(url.toString());
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Audio unavailable';
      });
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_playing) {
      await _player.pause();
    } else {
      // Restart from 0 if we're already at the end.
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration == Duration.zero ? widget.knownDuration : _duration;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _errorMessage == null ? _togglePlay : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _errorMessage == null
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.4),
                          AppColors.primary.withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                color: _errorMessage == null
                    ? null
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: _errorMessage == null ? 0.6 : 0.2,
                  ),
                ),
              ),
              child: Icon(
                _errorMessage != null
                    ? Icons.mic_off_outlined
                    : _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                color: AppColors.primary.withValues(
                  alpha: _errorMessage == null ? 1.0 : 0.5,
                ),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage ?? 'From your voice',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary.withValues(
                      alpha: _errorMessage == null ? 0.85 : 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary.withValues(
                        alpha: _errorMessage == null ? 0.8 : 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _errorMessage == null
                ? '${_fmt(_position)} / ${_fmt(total)}'
                : _fmt(widget.knownDuration),
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
