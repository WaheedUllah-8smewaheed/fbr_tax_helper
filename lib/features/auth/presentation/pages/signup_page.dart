import 'dart:math' as math;

import 'package:fbr_tax_helper/core/widgets/filer_flow_logo.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/session_router.dart';
import 'package:fbr_tax_helper/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _contactController = TextEditingController(text: '03');
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
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _submitSignup() {
    if (!_formKey.currentState!.validate()) return;

    context.read<SignupBloc>().add(
      SignUpButtonPressed(
        name: _nameController.text.trim(),
        contactNumber: _contactController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _submitGoogleSignup() {
    if (!(_captchaFieldKey.currentState?.validate() ?? false)) return;
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
    if ((value ?? '').trim().length < 2) {
      return 'Enter your name';
    }
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

  String? _validateContact(String? value) {
    final contact = (value ?? '').trim();
    if (!RegExp(r'^03\d{9}$').hasMatch(contact)) {
      return 'Enter exactly 11 digits starting with 03';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'Use at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Add at least one number';
    }
    if (RegExp(r'\s').hasMatch(password)) {
      return 'Password cannot contain spaces';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Add at least one special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
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
                if (canPop)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF092B29,
                        ).withValues(alpha: 0.78),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final topPadding = canPop ? 64.0 : 24.0;
                    final bottomPadding =
                        24.0 + MediaQuery.viewInsetsOf(context).bottom;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        topPadding,
                        16,
                        bottomPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            constraints.maxHeight - topPadding - bottomPadding,
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 460,
                            child: _SignupPanel(
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              contactController: _contactController,
                              passwordController: _passwordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                              captchaController: _captchaController,
                              captchaFieldKey: _captchaFieldKey,
                              captchaQuestion: _captcha.question,
                              obscurePassword: _obscurePassword,
                              obscureConfirmPassword: _obscureConfirmPassword,
                              onTogglePassword: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onToggleConfirmPassword: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              onSignup: _submitSignup,
                              onGoogleSignup: _submitGoogleSignup,
                              onRefreshCaptcha: _refreshCaptcha,
                              validateName: _validateName,
                              validateEmail: _validateEmail,
                              validateContact: _validateContact,
                              validatePassword: _validatePassword,
                              validateConfirmPassword: _validateConfirmPassword,
                              validateCaptcha: _validateCaptcha,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.contactController,
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
    required this.validateContact,
    required this.validatePassword,
    required this.validateConfirmPassword,
    required this.validateCaptcha,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController contactController;
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
  final String? Function(String?) validateContact;
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
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.96),
      border: border,
      enabledBorder: border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SignupBloc, SignupState>(
      builder: (context, state) {
        final isLoading = state is SignupLoading;

        return Padding(
          padding: const EdgeInsets.only(
            top: 8,
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
                const SizedBox(height: 15),
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
                const SizedBox(height: 10),
                Text(
                  'Create your account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start managing your finances with confidence.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: validateName,
                  decoration: _inputDecoration(
                    hint: 'Full name',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: _inputDecoration(
                    hint: 'Email address',
                    icon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: contactController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  textInputAction: TextInputAction.next,
                  validator: validateContact,
                  decoration: _inputDecoration(
                    hint: 'Contact number',
                    icon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF092B29).withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security_outlined,
                        color: Color(0xFFFFC857),
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Use 8+ characters with uppercase, lowercase, number and special character.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  enabled: !isLoading,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: validatePassword,
                  decoration: _inputDecoration(
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPasswordController,
                  enabled: !isLoading,
                  obscureText: obscureConfirmPassword,
                  textInputAction: TextInputAction.next,
                  validator: validateConfirmPassword,
                  decoration: _inputDecoration(
                    hint: 'Confirm password',
                    icon: Icons.verified_user_outlined,
                    suffixIcon: IconButton(
                      tooltip: obscureConfirmPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: onToggleConfirmPassword,
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F6B57), Color(0xFF183A5A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4DDBC4).withValues(alpha: 0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF092B29).withValues(alpha: 0.22),
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
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC857),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF092B29),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              color: const Color(
                                0xFF4DDBC4,
                              ).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'New question',
                              visualDensity: VisualDensity.compact,
                              onPressed: isLoading ? null : onRefreshCaptcha,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF4DDBC4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            constraints: const BoxConstraints(minWidth: 118),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFC857), Color(0xFF4DDBC4)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.functions_rounded,
                                  color: Color(0xFF183A5A),
                                  size: 20,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '$captchaQuestion = ?',
                                  style: const TextStyle(
                                    color: Color(0xFF092B29),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
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
                                iconColor: const Color(0xFF0F6B57),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC857),
                      foregroundColor: const Color(0xFF092B29),
                      elevation: 3,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
                    onPressed: isLoading ? null : onGoogleSignup,
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
                const SizedBox(height: 10),
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
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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
                          foregroundColor: const Color(0xFFFFC857),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
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
          ),
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
        final isWide = constraints.maxWidth >= 900;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: isWide ? 54 : 20,
              right: isWide ? 54 : -18,
              child: Transform.rotate(
                angle: 0.08,
                child: _SignupBackgroundBadge(
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
                child: _SignupBackgroundBadge(
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
    final deepPaint = Paint()..color = const Color(0xFF092B29);
    final goldPaint = Paint()..color = const Color(0xFFFFC857);
    final lightPaint = Paint()..color = const Color(0xFF4DDBC4);

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
