import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class PeaceStreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int totalDaysOfPeace;

  const PeaceStreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysOfPeace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Days of Peace',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: '$currentStreak',
                  label: 'Current\nStreak',
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _StatColumn(
                  value: '$longestStreak',
                  label: 'Longest\nStreak',
                  color: AppColors.accent,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _StatColumn(
                  value: '$totalDaysOfPeace',
                  label: 'Total\nPeaceful',
                  color: AppColors.peace,
                ),
              ),
            ],
          ),
          if (currentStreak > 0) ...[
            const SizedBox(height: 14),
            Text(
              _getStreakMessage(currentStreak),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  String _getStreakMessage(int streak) {
    if (streak >= 30) {
      return 'A month of peace. You\'re becoming who you were meant to be.';
    } else if (streak >= 14) {
      return 'Two weeks strong. The warrior is becoming the wanderer.';
    } else if (streak >= 7) {
      return 'A full week of peace. You\'re building something real.';
    } else if (streak >= 3) {
      return 'Three days and counting. Momentum is on your side.';
    }
    return 'Every day of peace is a victory.';
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.3,
              ),
        ),
      ],
    );
  }
}
