import 'dart:math' as math;

import 'package:fbr_tax_helper/core/widgets/filer_flow_logo.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/session_router.dart';
import 'package:fbr_tax_helper/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Colors (unchanged theme)
const _kDeep = Color(0xFF092B29);
const _kGold = Color(0xFFFFC857);
const _kMint = Color(0xFF4DDBC4);
const _kGreen = Color(0xFF0F6B57);
const _kNavy = Color(0xFF183A5A);

// Spacing scale
const double _gapS = 8;
const double _gapM = 12;
const double _gapL = 20;

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SignupBloc(authService: context.read<AuthService>()),
      child: const SignupForm(),
    );
  }
}

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _captchaFieldKey = GlobalKey<FormFieldState<String>>();

  late final AnimationController _animationController;
  late _ArithmeticChallenge _captcha;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _captcha = _ArithmeticChallenge.generate();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _submitSignup() {
    final valid = _formKey.currentState!.validate();
    if (!valid) {
      // Wrong captcha answer -> give a fresh question
      final typed = _captchaController.text.trim();
      if (typed.isNotEmpty && _validateCaptcha(typed) != null) {
        _refreshCaptcha();
      }
      return;
    }

    context.read<SignupBloc>().add(
      SignUpButtonPressed(
        name: _nameController.text.trim(),
        contactNumber: '00000000000',
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _submitGoogleSignup() {
    if (!(_captchaFieldKey.currentState?.validate() ?? false)) {
      if (_captchaController.text.trim().isNotEmpty) _refreshCaptcha();
      return;
    }
    context.read<SignupBloc>().add(const SignUpWithGooglePressed());
  }

  void _refreshCaptcha() {
    setState(() {
      _captcha = _ArithmeticChallenge.generate();
      _captchaController.clear();
      _captchaFieldKey.currentState?.reset();
    });
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().length < 2) return 'Enter your name';
    return null;
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
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Add at least one number';
    if (RegExp(r'\s').hasMatch(password)) {
      return 'Password cannot contain spaces';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Add at least one special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  String? _validateCaptcha(String? value) {
    final answer = int.tryParse((value ?? '').trim());
    if (answer == null) return 'Enter the answer';
    if (answer != _captcha.answer) return 'Incorrect answer. Try again.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return BlocListener<SignupBloc, SignupState>(
      listener: (context, state) {
        if (state is SignupFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Sign up failed: ${state.error}')),
            );
        }
        if (state is SignupSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Account created successfully.')),
            );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SessionRouter()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: _SignupBackdropPainter(_animationController.value),
              child: child,
            );
          },
          child: SafeArea(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: _SignupBackgroundContent()),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final hPad = width < 360 ? 12.0 : 20.0;
                      final topPad = canPop ? 56.0 : 16.0;
                      const bottomPad = 20.0;
                      final minHeight = math.max(
                        0.0,
                        height - topPad - bottomPad,
                      );

                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          topPad,
                          hPad,
                          bottomPad,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _SignupPanel(
                                compact: height < 720 || width < 340,
                                asCard: width >= 600,
                                formKey: _formKey,
                                nameController: _nameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                captchaController: _captchaController,
                                captchaFieldKey: _captchaFieldKey,
                                captchaQuestion: _captcha.question,
                                obscurePassword: _obscurePassword,
                                obscureConfirmPassword: _obscureConfirmPassword,
                                onTogglePassword: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onToggleConfirmPassword: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                onSignup: _submitSignup,
                                onGoogleSignup: _submitGoogleSignup,
                                onRefreshCaptcha: _refreshCaptcha,
                                validateName: _validateName,
                                validateEmail: _validateEmail,
                                validatePassword: _validatePassword,
                                validateConfirmPassword:
                                    _validateConfirmPassword,
                                validateCaptcha: _validateCaptcha,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (canPop)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: _kDeep.withValues(alpha: 0.78),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
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

class _SignupPanel extends StatelessWidget {
  const _SignupPanel({
    required this.compact,
    required this.asCard,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.captchaController,
    required this.captchaFieldKey,
    required this.captchaQuestion,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSignup,
    required this.onGoogleSignup,
    required this.onRefreshCaptcha,
    required this.validateName,
    required this.validateEmail,
    required this.validatePassword,
    required this.validateConfirmPassword,
    required this.validateCaptcha,
  });

  final bool compact;
  final bool asCard;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController captchaController;
  final GlobalKey<FormFieldState<String>> captchaFieldKey;
  final String captchaQuestion;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSignup;
  final VoidCallback onGoogleSignup;
  final VoidCallback onRefreshCaptcha;
  final String? Function(String?) validateName;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;
  final String? Function(String?) validateConfirmPassword;
  final String? Function(String?) validateCaptcha;

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Color? iconColor,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      errorStyle: const TextStyle(color: Colors.black, height: 1.2),
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.96),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
    );
  }

  Widget _visibilityButton({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }

  Widget _passwordHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kDeep.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.security_outlined, color: _kGold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use 8+ characters with uppercase, lowercase, number and special character.',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _captchaCard(bool isLoading) {
    final question = Container(
      height: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kGold, _kMint]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.functions_rounded, color: _kNavy, size: 20),
            const SizedBox(width: 6),
            Text(
              '$captchaQuestion = ?',
              style: const TextStyle(
                color: _kDeep,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );

    final answer = TextFormField(
      key: captchaFieldKey,
      controller: captchaController,
      enabled: !isLoading,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textInputAction: TextInputAction.done,
      validator: validateCaptcha,
      onFieldSubmitted: (_) {
        if (!isLoading) onSignup();
      },
      decoration: _inputDecoration(
        hint: 'Answer',
        icon: Icons.calculate_outlined,
        iconColor: _kGreen,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(_gapM),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGreen, _kNavy],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kMint.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _kDeep.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: _kDeep, size: 19),
              ),
              const SizedBox(width: _gapS),
              const Expanded(
                child: Text(
                  'Security check',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _kMint.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'New question',
                  visualDensity: VisualDensity.compact,
                  onPressed: isLoading ? null : onRefreshCaptcha,
                  icon: const Icon(Icons.refresh_rounded, color: _kMint),
                ),
              ),
            ],
          ),
          const SizedBox(height: _gapS),
          LayoutBuilder(
            builder: (context, c) {
              // Very narrow: stack question above answer
              if (c.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [question, const SizedBox(height: _gapS), answer],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: question),
                  const SizedBox(width: _gapS),
                  Expanded(flex: 5, child: answer),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SignupBloc, SignupState>(
      builder: (context, state) {
        final isLoading = state is SignupLoading;

        final content = Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- Header ----
              Center(child: FilerFlowLogo(size: compact ? 84 : 104)),
              SizedBox(height: compact ? _gapS : _gapM),
              Text(
                'Filer Flow',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 32 : 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Start managing your finances with confidence.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              SizedBox(height: compact ? _gapM : _gapL),

              // ---- Fields ----
              TextFormField(
                controller: nameController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: validateName,
                decoration: _inputDecoration(
                  hint: 'Full name',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: _gapM),
              TextFormField(
                controller: emailController,
                enabled: !isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
                decoration: _inputDecoration(
                  hint: 'Email address',
                  icon: Icons.mail_outline,
                ),
              ),
              const SizedBox(height: _gapM),
              TextFormField(
                controller: passwordController,
                enabled: !isLoading,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                validator: validatePassword,
                decoration: _inputDecoration(
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: _visibilityButton(
                    obscured: obscurePassword,
                    onPressed: onTogglePassword,
                  ),
                ),
              ),
              const SizedBox(height: _gapS),
              _passwordHint(),
              const SizedBox(height: _gapM),
              TextFormField(
                controller: confirmPasswordController,
                enabled: !isLoading,
                obscureText: obscureConfirmPassword,
                textInputAction: TextInputAction.next,
                validator: validateConfirmPassword,
                decoration: _inputDecoration(
                  hint: 'Confirm password',
                  icon: Icons.verified_user_outlined,
                  suffixIcon: _visibilityButton(
                    obscured: obscureConfirmPassword,
                    onPressed: onToggleConfirmPassword,
                  ),
                ),
              ),
              const SizedBox(height: _gapL),

              // ---- Security check ----
              _captchaCard(isLoading),
              const SizedBox(height: _gapL),

              // ---- Actions ----
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: _kDeep,
                    elevation: 3,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : onSignup,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: const Text('Create account'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: _gapM),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.white.withValues(alpha: 0.3)),
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
                      child: Divider(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _kNavy,
                    side: BorderSide.none,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : onGoogleSignup,
                  icon: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: _kNavy.withValues(alpha: 0.2)),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  label: const Text('Continue with Google'),
                ),
              ),
              const SizedBox(height: _gapM),
              Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: BoxDecoration(
                  color: _kDeep.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _kGold,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (!asCard) return content;

        // Tablet / desktop / web: frame the form so it doesn't float
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _kDeep.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: content,
        );
      },
    );
  }
}

class _ArithmeticChallenge {
  const _ArithmeticChallenge({required this.question, required this.answer});

  final String question;
  final int answer;

  factory _ArithmeticChallenge.generate() {
    final random = math.Random.secure();
    switch (random.nextInt(4)) {
      case 0:
        final first = random.nextInt(20) + 1;
        final second = random.nextInt(20) + 1;
        return _ArithmeticChallenge(
          question: '$first + $second',
          answer: first + second,
        );
      case 1:
        final first = random.nextInt(20) + 1;
        final second = random.nextInt(first) + 1;
        return _ArithmeticChallenge(
          question: '$first - $second',
          answer: first - second,
        );
      case 2:
        final first = random.nextInt(11) + 2;
        final second = random.nextInt(11) + 2;
        return _ArithmeticChallenge(
          question: '$first * $second',
          answer: first * second,
        );
      default:
        final divisor = random.nextInt(11) + 2;
        final answer = random.nextInt(11) + 2;
        return _ArithmeticChallenge(
          question: '${divisor * answer} / $divisor',
          answer: answer,
        );
    }
  }
}

class _SignupBackgroundContent extends StatelessWidget {
  const _SignupBackgroundContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showLabels = width >= 700;
        // Side text only when there is real room beside the 440px form
        final showSideText = width >= 1100;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: showLabels ? 54 : 16,
              right: showLabels ? 54 : -22,
              child: Transform.rotate(
                angle: 0.08,
                child: _SignupBackgroundBadge(
                  icon: Icons.receipt_long_outlined,
                  label: showLabels ? 'Organized records' : null,
                ),
              ),
            ),
            Positioned(
              bottom: showLabels ? 58 : 20,
              left: showLabels ? 58 : -22,
              child: Transform.rotate(
                angle: -0.08,
                child: _SignupBackgroundBadge(
                  icon: Icons.calculate_outlined,
                  label: showLabels ? 'Tax made simple' : null,
                ),
              ),
            ),
            if (showSideText)
              Positioned(
                left: 64,
                top: constraints.maxHeight * 0.31,
                width: 250,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insights_rounded, color: _kGold, size: 42),
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

class _SignupBackgroundBadge extends StatelessWidget {
  const _SignupBackgroundBadge({required this.icon, this.label});

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

class _SignupBackdropPainter extends CustomPainter {
  const _SignupBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00695C), Color(0xFF0F6B57), Color(0xFF183A5A)],
      ).createShader(rect);
    final deepPaint = Paint()..color = _kDeep;
    final goldPaint = Paint()..color = _kGold;
    final lightPaint = Paint()..color = _kMint;

    canvas.drawRect(rect, basePaint);

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

    final lightPath = Path()
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
    canvas.drawPath(lightPath, lightPaint);

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
    canvas.drawPath(cornerPath, deepPaint);

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
  bool shouldRepaint(covariant _SignupBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}