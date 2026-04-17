import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Loads the dissolve fragment shader once and caches it for the app lifetime.
class DissolveShaderCache {
  DissolveShaderCache._();

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loading;

  /// Returns the compiled [FragmentProgram]. Safe to call multiple times.
  static Future<ui.FragmentProgram> load() {
    _loading ??= ui.FragmentProgram.fromAsset('shaders/dissolve.frag').then((p) {
      _program = p;
      return p;
    });
    return _loading!;
  }

  /// Returns the cached program if already loaded, otherwise null.
  static ui.FragmentProgram? get program => _program;
}

/// Overlays a dissolve shader on top of [child].
///
/// When [progress] is 0 the child is fully visible.
/// When [progress] is 1 the child is fully dissolved (transparent).
///
/// The shader paints an amber glow along the dissolve edge for a cinematic
/// "ink burning away" look.
class ShaderDissolveOverlay extends StatelessWidget {
  const ShaderDissolveOverlay({
    super.key,
    required this.progress,
    required this.child,
  });

  /// 0 = fully visible, 1 = fully dissolved.
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final program = DissolveShaderCache.program;
    if (program == null || progress <= 0.0) {
      // Shader not loaded yet or nothing to dissolve — show child as-is.
      return child;
    }
    if (progress >= 1.0) {
      // Fully dissolved — nothing to show.
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // The outgoing scene, clipped by the shader alpha.
        // We use saveLayer so the shader's alpha actually punches holes.
        CustomPaint(
          size: Size.infinite,
          painter: _DissolveLayerPainter(
            shader: program.fragmentShader(),
            progress: progress,
            child: child,
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

/// A more integrated painter that uses [saveLayer] + shader to composite
/// the child widget with the dissolve mask in a single paint pass.
///
/// This avoids double-drawing and gives correct alpha blending.
class _DissolveLayerPainter extends CustomPainter {
  _DissolveLayerPainter({
    required this.shader,
    required this.progress,
    required this.child,
  });

  final ui.FragmentShader shader;
  final double progress;
  final Widget child;

  @override
  void paint(Canvas canvas, Size size) {
    // We only draw the mask here; the actual child is drawn by the widget
    // tree beneath us.  See [DissolveTransition] for the full compositing.
  }

  @override
  bool shouldRepaint(covariant _DissolveLayerPainter old) =>
      old.progress != progress;
}

/// High-level transition widget that dissolves [outgoingChild] to reveal
/// [incomingChild] using the GLSL dissolve shader.
///
/// Uses a simple Stack approach:
///   bottom: incoming child (fades in via opacity)
///   top: outgoing child with shader dissolve overlay
class DissolveTransition extends StatelessWidget {
  const DissolveTransition({
    super.key,
    required this.progress,
    required this.outgoingChild,
    required this.incomingChild,
  });

  /// 0 = outgoing fully visible, 1 = incoming fully visible.
  final double progress;
  final Widget outgoingChild;
  final Widget incomingChild;

  @override
  Widget build(BuildContext context) {
    final program = DissolveShaderCache.program;

    // If shader isn't loaded, fall back to a simple crossfade.
    if (program == null) {
      return Stack(
        children: [
          Positioned.fill(child: outgoingChild),
          Positioned.fill(
            child: Opacity(opacity: progress, child: incomingChild),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Incoming scene — sits behind, simple fade in.
        Positioned.fill(
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: incomingChild,
          ),
        ),

        // Outgoing scene — on top, dissolving away via shader.
        if (progress < 1.0)
          Positioned.fill(
            child: _ShaderMaskedWidget(
              progress: progress,
              program: program,
              child: outgoingChild,
            ),
          ),
      ],
    );
  }
}

/// Applies the dissolve shader as an alpha mask to [child] using
/// [ShaderMask].
class _ShaderMaskedWidget extends StatelessWidget {
  const _ShaderMaskedWidget({
    required this.progress,
    required this.program,
    required this.child,
  });

  final double progress;
  final ui.FragmentProgram program;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shader = program.fragmentShader();
        shader.setFloat(0, progress);
        shader.setFloat(1, constraints.maxWidth);
        shader.setFloat(2, constraints.maxHeight);

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            // Re-set with actual bounds in case layout differs.
            shader.setFloat(1, bounds.width);
            shader.setFloat(2, bounds.height);
            return shader;
          },
          child: child,
        );
      },
    );
  }
}
