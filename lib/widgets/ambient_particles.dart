import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A reusable ambient particle effect widget.
/// Creates floating, glowing particles that drift upward and fade.
class AmbientParticles extends StatefulWidget {
  final int particleCount;
  final Color color;
  final double maxParticleSize;
  final double minParticleSize;
  final double opacity;
  final bool enabled;

  const AmbientParticles({
    super.key,
    this.particleCount = 30,
    this.color = AppColors.primary,
    this.maxParticleSize = 4.0,
    this.minParticleSize = 1.0,
    this.opacity = 0.6,
    this.enabled = true,
  });

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _createParticle());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(() {
      if (mounted && widget.enabled) {
        setState(() {
          _updateParticles();
        });
      }
    });
  }

  _Particle _createParticle({bool randomizeY = true}) {
    return _Particle(
      x: _random.nextDouble(),
      y: randomizeY ? _random.nextDouble() : 1.0 + _random.nextDouble() * 0.1,
      size: widget.minParticleSize +
          _random.nextDouble() * (widget.maxParticleSize - widget.minParticleSize),
      speedX: (_random.nextDouble() - 0.5) * 0.0008,
      speedY: -0.0005 - _random.nextDouble() * 0.0015,
      opacity: 0.1 + _random.nextDouble() * widget.opacity,
      flickerSpeed: 0.5 + _random.nextDouble() * 2.0,
      flickerOffset: _random.nextDouble() * pi * 2,
    );
  }

  void _updateParticles() {
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.x += p.speedX;
      p.y += p.speedY;

      // Wrap horizontally
      if (p.x < -0.05) p.x = 1.05;
      if (p.x > 1.05) p.x = -0.05;

      // Reset when going off top
      if (p.y < -0.05) {
        _particles[i] = _createParticle(randomizeY: false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          color: widget.color,
          time: _controller.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;
  double flickerSpeed;
  double flickerOffset;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.flickerSpeed,
    required this.flickerOffset,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double time;

  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Flicker effect
      final flicker = (sin(time * pi * 2 * p.flickerSpeed + p.flickerOffset) + 1) / 2;
      final currentOpacity = p.opacity * (0.4 + flicker * 0.6);

      // Fade near edges
      final edgeFade = _edgeFade(p.y);
      final finalOpacity = (currentOpacity * edgeFade).clamp(0.0, 1.0);

      if (finalOpacity < 0.01) continue;

      final position = Offset(p.x * size.width, p.y * size.height);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: finalOpacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(position, p.size * 2.5, glowPaint);

      // Core
      final corePaint = Paint()
        ..color = color.withValues(alpha: finalOpacity);
      canvas.drawCircle(position, p.size, corePaint);
    }
  }

  double _edgeFade(double y) {
    if (y < 0.05) return y / 0.05;
    if (y > 0.95) return (1.0 - y) / 0.05;
    return 1.0;
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
