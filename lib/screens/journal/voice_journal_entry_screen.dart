import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/journal_entry.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_mentor_service.dart';
import '../../services/storage_service.dart';
import '../../services/voice_recording_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/recording_waveform.dart';

/// UI states for the voice journal flow.
enum _VoiceFlowState {
  idle,
  recording,
  transcribing,
  editing,
  error,
}

/// Press-and-hold mic → record → transcribe → edit → save.
///
/// Matches the tome aesthetic of [JournalEntryScreen] so the voice entries
/// slot into the same journal list without feeling bolted on. Audio upload
/// respects the [StorageService.saveVoiceAudio] toggle.
class VoiceJournalEntryScreen extends StatefulWidget {
  const VoiceJournalEntryScreen({
    super.key,
    required this.storage,
    required this.mentor,
  });

  final StorageService storage;
  final AiMentorService mentor;

  @override
  State<VoiceJournalEntryScreen> createState() =>
      _VoiceJournalEntryScreenState();
}

class _VoiceJournalEntryScreenState extends State<VoiceJournalEntryScreen>
    with WidgetsBindingObserver {
  late final VoiceRecordingService _recorder;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  _VoiceFlowState _flowState = _VoiceFlowState.idle;
  String? _errorMessage;
  File? _pendingAudioFile;
  Duration _pendingAudioLength = Duration.zero;
  DateTime? _holdStartedAt;

  static const _tapGuard = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _recorder = VoiceRecordingService();
    _recorder.addListener(_onRecorderChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.removeListener(_onRecorderChanged);
    _recorder.dispose();
    _titleController.dispose();
    _contentController.dispose();
    // Best-effort cleanup if the user left mid-flow.
    final pending = _pendingAudioFile;
    if (pending != null) {
      () async {
        try {
          if (await pending.exists()) await pending.delete();
        } catch (_) {}
      }();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Match iMessage/Apple Voice Memos: backgrounding kills the in-flight
    // recording so we don't silently capture audio the user can't see.
    if (state != AppLifecycleState.resumed &&
        _flowState == _VoiceFlowState.recording) {
      _cancelRecording();
    }
  }

  void _onRecorderChanged() {
    // If the service auto-stopped (3-min cap), transition us accordingly.
    if (_recorder.state == VoiceRecorderState.idle &&
        _flowState == _VoiceFlowState.recording &&
        _recorder.maxLengthReached) {
      // The recorder already produced a file via its internal auto-stop;
      // but we don't have the result object here — kick stop() ourselves.
      _finishRecording(forced: true);
    } else if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // Recording gesture
  // ---------------------------------------------------------------------------

  Future<void> _beginRecording() async {
    if (_flowState != _VoiceFlowState.idle) return;
    HapticFeedback.mediumImpact();
    _holdStartedAt = DateTime.now();
    try {
      await _recorder.start();
      if (!mounted) return;
      setState(() {
        _flowState = _VoiceFlowState.recording;
      });
    } on VoiceRecordingException catch (e) {
      if (!mounted) return;
      setState(() {
        _flowState = _VoiceFlowState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flowState = _VoiceFlowState.error;
        _errorMessage = 'Could not start recording. $e';
      });
    }
  }

  Future<void> _endRecording() async {
    if (_flowState != _VoiceFlowState.recording) return;
    final held =
        _holdStartedAt == null ? Duration.zero : DateTime.now().difference(_holdStartedAt!);
    _holdStartedAt = null;

    // Too-short press: treat as accidental tap. Discard and stay idle.
    if (held < _tapGuard) {
      await _cancelRecording();
      return;
    }
    await _finishRecording();
  }

  Future<void> _finishRecording({bool forced = false}) async {
    try {
      final result = await _recorder.stop();
      if (!mounted) return;
      _pendingAudioFile = result.audioFile;
      _pendingAudioLength = result.length;
      setState(() {
        _flowState = _VoiceFlowState.transcribing;
      });
      HapticFeedback.lightImpact();
      await _runTranscription(result.audioFile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flowState = _VoiceFlowState.error;
        _errorMessage = 'Could not save the recording. $e';
      });
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _flowState = _VoiceFlowState.idle;
      _holdStartedAt = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Transcription
  // ---------------------------------------------------------------------------

  Future<void> _runTranscription(File audio) async {
    final transcript = await widget.mentor.transcribeAudio(audio);
    if (!mounted) return;
    setState(() {
      _contentController.text = transcript;
      _flowState = _VoiceFlowState.editing;
    });
  }

  Future<void> _retryTranscription() async {
    final file = _pendingAudioFile;
    if (file == null) return;
    setState(() {
      _flowState = _VoiceFlowState.transcribing;
    });
    await _runTranscription(file);
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();
    if (content.isEmpty) {
      _showSnack('Nothing to save yet.');
      return;
    }

    final userProvider = context.read<UserProvider>();
    final repo = userProvider.repo;
    if (repo == null) {
      _showSnack('Sign-in required before saving.');
      return;
    }

    setState(() {
      _flowState = _VoiceFlowState.transcribing;
    });

    final ids = userProvider.newJournalEntryId();
    String? storagePath;
    int? durationSeconds;

    final shouldPersistAudio = widget.storage.saveVoiceAudio;
    final audioFile = _pendingAudioFile;

    if (shouldPersistAudio && audioFile != null && await audioFile.exists()) {
      try {
        storagePath = await repo.uploadJournalAudio(ids.entryId, audioFile);
        durationSeconds = _pendingAudioLength.inSeconds;
      } catch (e) {
        // Don't block the save — keep the transcript even if upload fails.
        // Most likely cause: Firebase Storage not yet enabled (Blaze).
        debugPrint('[VoiceJournalEntryScreen] audio upload failed: $e');
      }
    }

    final entry = JournalEntry(
      id: ids.entryId,
      date: DateTime.now(),
      title: title.isEmpty ? _autoTitle(content) : title,
      content: content,
      audioStoragePath: storagePath,
      audioDurationSeconds: durationSeconds,
    );

    try {
      await userProvider.saveJournalEntry(entry);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flowState = _VoiceFlowState.editing;
      });
      _showSnack('Could not save. $e');
      return;
    }

    // Always clean up the local temp file after a successful save.
    if (audioFile != null) {
      await _recorder.cleanup(audioFile);
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    context.pop();
  }

  String _autoTitle(String content) {
    final line = content.split(RegExp(r'[.!?\n]')).first.trim();
    if (line.isEmpty) return 'Spoken entry';
    if (line.length <= 42) return line;
    return '${line.substring(0, 40).trimRight()}…';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.3,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: () => _confirmExit(),
                  onSave: _flowState == _VoiceFlowState.editing ? _save : null,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (_flowState == _VoiceFlowState.idle ||
        _flowState == _VoiceFlowState.error) {
      context.pop();
      return;
    }
    // In the middle of recording / transcribing / editing with unsaved work.
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        title: Text(
          'Discard this spoken entry?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Your recording and transcript will be lost.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keep writing',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Discard',
              style: TextStyle(
                color: AppColors.war,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (keep == false) {
      await _cancelRecording();
      final file = _pendingAudioFile;
      if (file != null) {
        await _recorder.cleanup(file);
      }
      if (!mounted) return;
      context.pop();
    }
  }

  Widget _buildBody() {
    switch (_flowState) {
      case _VoiceFlowState.idle:
        return _IdleView(onHoldStart: _beginRecording, onHoldEnd: _endRecording);
      case _VoiceFlowState.recording:
        return _RecordingView(
          recorder: _recorder,
          onRelease: _endRecording,
          onCancel: _cancelRecording,
        );
      case _VoiceFlowState.transcribing:
        return const _TranscribingView();
      case _VoiceFlowState.editing:
        return _EditingView(
          titleController: _titleController,
          contentController: _contentController,
          duration: _pendingAudioLength,
          hasAudio: _pendingAudioFile != null,
          onSave: _save,
        );
      case _VoiceFlowState.error:
        return _ErrorView(
          message: _errorMessage ?? 'Something went wrong.',
          canRetry: _pendingAudioFile != null,
          onRetry: _retryTranscription,
          onReset: () {
            setState(() {
              _flowState = _VoiceFlowState.idle;
              _errorMessage = null;
            });
          },
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onSave});

  final VoidCallback onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'VOICE ENTRY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          if (onSave != null)
            GestureDetector(
              onTap: onSave,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8C87A), Color(0xFFD4A853)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Color(0xFF1A1208),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 52),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle view — big glowing mic, prompt copy.
// ─────────────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onHoldStart, required this.onHoldEnd});

  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE8C87A), Color(0xFFD4A853)],
          ).createShader(bounds),
          child: Text(
            'Speak your page',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'Hold the candle to let the ink run. Release when you\'re done. '
            'Up to three minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Spacer(),
        _HoldMicButton(onHoldStart: onHoldStart, onHoldEnd: onHoldEnd),
        const SizedBox(height: 14),
        Text(
          'Hold to speak',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _HoldMicButton extends StatefulWidget {
  const _HoldMicButton({required this.onHoldStart, required this.onHoldEnd});

  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  State<_HoldMicButton> createState() => _HoldMicButtonState();
}

class _HoldMicButtonState extends State<_HoldMicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onHoldStart();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onHoldEnd();
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.onHoldEnd();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: _pressed ? 118 : 110,
        height: _pressed ? 118 : 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: _pressed ? 0.45 : 0.28),
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: AppColors.primary
                .withValues(alpha: _pressed ? 0.8 : 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: _pressed ? 30 : 22,
              spreadRadius: _pressed ? 2 : 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.mic_rounded,
          color: AppColors.primary,
          size: 44,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recording view — pulsing mic, waveform, timer.
// ─────────────────────────────────────────────────────────────────────────────

class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.recorder,
    required this.onRelease,
    required this.onCancel,
  });

  final VoiceRecordingService recorder;
  final VoidCallback onRelease;
  final VoidCallback onCancel;

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = recorder.elapsed;
    final max = VoiceRecordingService.maxDuration;
    final approaching = elapsed.inSeconds >= max.inSeconds - 20;

    return Listener(
      onPointerUp: (_) => onRelease(),
      onPointerCancel: (_) => onRelease(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            _fmt(elapsed),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 46,
              fontWeight: FontWeight.w600,
              color: approaching ? AppColors.war : AppColors.primary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'of ${_fmt(max)}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: RecordingWaveform(
              amplitude: recorder.amplitude,
              isActive: true,
              height: 96,
            ),
          ),
          const Spacer(),
          // Big pulsing mic — purely decorative now; releasing anywhere ends
          // the recording thanks to the outer Listener.
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.5),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 14),
          Text(
            approaching
                ? 'Almost at the 3-minute mark'
                : 'Release to finish',
            style: TextStyle(
              color: approaching
                  ? AppColors.war.withValues(alpha: 0.85)
                  : AppColors.textTertiary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transcribing view
// ─────────────────────────────────────────────────────────────────────────────

class _TranscribingView extends StatelessWidget {
  const _TranscribingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeOut(duration: 700.ms)
              .then()
              .fadeIn(duration: 700.ms),
          const SizedBox(height: 22),
          Text(
            'The ink is listening…',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transcribing your words. A few seconds.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editing view — shows transcript, lets user tweak before save.
// ─────────────────────────────────────────────────────────────────────────────

class _EditingView extends StatelessWidget {
  const _EditingView({
    required this.titleController,
    required this.contentController,
    required this.duration,
    required this.hasAudio,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final Duration duration;
  final bool hasAudio;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 14,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                hasAudio
                    ? 'FROM YOUR VOICE · ${_fmt(duration)}'
                    : 'FROM YOUR VOICE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
            cursorColor: AppColors.primary,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Title this page…',
              hintStyle: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.primary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TextField(
              controller: contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: AppColors.primary,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.75,
                letterSpacing: 0.15,
                color: AppColors.textPrimary.withValues(alpha: 0.95),
              ),
              decoration: InputDecoration(
                hintText:
                    'Your words will appear here — edit them if you like.',
                hintStyle: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.75,
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8C87A), Color(0xFFD4A853)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: Color(0xFF1A1208), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Save entry',
                      style: TextStyle(
                        color: Color(0xFF1A1208),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error view
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onReset,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.war.withValues(alpha: 0.8),
              size: 48,
            ),
            const SizedBox(height: 18),
            Text(
              'Something broke the silence',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            if (canRetry)
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              )
            else
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Start over'),
              ),
          ],
        ),
      ),
    );
  }
}
