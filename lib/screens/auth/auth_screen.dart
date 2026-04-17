import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';

/// Auth screen shown after paywall. Social auth prioritized, email expandable.
///
/// Phase 1A: real Firebase Auth for Apple, Google, and Email.
/// Phase 1B will insert profile load/create logic between sign-in and routing.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();

  bool _showEmailForm = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  AuthService get _authService => context.read<AuthService>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToJourney() {
    if (mounted) {
      // Phase 1B will hook profile load/create here before routing.
      context.go('/journey');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'sign-in-cancelled':
        case 'canceled':
          return 'Sign-in cancelled.';
        case 'user-not-found':
          return 'No account with that email. Try signing up instead.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'network-request-failed':
          return 'Network issue. Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _signInWithApple() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithApple();
      _navigateToJourney();
    } catch (e) {
      debugPrint('[AuthScreen] Apple sign-in failed: $e');
      _showError(_friendlyError(e));
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithGoogle();
      _navigateToJourney();
    } catch (e) {
      debugPrint('[AuthScreen] Google sign-in failed: $e');
      _showError(_friendlyError(e));
    }
  }

  void _toggleEmailForm() {
    HapticFeedback.lightImpact();
    setState(() => _showEmailForm = !_showEmailForm);

    if (_showEmailForm) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _submitEmail() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Try sign-in first; if the account doesn't exist, create it.
      try {
        await _authService.signInWithEmail(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'invalid-login-credentials') {
          await _authService.signUpWithEmail(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }
      _navigateToJourney();
    } catch (e) {
      debugPrint('[AuthScreen] Email auth failed: $e');
      _showError(_friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Radial background glow
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 1.2,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.04),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),

              // Ambient particles
              const Positioned.fill(
                child: AmbientParticles(
                  particleCount: 10,
                  color: AppColors.primary,
                  opacity: 0.15,
                  maxParticleSize: 2.0,
                  minParticleSize: 0.5,
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    children: [
                      _buildHero(),
                      const SizedBox(height: 24),
                      _buildTitle(),
                      const SizedBox(height: 32),
                      _buildAuthButtons(),
                      _buildEmailForm(),
                      _buildError(),
                      const SizedBox(height: 20),
                      _buildTerms(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Loading overlay — blocks interaction while signing in.
              if (_isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Hero Image ---

  Widget _buildHero() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing glow
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.1),
            duration: const Duration(milliseconds: 2400),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.primary.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          // Warrior image
          Image.asset(
            'assets/images/characters/warrior.png',
            height: 160,
            cacheWidth: 320,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 50,
                  color: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 600.ms);
  }

  // --- Title + Subtitle ---

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFE8C87A),
              Color(0xFFD4A853),
              Color(0xFFF0D78C),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: const Text(
            'ENTER YOUR JOURNEY',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to save your progress',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ).animate(delay: 200.ms).fadeIn(duration: 500.ms);
  }

  // --- Auth Buttons ---

  Widget _buildAuthButtons() {
    return Column(
      children: [
        // Apple button -- white filled
        _AuthButton(
          icon: Icons.apple,
          label: 'Continue with Apple',
          backgroundColor: Colors.white,
          textColor: Colors.black,
          onTap: _signInWithApple,
        ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(
              begin: 0.05,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 12),

        // Google button -- frosted glass with subtle border
        _AuthButton(
          icon: Icons.g_mobiledata,
          label: 'Continue with Google',
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          textColor: Colors.white,
          borderColor: Colors.white.withValues(alpha: 0.2),
          onTap: _signInWithGoogle,
        ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(
              begin: 0.05,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 12),

        // Email button -- frosted glass with primary border
        _AuthButton(
          icon: Icons.email_outlined,
          label: 'Continue with Email',
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          textColor: AppColors.primary,
          borderColor: AppColors.primary.withValues(alpha: 0.25),
          onTap: _toggleEmailForm,
          trailing: AnimatedRotation(
            turns: _showEmailForm ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ).animate(delay: 600.ms).fadeIn(duration: 400.ms).slideY(
              begin: 0.05,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  // --- Expandable Email Form ---

  Widget _buildEmailForm() {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            _buildTextField(
              controller: _emailController,
              hint: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outlined,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitEmail(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.primary.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            const SizedBox(height: 16),
            // Sign Up golden gradient button
            GestureDetector(
              onTap: _submitEmail,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A853), Color(0xFFE8C87A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0E1A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggleEmailForm,
              child: Text(
                'Back to options',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
      crossFadeState: _showEmailForm
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeOutCubic,
      secondCurve: Curves.easeOutCubic,
      sizeCurve: Curves.easeOutCubic,
    );
  }

  // --- Text Field ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // --- Error Display ---

  Widget _buildError() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: _errorMessage != null
          ? Padding(
              key: ValueKey(_errorMessage),
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.war.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.war.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.war,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.war,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no-error')),
    );
  }

  // --- Terms ---

  Widget _buildTerms() {
    return Text(
      'By continuing, you agree to our Terms & Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textTertiary,
      ),
    ).animate(delay: 700.ms).fadeIn(duration: 400.ms);
  }
}

// ============================================================
// Custom Auth Button
// ============================================================

class _AuthButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _AuthButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.onTap,
    this.trailing,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              HapticFeedback.mediumImpact();
              widget.onTap?.call();
            },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!)
                  : null,
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: widget.backgroundColor == Colors.white
                            ? Colors.white.withValues(alpha: 0.08)
                            : widget.textColor.withValues(alpha: 0.06),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 22, color: widget.textColor),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 6),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
