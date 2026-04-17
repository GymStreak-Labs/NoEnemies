import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// Stage-aware ambient particle layer. Each UserTitle gets a unique particle
/// style that matches the Vinland Saga aesthetic of its scene:
///
/// - Warrior:    rising embers/sparks (fire on the battlefield)
/// - Wanderer:   golden dust motes drifting in sunlight
/// - Seeker:     bioluminescent particles glowing in dark water
/// - Peacemaker: petals + pollen drifting through meadow air
class StageParticles extends StatefulWidget {
  final UserTitle title;
  final int particleCount;
  final double opacity;

  const StageParticles({
    super.key,
    required this.title,
    this.particleCount = 30,
    this.opacity = 0.7,
  });

  @override
  State<StageParticles> createState() => _StageParticlesState();
}

class _StageParticlesState extends State<StageParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  _StageStyle get _style => _styleFor(widget.title);

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _make());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(() {
      if (mounted) setState(_tick);
    });
  }

  @override
  void didUpdateWidget(covariant StageParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.particleCount != widget.particleCount) {
      _particles = List.generate(widget.particleCount, (_) => _make());
    }
  }

  _Particle _make({bool offscreenY = false}) {
    final s = _style;
    return _Particle(
      x: _random.nextDouble(),
      y: offscreenY ? 1.05 + _random.nextDouble() * 0.1 : _random.nextDouble(),
      size: s.minSize + _random.nextDouble() * (s.maxSize - s.minSize),
      speedX: (_random.nextDouble() - 0.5) * s.driftXAmplitude,
      speedY: s.baseSpeedY + _random.nextDouble() * s.varSpeedY,
      opacity: s.minOpacity +
          _random.nextDouble() * (widget.opacity - s.minOpacity),
      flickerSpeed: s.flickerMin + _random.nextDouble() * s.flickerVar,
      flickerOffset: _random.nextDouble() * pi * 2,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * s.rotationSpeed,
    );
  }

  void _tick() {
    final s = _style;
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      // Sine-wave horizontal sway (more pronounced for petals)
      final sway = sin(_controller.value * pi * 2 * 0.2 + p.flickerOffset) *
          s.swayAmplitude;
      p.x += p.speedX + sway * 0.0003;
      p.y += p.speedY;
      p.rotation += p.rotationSpeed;

      if (p.x < -0.05) p.x = 1.05;
      if (p.x > 1.05) p.x = -0.05;

      if (s.direction == _Direction.up && p.y < -0.05) {
        _particles[i] = _make(offscreenY: true);
      } else if (s.direction == _Direction.down && p.y > 1.05) {
        _particles[i] = _make()..y = -0.05;
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
    return IgnorePointer(
      child: CustomPaint(
        painter: _StageParticlePainter(
          particles: _particles,
          style: _style,
          time: _controller.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

enum _Direction { up, down }

enum _Shape { circle, oval, line }

class _StageStyle {
  final Color primary;
  final Color secondary;
  final _Shape shape;
  final _Direction direction;
  final double minSize;
  final double maxSize;
  final double baseSpeedY; // Per-tick movement
  final double varSpeedY;
  final double driftXAmplitude;
  final double swayAmplitude;
  final double rotationSpeed;
  final double minOpacity;
  final double flickerMin;
  final double flickerVar;
  final double glowSize;
  final bool hasTrail;

  const _StageStyle({
    required this.primary,
    required this.secondary,
    required this.shape,
    required this.direction,
    required this.minSize,
    required this.maxSize,
    required this.baseSpeedY,
    required this.varSpeedY,
    required this.driftXAmplitude,
    required this.swayAmplitude,
    required this.rotationSpeed,
    required this.minOpacity,
    required this.flickerMin,
    required this.flickerVar,
    required this.glowSize,
    this.hasTrail = false,
  });
}

_StageStyle _styleFor(UserTitle t) {
  switch (t) {
    case UserTitle.warrior:
      // Rising embers — fast, chaotic, warm orange/red, glowing trails
      return const _StageStyle(
        primary: Color(0xFFFF6B35),
        secondary: Color(0xFFC75050),
        shape: _Shape.circle,
        direction: _Direction.up,
        minSize: 0.8,
        maxSize: 2.5,
        baseSpeedY: -0.0018,
        varSpeedY: -0.0018,
        driftXAmplitude: 0.0015,
        swayAmplitude: 0.5,
        rotationSpeed: 0,
        minOpacity: 0.3,
        flickerMin: 1.5,
        flickerVar: 3.0,
        glowSize: 3.0,
        hasTrail: true,
      );
    case UserTitle.wanderer:
      // Golden dust motes — slow, gentle, soft amber, sparse glow
      return const _StageStyle(
        primary: Color(0xFFD4A853),
        secondary: Color(0xFFE8C87A),
        shape: _Shape.circle,
        direction: _Direction.up,
        minSize: 0.6,
        maxSize: 1.8,
        baseSpeedY: -0.0004,
        varSpeedY: -0.0006,
        driftXAmplitude: 0.0008,
        swayAmplitude: 0.7,
        rotationSpeed: 0,
        minOpacity: 0.2,
        flickerMin: 0.4,
        flickerVar: 0.8,
        glowSize: 2.5,
      );
    case UserTitle.seeker:
      // Bioluminescent — slow upward pulse, teal glow, peaceful
      return const _StageStyle(
        primary: Color(0xFF5BBFBA),
        secondary: Color(0xFF8FE3DE),
        shape: _Shape.circle,
        direction: _Direction.up,
        minSize: 0.8,
        maxSize: 2.2,
        baseSpeedY: -0.0007,
        varSpeedY: -0.0005,
        driftXAmplitude: 0.0006,
        swayAmplitude: 0.4,
        rotationSpeed: 0,
        minOpacity: 0.35,
        flickerMin: 0.6,
        flickerVar: 1.0,
        glowSize: 4.0,
      );
    case UserTitle.peacemaker:
      // Petals/pollen — gentle drift down, rotate, soft green/cream
      return const _StageStyle(
        primary: Color(0xFFA8D5B4),
        secondary: Color(0xFFE8E0D0),
        shape: _Shape.oval,
        direction: _Direction.down,
        minSize: 1.2,
        maxSize: 3.0,
        baseSpeedY: 0.0006,
        varSpeedY: 0.0008,
        driftXAmplitude: 0.0012,
        swayAmplitude: 1.2,
        rotationSpeed: 0.012,
        minOpacity: 0.3,
        flickerMin: 0.3,
        flickerVar: 0.5,
        glowSize: 2.0,
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
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.flickerSpeed,
    required this.flickerOffset,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _StageParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final _StageStyle style;
  final double time;

  _StageParticlePainter({
    required this.particles,
    required this.style,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final flicker =
          (sin(time * pi * 2 * p.flickerSpeed + p.flickerOffset) + 1) / 2;
      final fade = _edgeFade(p.y);
      final alpha = (p.opacity * (0.4 + flicker * 0.6) * fade).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;

      final pos = Offset(p.x * size.width, p.y * size.height);
      final color = Color.lerp(style.primary, style.secondary, flicker)!;

      // Glow halo
      final glow = Paint()
        ..color = color.withValues(alpha: alpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * style.glowSize);
      canvas.drawCircle(pos, p.size * style.glowSize, glow);

      // Trail (warrior embers only)
      if (style.hasTrail) {
        final trail = Paint()
          ..color = color.withValues(alpha: alpha * 0.4)
          ..strokeWidth = p.size * 0.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          pos,
          Offset(pos.dx - p.speedX * 800, pos.dy - p.speedY * 800),
          trail,
        );
      }

      // Core shape
      final core = Paint()..color = color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotation);
      switch (style.shape) {
        case _Shape.circle:
          canvas.drawCircle(Offset.zero, p.size, core);
          break;
        case _Shape.oval:
          // Petal-like oval
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: p.size * 2.4, height: p.size),
            core,
          );
          break;
        case _Shape.line:
          canvas.drawLine(
              Offset(-p.size, 0), Offset(p.size, 0), Paint()..color = color);
          break;
      }
      canvas.restore();
    }
  }

  double _edgeFade(double y) {
    if (y < 0.04) return (y / 0.04).clamp(0.0, 1.0);
    if (y > 0.96) return ((1.0 - y) / 0.04).clamp(0.0, 1.0);
    return 1.0;
  }

  @override
  bool shouldRepaint(_StageParticlePainter oldDelegate) => true;
}

extension UserTitleParticles on UserTitle {
  Color get particleColor {
    switch (this) {
      case UserTitle.warrior:
        return AppColors.war;
      case UserTitle.wanderer:
        return AppColors.primary;
      case UserTitle.seeker:
        return AppColors.accent;
      case UserTitle.peacemaker:
        return AppColors.peace;
    }
  }
}
