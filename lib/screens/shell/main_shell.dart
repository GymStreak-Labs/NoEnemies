import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = <_TabSpec>[
    _TabSpec('/journey', Icons.explore_outlined, Icons.explore, 'Journey'),
    _TabSpec('/reflect', Icons.auto_stories_outlined, Icons.auto_stories, 'Reflect'),
    _TabSpec('/crew', Icons.groups_outlined, Icons.groups, 'Crew'),
    _TabSpec('/you', Icons.person_outline, Icons.person, 'You'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: child,
      bottomNavigationBar: _CinematicTabBar(
        currentIndex: index,
        tabs: _tabs,
        onTap: (i) {
          if (i == index) return;
          HapticFeedback.lightImpact();
          context.go(_tabs[i].route);
        },
      ),
    );
  }
}

class _TabSpec {
  final String route;
  final IconData iconOutlined;
  final IconData iconFilled;
  final String label;
  const _TabSpec(this.route, this.iconOutlined, this.iconFilled, this.label);
}

class _CinematicTabBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onTap;

  const _CinematicTabBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0B0D14),
            Colors.black.withValues(alpha: 0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 32,
            offset: const Offset(0, -10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amber gradient top accent line
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00D4A853),
                  Color(0x66D4A853),
                  Color(0x00D4A853),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 10,
              bottom: bottomInset > 0 ? bottomInset : 12,
              left: 8,
              right: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: _TabItem(
                    tab: tab,
                    isActive: isActive,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final _TabSpec tab;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: isActive ? 1 : 0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return SizedBox(
                    height: 36,
                    width: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Active radial glow backdrop
                        if (t > 0)
                          Opacity(
                            opacity: t,
                            child: Container(
                              width: 44 + (6 * t),
                              height: 28 + (4 * t),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.28),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Icon
                        Transform.scale(
                          scale: 1.0 + (0.08 * t),
                          child: _TabIcon(
                            iconData: isActive ? tab.iconFilled : tab.iconOutlined,
                            activeProgress: t,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              // Label with animated color
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: isActive ? 1 : 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                builder: (context, t, _) {
                  final color = Color.lerp(
                    AppColors.textTertiary.withValues(alpha: 0.75),
                    AppColors.primary,
                    t,
                  )!;
                  return Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.lerp(
                        FontWeight.w500,
                        FontWeight.w600,
                        t,
                      ),
                      color: color,
                      letterSpacing: 0.4 + (0.6 * t),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              // Active indicator pill
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: isActive ? 1 : 0),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return Container(
                    height: 2.5,
                    width: 18 * t,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE8C87A),
                          Color(0xFFD4A853),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55 * t),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  final IconData iconData;
  final double activeProgress;

  const _TabIcon({
    required this.iconData,
    required this.activeProgress,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(iconData, size: 24);

    if (activeProgress <= 0.01) {
      return Icon(
        iconData,
        size: 24,
        color: AppColors.textTertiary.withValues(alpha: 0.85),
      );
    }

    // Active: gold gradient shader mask
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          Color.lerp(
            AppColors.textTertiary.withValues(alpha: 0.85),
            const Color(0xFFE8C87A),
            activeProgress,
          )!,
          Color.lerp(
            AppColors.textTertiary.withValues(alpha: 0.85),
            const Color(0xFFD4A853),
            activeProgress,
          )!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: icon,
    );
  }
}
