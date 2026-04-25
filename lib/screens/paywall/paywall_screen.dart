import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/legal_urls.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

/// Standalone paywall screen shown after onboarding celebration.
/// Modeled after GymLevels' paywall with NoEnemies' dark anime aesthetic.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;

  bool _isAnnual = true;

  // Staggered entrance flags
  bool _showHero = false;
  bool _showPlans = false;
  bool _showBenefits = false;
  bool _showCta = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Staggered entrance timing
    Future.delayed(Duration.zero, () {
      if (mounted) setState(() => _showHero = true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showPlans = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showBenefits = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showCta = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subscriptions = context.read<SubscriptionService>();
      if (subscriptions.offerings == null &&
          !subscriptions.isLoadingOfferings) {
        subscriptions.loadOfferings();
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String _ctaText(SubscriptionService subscriptions) {
    if (_isAnnual) {
      return 'Start My Journey \u2014 ${subscriptions.annualPrice}/year';
    }
    return 'Start Free Trial \u2014 ${subscriptions.weeklyPrice}/week';
  }

  Future<void> _handleSubscribe() async {
    final subscriptions = context.read<SubscriptionService>();
    final package = subscriptions.packageForPlan(annual: _isAnnual);
    if (package == null) {
      _showSnackBar(
        subscriptions.isLoadingOfferings
            ? 'Plans are still loading. Try again in a moment.'
            : 'Plans are not available yet. Please try again shortly.',
      );
      if (!subscriptions.isLoadingOfferings) {
        await subscriptions.loadOfferings();
      }
      return;
    }

    debugPrint(
      '[PaywallScreen] Subscribe tapped: '
      '${_isAnnual ? "annual" : "weekly"} -> ${package.identifier} / '
      '${package.storeProduct.identifier}',
    );

    final result = await subscriptions.purchase(package);
    if (!mounted) return;

    if (result.success) {
      _showSnackBar('You are in. Welcome to the path.');
      context.go('/auth');
    } else if (!result.cancelled) {
      _showSnackBar(
        result.errorMessage ?? 'Purchase failed. Please try again.',
      );
    }
  }

  void _handleClose() {
    // Paywall close sends the user to /auth. They still have to sign in
    // before they can reach the app (Phase 1A: auth required for /journey).
    debugPrint('[PaywallScreen] Close tapped — routing to /auth');
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final subscriptions = context.watch<SubscriptionService>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background radial glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.2,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Ambient particles
            const Positioned.fill(
              child: AmbientParticles(
                particleCount: 12,
                color: AppColors.primary,
                opacity: 0.2,
                maxParticleSize: 2.0,
                minParticleSize: 0.5,
              ),
            ),

            // Scrollable content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildSpecialOfferBanner(subscriptions),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildPricingCards(subscriptions),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionDivider(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildBenefitShowcase(),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildQuickFeaturesRow(),
                  ),
                  const SizedBox(height: 28),
                  _buildSocialProof(),
                  const SizedBox(height: 24),
                  _buildFooter(),
                  // Clearance for fixed CTA
                  SizedBox(height: 100 + bottomPadding),
                ],
              ),
            ),

            // Close (X) button — top right
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: _handleClose,
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

            // Fixed bottom CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showCta ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: bottomPadding + 12,
                  ),
                  child: _buildCtaButton(subscriptions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // HERO SECTION
  // ===========================================================

  Widget _buildHeroSection() {
    return AnimatedOpacity(
      opacity: _showHero ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/intro/intro_title_art.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              cacheWidth: 828,
            ),
            // Gradient fade to black
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Headline overlay
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'BEGIN YOUR PEACE JOURNEY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 3,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock your full transformation',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // SPECIAL OFFER BANNER
  // ===========================================================

  Widget _buildSpecialOfferBanner(SubscriptionService subscriptions) {
    return AnimatedOpacity(
      opacity: _showPlans ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + _shimmerController.value * 3, 0),
                  end: Alignment(-1.0 + _shimmerController.value * 3 + 1, 0),
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    3,
                    (i) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          alpha: 0.6 - (i * 0.15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subscriptions.specialOfferTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subscriptions.specialOfferBadge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================
  // PRICING CARDS
  // ===========================================================

  Widget _buildPricingCards(SubscriptionService subscriptions) {
    final annualBreakdown = subscriptions.annualWeeklyBreakdown;
    final annualBadge = subscriptions.hasSpecialAnnualOffer
        ? 'SPECIAL'
        : 'SAVE 77%';
    final annualSubtitle = subscriptions.hasSpecialAnnualOffer
        ? 'Usually ${subscriptions.regularAnnualPrice}/year'
        : null;

    return AnimatedOpacity(
      opacity: _showPlans ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSlide(
        offset: _showPlans ? Offset.zero : const Offset(0, 0.03),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            // Annual plan (selected by default)
            _buildPlanCard(
              title: 'Annual',
              price: subscriptions.annualPrice,
              period: '/year',
              breakdown: annualBreakdown,
              isSelected: _isAnnual,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAnnual = true);
              },
              badge: annualBadge,
              subtitle: annualSubtitle,
              isAnnual: true,
            ),
            const SizedBox(height: 10),
            // Weekly plan
            _buildPlanCard(
              title: 'Weekly',
              price: subscriptions.weeklyPrice,
              period: '/week',
              breakdown: null,
              isSelected: !_isAnnual,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isAnnual = false);
              },
              subtitle: 'Try for a week',
              isAnnual: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isAnnual,
    String? breakdown,
    String? badge,
    String? subtitle,
  }) {
    final glowColor = isAnnual ? AppColors.primary : Colors.white24;
    final effectiveGlow = isSelected
        ? glowColor
        : glowColor.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? effectiveGlow.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && isAnnual
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Check indicator
              _buildCheckIndicator(
                isSelected,
                isAnnual ? AppColors.primary : Colors.white54,
              ),
              const SizedBox(width: 14),
              // Title + subtitle/breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isAnnual ? AppColors.primary : Colors.white)
                                : AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.peace.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.peace.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.peace,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (breakdown != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Just $breakdown',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? (isAnnual ? AppColors.primary : Colors.white)
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckIndicator(bool isSelected, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? color.withValues(alpha: 0.35) : Colors.transparent,
        border: Border.all(
          color: isSelected ? color : Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 13)
          : null,
    );
  }

  // ===========================================================
  // SECTION DIVIDER
  // ===========================================================

  Widget _buildSectionDivider() {
    return AnimatedOpacity(
      opacity: _showBenefits ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'WHAT YOU GET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.7),
                  letterSpacing: 3,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // BENEFIT SHOWCASE (6 features with frosted glass cards)
  // ===========================================================

  Widget _buildBenefitShowcase() {
    const benefits = [
      (
        Icons.psychology_outlined,
        'Personal Mentor',
        'Guidance that adapts to YOU \u2014 knows your triggers by month 3',
      ),
      (
        Icons.map_outlined,
        'Voyage Map',
        'Watch your transformation unfold day by day',
      ),
      (
        Icons.wb_sunny_outlined,
        'Daily Rituals',
        'Morning intention + evening reflection in 5 minutes',
      ),
      (
        Icons.insights_outlined,
        'Weekly Insights',
        'Personalized reports that show patterns you can\'t see alone',
      ),
      (
        Icons.people_outline,
        'Crews',
        'Small groups matched by conflict type (coming soon)',
      ),
      (
        Icons.auto_stories_outlined,
        'Book of Peace',
        'Your collected wisdom, shareable and permanent',
      ),
    ];

    return AnimatedOpacity(
      opacity: _showBenefits ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: Column(
        children: benefits.asMap().entries.map((entry) {
          final index = entry.key;
          final benefit = entry.value;
          return _BenefitCard(
                icon: benefit.$1,
                title: benefit.$2,
                subtitle: benefit.$3,
              )
              .animate()
              .fadeIn(delay: (200 * index).ms, duration: 400.ms)
              .slideX(
                begin: 0.05,
                end: 0,
                delay: (200 * index).ms,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              );
        }).toList(),
      ),
    );
  }

  // ===========================================================
  // QUICK FEATURES ROW
  // ===========================================================

  Widget _buildQuickFeaturesRow() {
    const features = [
      'Unlimited',
      'Ad-Free',
      'Cancel Anytime',
      'Privacy First',
    ];

    return AnimatedOpacity(
      opacity: _showBenefits ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: features.map((label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================
  // SOCIAL PROOF
  // ===========================================================

  Widget _buildSocialProof() {
    return AnimatedOpacity(
      opacity: _showBenefits ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Column(
        children: [
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                  size: 20,
                );
              }),
              const SizedBox(width: 8),
              Text(
                '4.9',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Join 12,847+ on the path to peace',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // FOOTER
  // ===========================================================

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => _openLegalUrl(LegalUrls.termsOfUse),
          child: Text(
            'Terms',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
        Text('\u00B7', style: TextStyle(color: AppColors.textTertiary)),
        TextButton(
          onPressed: () => _openLegalUrl(LegalUrls.privacyPolicy),
          child: Text(
            'Privacy',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
        Text('\u00B7', style: TextStyle(color: AppColors.textTertiary)),
        TextButton(
          onPressed: () async {
            HapticFeedback.selectionClick();
            debugPrint('[PaywallScreen] Restore tapped');
            final result = await context
                .read<SubscriptionService>()
                .restorePurchases();
            if (!mounted) return;
            if (result.success && result.isPremium) {
              _showSnackBar('Purchase restored. Welcome back.');
              context.go('/auth');
            } else if (result.success) {
              _showSnackBar('No active subscription found.');
            } else {
              _showSnackBar(
                result.errorMessage ?? 'Restore failed. Please try again.',
              );
            }
          },
          child: Text(
            'Restore',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  /// Open the hosted Privacy Policy or Terms of Use page in the user's
  /// default browser (external application — keeps our dark paywall context
  /// clean and honours platform conventions). Non-blocking: any failure is
  /// surfaced via a snackbar so we don't crash the paywall.
  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    } catch (e) {
      debugPrint('[PaywallScreen] _openLegalUrl failed for $url: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open the page')));
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF141925),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================
  // CTA BUTTON
  // ===========================================================

  Widget _buildCtaButton(SubscriptionService subscriptions) {
    final disabled = subscriptions.isPurchasing;
    return GestureDetector(
      onTap: disabled
          ? null
          : () async {
              HapticFeedback.mediumImpact();
              await _handleSubscribe();
            },
      child: AnimatedScale(
        scale: _showCta ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFD4A853), Color(0xFFE8C87A)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: subscriptions.isPurchasing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0A0E1A),
                    ),
                  )
                : Text(
                    _ctaText(subscriptions),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0E1A),
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BENEFIT CARD (frosted glass)
// ============================================================

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    height: 1.3,
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
