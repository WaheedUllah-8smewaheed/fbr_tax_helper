import 'dart:math' as math;

import 'package:fbr_tax_helper/features/auth/presentation/pages/session_router.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:fbr_tax_helper/services/signup_bloc.dart';
import 'package:flutter/material.dart';
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
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _animationController;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
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
    final digits = contact.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 720;

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
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SignupHeader(
                                  progress: _animationController.value,
                                ),
                                const SizedBox(height: 22),
                                _SignupPanel(
                                  formKey: _formKey,
                                  nameController: _nameController,
                                  emailController: _emailController,
                                  contactController: _contactController,
                                  passwordController: _passwordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  obscurePassword: _obscurePassword,
                                  obscureConfirmPassword:
                                      _obscureConfirmPassword,
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
                                  validateName: _validateName,
                                  validateEmail: _validateEmail,
                                  validateContact: _validateContact,
                                  validatePassword: _validatePassword,
                                  validateConfirmPassword:
                                      _validateConfirmPassword,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _SignupHeader(
                                    progress: _animationController.value,
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: _SignupPanel(
                                    formKey: _formKey,
                                    nameController: _nameController,
                                    emailController: _emailController,
                                    contactController: _contactController,
                                    passwordController: _passwordController,
                                    confirmPasswordController:
                                        _confirmPasswordController,
                                    obscurePassword: _obscurePassword,
                                    obscureConfirmPassword:
                                        _obscureConfirmPassword,
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
                                    validateName: _validateName,
                                    validateEmail: _validateEmail,
                                    validateContact: _validateContact,
                                    validatePassword: _validatePassword,
                                    validateConfirmPassword:
                                        _validateConfirmPassword,
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

class _SignupHeader extends StatelessWidget {
  const _SignupHeader({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lift = math.sin(progress * 2 * math.pi) * 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: Offset(0, lift),
          child: Container(
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
        ),
        const SizedBox(height: 28),
        Text(
          'Create account',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Keep your income, expenses, and tax records tied to your own secure profile.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFFE7F0EA),
            height: 1.45,
          ),
        ),
      ],
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
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSignup,
    required this.validateName,
    required this.validateEmail,
    required this.validateContact,
    required this.validatePassword,
    required this.validateConfirmPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController contactController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSignup;
  final String? Function(String?) validateName;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validateContact;
  final String? Function(String?) validatePassword;
  final String? Function(String?) validateConfirmPassword;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignupBloc, SignupState>(
      builder: (context, state) {
        final isLoading = state is SignupLoading;

        return Card(
          elevation: 18,
          color: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign up',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                    decoration: const InputDecoration(
                      labelText: 'User name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: contactController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: validateContact,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: validatePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPasswordController,
                    enabled: !isLoading,
                    obscureText: obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: validateConfirmPassword,
                    onFieldSubmitted: (_) {
                      if (!isLoading) onSignup();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
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
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: isLoading ? null : onSignup,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: const Text('Sign up'),
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

class _SignupBackdropPainter extends CustomPainter {
  const _SignupBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = const Color(0xFF0F6B57);
    final deepPaint = Paint()..color = const Color(0xFF093D35);
    final goldPaint = Paint()..color = const Color(0xFFE2A72E);
    final lightPaint = Paint()..color = const Color(0xFFF6F7F4);

    canvas.drawRect(Offset.zero & size, basePaint);

    final wave = math.sin(progress * 2 * math.pi) * size.height * 0.025;
    final deepPath = Path()
      ..moveTo(size.width * 0.68, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.46 + wave)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.34,
        size.width * 0.68,
        0,
      )
      ..close();
    canvas.drawPath(deepPath, deepPaint);

    final lightPath = Path()
      ..moveTo(0, size.height * 0.78 + wave)
      ..lineTo(size.width, size.height * 0.62 - wave)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lightPath, lightPaint);

    final goldPath = Path()
      ..moveTo(0, size.height * 0.72 + wave)
      ..lineTo(size.width, size.height * 0.56 - wave)
      ..lineTo(size.width, size.height * 0.62 - wave)
      ..lineTo(0, size.height * 0.78 + wave)
      ..close();
    canvas.drawPath(goldPath, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _SignupBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
