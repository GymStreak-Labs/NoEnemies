import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight amplitude-driven waveform. Holds a rolling buffer of recent
/// peak amplitudes and paints them as vertical amber bars centred on the
/// vertical midline.
///
/// Each incoming amplitude is pushed onto a fixed-length ring; the oldest
/// values scroll off the left edge. Cheap — all in CustomPainter, no
/// animations per-bar.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({
    super.key,
    required this.amplitude,
    required this.isActive,
    this.height = 72,
    this.barCount = 48,
  });

  /// Latest peak amplitude in [0..1]. Poll this from the recorder service.
  final double amplitude;

  /// When false the bars decay to a flat line (used for idle / transcribing).
  final bool isActive;

  final double height;
  final int barCount;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> {
  late List<double> _history;

  @override
  void initState() {
    super.initState();
    _history = List<double>.filled(widget.barCount, 0);
  }

  @override
  void didUpdateWidget(covariant RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _history = List<double>.filled(widget.barCount, 0);
    }
    if (oldWidget.amplitude != widget.amplitude ||
        oldWidget.isActive != widget.isActive) {
      // Shift-left one slot, push the new value (or decay when inactive).
      final next = List<double>.from(_history);
      for (var i = 0; i < next.length - 1; i++) {
        next[i] = next[i + 1];
      }
      next[next.length - 1] =
          widget.isActive ? widget.amplitude : widget.amplitude * 0.5;
      _history = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _WaveformPainter(
          samples: _history,
          active: widget.isActive,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.samples, required this.active});

  final List<double> samples;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final count = samples.length;
    final gap = 2.0;
    final barWidth = math.max(2.0, (size.width - gap * (count - 1)) / count);
    final midY = size.height / 2;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = active
          ? AppColors.primary.withValues(alpha: 0.85)
          : AppColors.primary.withValues(alpha: 0.35);

    for (var i = 0; i < count; i++) {
      final v = samples[i].clamp(0.0, 1.0);
      // Minimum baseline so flat silence still shows a hairline — makes the
      // recording feel alive even mid-pause.
      final h = (v * size.height).clamp(2.0, size.height - 2);
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - h / 2, barWidth, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.samples != samples || old.active != active;
}
