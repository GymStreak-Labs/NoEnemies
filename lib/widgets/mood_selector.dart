import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/check_in.dart';
import '../theme/app_colors.dart';

class MoodSelector extends StatelessWidget {
  final Mood? selectedMood;
  final ValueChanged<Mood> onMoodSelected;

  const MoodSelector({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: Mood.values.map((mood) {
            final isSelected = selectedMood == mood;
            return GestureDetector(
              onTap: () => onMoodSelected(mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      mood.emoji,
                      style: TextStyle(
                        fontSize: isSelected ? 32 : 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mood.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(
                  delay: (Mood.values.indexOf(mood) * 80).ms,
                  duration: 300.ms,
                );
          }).toList(),
        ),
      ],
    );
  }
}
