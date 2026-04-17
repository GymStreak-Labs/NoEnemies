import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DimensionSlider extends StatelessWidget {
  final String label;
  final String lowLabel;
  final String highLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const DimensionSlider({
    super.key,
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: Color.lerp(
              AppColors.war,
              AppColors.peace,
              value,
            ),
            inactiveTrackColor: AppColors.surfaceBorder,
            thumbColor: Color.lerp(
              AppColors.war,
              AppColors.peace,
              value,
            ),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
            ),
            overlayColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lowLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.war.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
              ),
              Text(
                highLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.peace.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
