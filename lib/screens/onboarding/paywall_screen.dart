import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isAnnual = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Atmospheric background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.3,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Subtle particles
          const Positioned.fill(
            child: AmbientParticles(
              particleCount: 15,
              color: AppColors.primary,
              opacity: 0.2,
              maxParticleSize: 2.0,
              minParticleSize: 0.5,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Close button (MVP only)
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => context.go('/journey'),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textTertiary.withValues(alpha: 0.6),
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Header — premium, not salesy
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFE8C87A),
                        Color(0xFFD4A853),
                        Color(0xFFF0D78C),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      'Begin Your\nPeace Journey',
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                height: 1.15,
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 12),

                  Text(
                    'Everything you need to end the inner war',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                  const SizedBox(height: 36),

                  // Features — premium styled
                  ..._features.asMap().entries.map((entry) {
                    return _FeatureRow(
                      icon: entry.value.$1,
                      title: entry.value.$2,
                      subtitle: entry.value.$3,
                    ).animate().fadeIn(
                          delay: (300 + entry.key * 100).ms,
                          duration: 400.ms,
                        ).slideX(
                          begin: 0.03,
                          end: 0,
                          delay: (300 + entry.key * 100).ms,
                          duration: 400.ms,
                        );
                  }),

                  const SizedBox(height: 36),

                  // Plan selector — premium cards
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          title: 'Weekly',
                          price: '\$4.99',
                          period: '/week',
                          isSelected: !_isAnnual,
                          onTap: () => setState(() => _isAnnual = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          title: 'Annual',
                          price: '\$59.99',
                          period: '/year',
                          isSelected: _isAnnual,
                          onTap: () => setState(() => _isAnnual = true),
                          badge: 'SAVE 77%',
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 800.ms, duration: 500.ms),

                  const SizedBox(height: 10),

                  if (_isAnnual)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.peace.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'That\'s just \$1.15/week',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.peace,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 28),

                  // Subscribe button — golden gradient
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFD4A853),
                            Color(0xFFE8C87A),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // MVP: skip to app
                          context.go('/journey');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isAnnual
                              ? 'Start Annual Plan'
                              : 'Start Weekly Plan',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1000.ms, duration: 500.ms),

                  const SizedBox(height: 14),

                  Text(
                    'Cancel anytime. No commitment.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Legal links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Terms',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Text(
                        '\u00B7',
                        style: TextStyle(
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.5)),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Privacy',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Text(
                        '\u00B7',
                        style: TextStyle(
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.5)),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Restore',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (
      Icons.psychology_outlined,
      'AI-Powered Mentor',
      'Personalised prompts that learn your patterns',
    ),
    (
      Icons.map_outlined,
      'Voyage Map',
      'Visual journey of your transformation',
    ),
    (
      Icons.auto_stories_outlined,
      'Daily Reflections',
      'Morning & evening check-ins tailored to you',
    ),
    (
      Icons.insights_outlined,
      'Weekly Insights',
      'Pattern detection & progress reports',
    ),
    (
      Icons.groups_outlined,
      'Crew Matching',
      'Connect with 5-8 people on the same journey',
    ),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.peace.withValues(alpha: 0.7),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.peace.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.peace.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peace,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: price,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: period,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
