import 'dart:math' as math;

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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 560;

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
                if (Navigator.of(context).canPop())
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
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 32,
                      72,
                      isCompact ? 16 : 32,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AnimatedLoginHeader(
                                  progress: _animationController.value,
                                ),
                                const SizedBox(height: 22),
                                _LoginPanel(
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
                                        builder: (context) =>
                                            const SignupPage(),
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
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _AnimatedLoginHeader(
                                    progress: _animationController.value,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
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
                                          builder: (context) =>
                                              const SignupPage(),
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
                              ],
                            ),
                    ),
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
                border: const OutlineInputBorder(),
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

class _AnimatedLoginHeader extends StatelessWidget {
  const _AnimatedLoginHeader({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pulse = math.sin(progress * 2 * math.pi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFF00796B),
            size: 38,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Welcome back',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to keep your tax estimates, expenses, and Drive backup in sync.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 160,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 64,
                top: 18 + pulse * 4,
                child: const _FloatingStatCard(
                  icon: Icons.trending_up,
                  label: 'Income',
                  value: 'PKR 150k',
                  color: Color(0xFF40C4A3),
                ),
              ),
              Positioned(
                right: 0,
                top: 82 - pulse * 5,
                child: const _FloatingStatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Expense',
                  value: 'PKR 85k',
                  color: Color(0xFFFFC857),
                ),
              ),
              Positioned(
                left: 34,
                bottom: 0,
                child: Transform.rotate(
                  angle: -0.08 + pulse * 0.02,
                  child: const _TaxBadge(),
                ),
              ),
            ],
          ),
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

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 34,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF123D36),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your account dashboard is ready.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF65716C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
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
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
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
                      onPressed: isLoading ? null : onEmailLogin,
                      icon: isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onGoogleLogin,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Google accounts are already email-verified and can enable authenticator 2FA without an email link.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF65716C),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF65716C),
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : onCreateAccount,
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onTaxCalculator,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Tax Calculator'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingStatCard extends StatelessWidget {
  const _FloatingStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF65716C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF123D36),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaxBadge extends StatelessWidget {
  const _TaxBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF123D36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, color: Color(0xFFFFC857), size: 20),
          SizedBox(width: 8),
          Text(
            'Filer Flow',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
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
      ..moveTo(0, size.height * 0.74 + wave)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.61 - wave,
        size.width,
        size.height * 0.68 + wave,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(goldPath, goldPaint);

    final mintPath = Path()
      ..moveTo(0, size.height * 0.82 - wave)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.70 + wave,
        size.width,
        size.height * 0.78 - wave,
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
