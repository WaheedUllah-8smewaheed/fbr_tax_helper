import 'dart:math' as math;

import 'package:fbr_tax_helper/core/widgets/filer_flow_logo.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/public_calculator_screen.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/signup_page.dart';
import 'package:fbr_tax_helper/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(authService: context.read<AuthService>()),
      child: const LoginForm(),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _animationController;
  bool _obscurePassword = true;
  bool _isShowingTotpChallenge = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmailLogin() {
    if (!_formKey.currentState!.validate()) return;

    context.read<LoginBloc>().add(
      LoginWithEmailAndPasswordPressed(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  void _submitGoogleLogin() {
    context.read<LoginBloc>().add(const LoginWithGooglePressed());
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _showTotpChallenge(TotpSignInChallenge challenge) async {
    if (_isShowingTotpChallenge) return;
    _isShowingTotpChallenge = true;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _TotpSignInDialog(
        authService: context.read<AuthService>(),
        challenge: challenge,
      ),
    );
    _isShowingTotpChallenge = false;
    if (!mounted || verified != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Login successful.')));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginTotpRequired) {
          _showTotpChallenge(state.challenge);
        }
        if (state is LoginFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Login failed: ${state.error}')),
            );
        }
        if (state is LoginSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Login successful.')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: _LoginBackdropPainter(_animationController.value),
              child: child,
            );
          },
          child: SafeArea(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: _LoginBackgroundContent()),
                ),
                if (canPop)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          canPop ? 64 : 16,
                          16,
                          16,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 460,
                              child: _LoginPanel(
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                obscurePassword: _obscurePassword,
                                onTogglePassword: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                onEmailLogin: _submitEmailLogin,
                                onGoogleLogin: _submitGoogleLogin,
                                onCreateAccount: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const SignupPage(),
                                    ),
                                  );
                                },
                                onTaxCalculator: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PublicCalculatorScreen(),
                                    ),
                                  );
                                },
                                validateEmail: _validateEmail,
                                validatePassword: _validatePassword,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotpSignInDialog extends StatefulWidget {
  const _TotpSignInDialog({required this.authService, required this.challenge});

  final AuthService authService;
  final TotpSignInChallenge challenge;

  @override
  State<_TotpSignInDialog> createState() => _TotpSignInDialogState();
}

class _TotpSignInDialogState extends State<_TotpSignInDialog> {
  final _codeController = TextEditingController();
  String? _error;
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.length != 6 || _isVerifying) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await widget.authService.resolveTotpSignIn(
        widget.challenge,
        _codeController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.phonelink_lock_outlined),
      title: const Text('Two-factor authentication'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the current code from your authenticator app.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              enabled: !_isVerifying,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                labelText: '6-digit code',
                errorText: _error,
                errorStyle: const TextStyle(color: Colors.black),
                border: const OutlineInputBorder(),
                errorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _verify,
          child: _isVerifying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onEmailLogin,
    required this.onGoogleLogin,
    required this.onCreateAccount,
    required this.onTaxCalculator,
    required this.validateEmail,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onEmailLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onCreateAccount;
  final VoidCallback onTaxCalculator;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final isLoading = state is LoginLoading;

        return Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 24,
            right: 24,
            left: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(child: FilerFlowLogo(size: 120)),

                const SizedBox(height: 20),

                Text(
                  'Filer Flow',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in to manage your finances with confidence.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    // Change Color
                    errorStyle: const TextStyle(color: Colors.black),
                    prefixIcon: const Icon(Icons.alternate_email),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.96),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  validator: validatePassword,
                  onFieldSubmitted: (_) {
                    if (!isLoading) onEmailLogin();
                  },
                  decoration: InputDecoration(
                    hintText: 'Password',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    // errorStyle: TextStyle(color: Colors.red), // Default error color
                    errorStyle: const TextStyle(color: Colors.black),
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.96),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: isLoading ? null : onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF083B1F),
                      foregroundColor: const Color(
                        0xFFD1EBE1,
                      ), // Clean white for text & icons
                      elevation: 2,
                      shadowColor: const Color(0xFF083B1F).withValues(
                        alpha: 0.3,
                      ), // Natural shadow matching button
                      side: BorderSide(
                        color: Colors.white.withValues(
                          alpha: 0.2,
                        ), // Subtle light border
                        width: 1,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight
                            .w600, // Reduced from w800 for cleaner typography
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : onEmailLogin,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text('Sign in'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF183A5A),
                      side: BorderSide.none,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : onGoogleLogin,
                    icon: Container(
                      width: 25,
                      height: 25,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF183A5A).withValues(alpha: 0.2),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF092B29).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New to Filer Flow?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFC857),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: isLoading ? null : onCreateAccount,
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF092B29,
                      ).withValues(alpha: 0.82),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isLoading ? null : onTaxCalculator,
                    icon: const Icon(
                      Icons.calculate_outlined,
                      color: Color(0xFFFFC857),
                    ),
                    label: const Text('Open Tax Calculator'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoginBackgroundContent extends StatelessWidget {
  const _LoginBackgroundContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: isWide ? 54 : 20,
              right: isWide ? 54 : -18,
              child: Transform.rotate(
                angle: 0.08,
                child: _BackgroundBadge(
                  icon: Icons.receipt_long_outlined,
                  label: isWide ? 'Organized records' : null,
                ),
              ),
            ),
            Positioned(
              bottom: isWide ? 58 : 26,
              left: isWide ? 58 : -14,
              child: Transform.rotate(
                angle: -0.08,
                child: _BackgroundBadge(
                  icon: Icons.calculate_outlined,
                  label: isWide ? 'Tax made simple' : null,
                ),
              ),
            ),
            if (isWide)
              Positioned(
                left: 64,
                top: constraints.maxHeight * 0.31,
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFFFFC857),
                      size: 42,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'A clearer view of\nyour financial life.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Track income, expenses and tax information in one secure place.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BackgroundBadge extends StatelessWidget {
  const _BackgroundBadge({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(label == null ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: label == null ? 0.1 : 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 28),
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginBackdropPainter extends CustomPainter {
  const _LoginBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00695C), Color(0xFF0F6B57), Color(0xFF183A5A)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final goldPaint = Paint()..color = const Color(0xFFFFC857);
    final mintPaint = Paint()..color = const Color(0xFF4DDBC4);
    final inkPaint = Paint()..color = const Color(0xFF092B29);

    final wave = math.sin(progress * 2 * math.pi) * size.height * 0.025;

    final goldPath = Path()
      ..moveTo(0, size.height * 0.60 + wave)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.49 - wave,
        size.width,
        size.height * 0.55 + wave,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(goldPath, goldPaint);

    final mintPath = Path()
      ..moveTo(0, size.height * 0.86 - wave)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.76 + wave,
        size.width,
        size.height * 0.82 - wave,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mintPath, mintPaint);

    final cornerPath = Path()
      ..moveTo(size.width * 0.72, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.25 + wave,
        size.width * 0.72,
        0,
      )
      ..close();
    canvas.drawPath(cornerPath, inkPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var index = 0; index < 7; index++) {
      final y = size.height * (0.12 + index * 0.085) + wave;
      canvas.drawLine(
        Offset(size.width * 0.05, y),
        Offset(size.width * 0.48, y + math.sin(index + progress * 6) * 10),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoginBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
