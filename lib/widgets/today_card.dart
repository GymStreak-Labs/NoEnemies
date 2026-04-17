import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class TodayCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isCompleted;
  final String? heroTag;

  const TodayCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.onTap,
    this.isCompleted = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.peace.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCompleted
                  ? AppColors.peace.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.peace.withValues(alpha: 0.15)
                      : accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.peace.withValues(alpha: 0.3)
                        : accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isCompleted ? AppColors.peace : accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isCompleted
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isCompleted)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textTertiary,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );

    final wrapped = GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: heroTag != null
          ? Hero(
              tag: heroTag!,
              flightShuttleBuilder: (_, __, ___, ____, _____) => card,
              child: Material(type: MaterialType.transparency, child: card),
            )
          : card,
    );

    return wrapped.animate().fadeIn(duration: 400.ms).slideX(begin: 0.03, end: 0);
  }
}
