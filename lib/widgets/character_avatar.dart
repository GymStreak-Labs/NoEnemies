import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// A simple character visualization that evolves based on title.
/// Uses CustomPainter for a warrior-to-peacemaker silhouette.
class CharacterAvatar extends StatelessWidget {
  final UserTitle title;
  final double size;
  final bool showGlow;

  const CharacterAvatar({
    super.key,
    required this.title,
    this.size = 120,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CharacterPainter(
          title: title,
          showGlow: showGlow,
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final UserTitle title;
  final bool showGlow;

  _CharacterPainter({required this.title, required this.showGlow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background glow
    if (showGlow) {
      final glowColor = _glowColor;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.3),
            glowColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius),
        );
      canvas.drawCircle(center, radius, glowPaint);
    }

    // Inner circle
    final circlePaint = Paint()
      ..color = _backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.7, circlePaint);

    // Border ring
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.7, borderPaint);

    // Character icon (simplified silhouette)
    _drawCharacter(canvas, size, center, radius);
  }

  void _drawCharacter(
      Canvas canvas, Size size, Offset center, double radius) {
    final iconPaint = Paint()
      ..color = _iconColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final headRadius = radius * 0.15;
    final headCenter = Offset(center.dx, center.dy - radius * 0.22);

    // Head
    canvas.drawCircle(headCenter, headRadius, iconPaint);

    // Body
    final bodyPath = Path();
    bodyPath.moveTo(center.dx, headCenter.dy + headRadius);
    bodyPath.lineTo(center.dx, center.dy + radius * 0.15);
    canvas.drawPath(bodyPath, strokePaint);

    // Arms
    switch (title) {
      case UserTitle.warrior:
        // Arms raised in fists (fighting stance)
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx - radius * 0.25, center.dy - radius * 0.2),
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx + radius * 0.25, center.dy - radius * 0.2),
          strokePaint,
        );
        // Sword line (right hand)
        final swordPaint = Paint()
          ..color = AppColors.war.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(center.dx + radius * 0.25, center.dy - radius * 0.2),
          Offset(center.dx + radius * 0.35, center.dy - radius * 0.4),
          swordPaint,
        );
        break;

      case UserTitle.wanderer:
        // Arms slightly down, walking posture
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx - radius * 0.22, center.dy + radius * 0.1),
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx + radius * 0.22, center.dy + radius * 0.1),
          strokePaint,
        );
        break;

      case UserTitle.seeker:
        // Arms open, receptive
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx - radius * 0.28, center.dy - radius * 0.05),
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx + radius * 0.28, center.dy - radius * 0.05),
          strokePaint,
        );
        break;

      case UserTitle.peacemaker:
        // Arms wide open, embracing
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.15),
          strokePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - radius * 0.05),
          Offset(center.dx + radius * 0.3, center.dy - radius * 0.15),
          strokePaint,
        );
        // Peace glow around figure
        final peacePaint = Paint()
          ..color = AppColors.peace.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius * 0.5, peacePaint);
        break;
    }

    // Legs
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.15),
      Offset(center.dx - radius * 0.15, center.dy + radius * 0.38),
      strokePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.15),
      Offset(center.dx + radius * 0.15, center.dy + radius * 0.38),
      strokePaint,
    );
  }

  Color get _glowColor {
    switch (title) {
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

  Color get _backgroundColor {
    switch (title) {
      case UserTitle.warrior:
        return AppColors.war.withValues(alpha: 0.15);
      case UserTitle.wanderer:
        return AppColors.primary.withValues(alpha: 0.1);
      case UserTitle.seeker:
        return AppColors.accent.withValues(alpha: 0.1);
      case UserTitle.peacemaker:
        return AppColors.peace.withValues(alpha: 0.1);
    }
  }

  Color get _borderColor {
    switch (title) {
      case UserTitle.warrior:
        return AppColors.war.withValues(alpha: 0.4);
      case UserTitle.wanderer:
        return AppColors.primary.withValues(alpha: 0.4);
      case UserTitle.seeker:
        return AppColors.accent.withValues(alpha: 0.4);
      case UserTitle.peacemaker:
        return AppColors.peace.withValues(alpha: 0.4);
    }
  }

  Color get _iconColor {
    switch (title) {
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

  @override
  bool shouldRepaint(_CharacterPainter oldDelegate) =>
      oldDelegate.title != title || oldDelegate.showGlow != showGlow;
}
