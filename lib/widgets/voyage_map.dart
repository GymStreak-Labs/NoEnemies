import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A parchment-style voyage map showing the user's journey from Warrior to
/// Peacemaker. A winding route is drawn across an aged map; a Viking longship
/// rests at the user's current day position; milestone landmarks (wheat sheaf,
/// dragon prow, peace tree) sit at the 7/30/90 day thresholds.
class VoyageMap extends StatefulWidget {
  /// Total days since the user started their journey (Day 1 = 0).
  final int daysSinceStart;

  /// Total peace days accumulated. Drives footprint visuals.
  final int totalPeaceDays;

  const VoyageMap({
    super.key,
    required this.daysSinceStart,
    required this.totalPeaceDays,
  });

  @override
  State<VoyageMap> createState() => _VoyageMapState();
}

class _VoyageMapState extends State<VoyageMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shipController;

  @override
  void initState() {
    super.initState();
    _shipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 11, // Slightly taller than parchment for content room
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Parchment background
              Image.asset(
                'assets/images/voyage/parchment.png',
                fit: BoxFit.cover,
              ),

              // Slight darkening to make overlays pop
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),

              // The voyage path + milestones + ship — drawn via CustomPaint
              // for the curve, with widget-based overlays for the assets.
              LayoutBuilder(
                builder: (context, constraints) {
                  return _VoyageContent(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    daysSinceStart: widget.daysSinceStart,
                    totalPeaceDays: widget.totalPeaceDays,
                    shipBob: _shipController,
                  );
                },
              ),

              // Bottom legend
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day ${widget.daysSinceStart + 1}',
                      style: const TextStyle(
                        color: Color(0xFF5C3A1E),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${widget.totalPeaceDays} peace days',
                      style: const TextStyle(
                        color: Color(0xFF5C3A1E),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoyageContent extends StatelessWidget {
  final double width;
  final double height;
  final int daysSinceStart;
  final int totalPeaceDays;
  final Animation<double> shipBob;

  const _VoyageContent({
    required this.width,
    required this.height,
    required this.daysSinceStart,
    required this.totalPeaceDays,
    required this.shipBob,
  });

  static const _milestoneDays = [7, 30, 90]; // Wanderer, Seeker, Peacemaker
  static const _maxJourneyDays = 90.0;

  Offset _positionForDay(double day) {
    // Map day 0 → leftmost; day 90 → rightmost.
    // Curve gently across the canvas (sine wave) for an organic route.
    final pad = 30.0;
    final usableW = width - (pad * 2);
    final t = (day / _maxJourneyDays).clamp(0.0, 1.0);
    final x = pad + (usableW * t);
    // Sine wave centered at canvas center, gentle amplitude
    final centerY = height * 0.5;
    final amplitude = height * 0.18;
    final y = centerY + amplitude * math.sin(t * math.pi * 2.4);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final shipPos = _positionForDay(daysSinceStart.toDouble());
    final shipSize = math.min(width * 0.18, 80.0);
    final milestoneSize = math.min(width * 0.10, 44.0);

    return Stack(
      children: [
        // Path + footprints — painted via CustomPainter
        CustomPaint(
          size: Size(width, height),
          painter: _VoyagePathPainter(
            daysSinceStart: daysSinceStart,
            totalPeaceDays: totalPeaceDays,
            positionForDay: _positionForDay,
          ),
        ),

        // Milestones (wheat sheaf, dragon prow, peace tree)
        for (int i = 0; i < _milestoneDays.length; i++)
          _milestoneAt(i, milestoneSize),

        // Ship — bobs gently up and down along its position
        AnimatedBuilder(
          animation: shipBob,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(shipBob.value);
            final dy = -2.0 + (t * 4.0);
            return Positioned(
              left: shipPos.dx - shipSize / 2,
              top: shipPos.dy - shipSize / 2 + dy,
              child: SizedBox(
                width: shipSize,
                height: shipSize,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/images/voyage/ship.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _milestoneAt(int index, double size) {
    final day = _milestoneDays[index];
    final pos = _positionForDay(day.toDouble());
    final reached = daysSinceStart >= day;
    final asset = switch (index) {
      0 => 'assets/images/voyage/milestone_wanderer.png',
      1 => 'assets/images/voyage/milestone_seeker.png',
      _ => 'assets/images/voyage/milestone_peacemaker.png',
    };
    final dayLabel = switch (index) {
      0 => '7d',
      1 => '30d',
      _ => '90d',
    };

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: reached ? 1.0 : 0.45,
            child: ColorFiltered(
              colorFilter: reached
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.5, 0.5, 0.5, 0, 30,
                      0.5, 0.5, 0.5, 0, 30,
                      0.5, 0.5, 0.5, 0, 30,
                      0, 0, 0, 1, 0,
                    ]),
              child: SizedBox(
                width: size,
                height: size,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayLabel,
            style: TextStyle(
              color: const Color(0xFF5C3A1E)
                  .withValues(alpha: reached ? 1.0 : 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoyagePathPainter extends CustomPainter {
  final int daysSinceStart;
  final int totalPeaceDays;
  final Offset Function(double day) positionForDay;

  _VoyagePathPainter({
    required this.daysSinceStart,
    required this.totalPeaceDays,
    required this.positionForDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build the full route (90 days) as a smooth path for the dotted line
    final fullPath = Path();
    final steps = 90;
    for (int i = 0; i <= steps; i++) {
      final p = positionForDay(i.toDouble());
      if (i == 0) {
        fullPath.moveTo(p.dx, p.dy);
      } else {
        fullPath.lineTo(p.dx, p.dy);
      }
    }

    // Faint dotted future path (whole journey)
    final futurePaint = Paint()
      ..color = const Color(0xFF5C3A1E).withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, fullPath, futurePaint, dashWidth: 4, dashGap: 4);

    // Solid traversed portion (Day 0 → daysSinceStart)
    if (daysSinceStart > 0) {
      final traversedPath = Path();
      for (int i = 0; i <= daysSinceStart; i++) {
        final p = positionForDay(i.toDouble());
        if (i == 0) {
          traversedPath.moveTo(p.dx, p.dy);
        } else {
          traversedPath.lineTo(p.dx, p.dy);
        }
      }
      final traversedPaint = Paint()
        ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(traversedPath, traversedPaint);
    }

    // Footprints / day marks for each peace day completed
    final footprintPaint = Paint()
      ..color = AppColors.peace.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final daysToMark = math.min(daysSinceStart, totalPeaceDays);
    for (int i = 1; i <= daysToMark; i++) {
      final p = positionForDay(i.toDouble());
      // Tiny perpendicular offset to make each "step" feel like a footprint
      final isLeft = i % 2 == 0;
      final dx = isLeft ? -3.5 : 3.5;
      final dy = isLeft ? -2 : 2;
      canvas.drawCircle(Offset(p.dx + dx, p.dy + dy), 1.8, footprintPaint);
    }

    // Compass rose stays in the parchment image — no need to draw one
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashGap,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_VoyagePathPainter oldDelegate) =>
      oldDelegate.daysSinceStart != daysSinceStart ||
      oldDelegate.totalPeaceDays != totalPeaceDays;
}
