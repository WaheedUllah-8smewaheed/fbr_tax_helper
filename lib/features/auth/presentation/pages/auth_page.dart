import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../services/auth_service.dart';
import '../../../tax_calculator/presentation/screens/tax_calculator_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _toggleMode() async {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await widget.authService.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRegisterMode
                ? 'Account created successfully.'
                : 'Signed in successfully.',
          ),
        ),
      );
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));
      _navigateToCalculator();
    } catch (error) {
      setState(() {
        _errorMessage = error is AuthServiceException
            ? error.message
            : 'Authentication failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithGoogle(requestDriveAccess: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in with Google.')));
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));
      _navigateToCalculator();
    } catch (error) {
      setState(() {
        _errorMessage = error is AuthServiceException
            ? error.message
            : 'Google sign in failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out successfully.')));
      setState(() {});
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to sign out. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter an email address';
    }
    if (!trimmed.contains('@')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Account'),
            actions: [
              if (user != null)
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAnimatedHeader(context),
                  const SizedBox(height: 24),
                  if (user != null) ...[
                    _AccountCard(user: user),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ] else ...[
                    _buildAuthForm(context),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _toggleMode,
                      child: Text(
                        _isRegisterMode
                            ? 'Already have an account? Sign in'
                            : 'Create a new account',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => TaxCalculatorScreen(
                              authService: widget.authService,
                            ),
                          ),
                        );
                      },
                      child: const Text('Calculate your TAX'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToCalculator() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            TaxCalculatorScreen(authService: widget.authService),
      ),
    );
  }

  Widget _buildAnimatedHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 250,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final progress = _animationController.value;
              final incomeShift = math.sin(progress * 2 * math.pi) * 10;
              final expenseShift = math.cos(progress * 2 * math.pi) * 10;

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F6B57), Color(0xFF3AB795)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.12),
                          blurRadius: 20,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 28,
                    top: 32 + incomeShift,
                    child: _buildStatChip(
                      label: 'Income',
                      value: '+ 8.2k',
                      color: Colors.green.shade300,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  Positioned(
                    right: 28,
                    top: 32 + expenseShift,
                    child: _buildStatChip(
                      label: 'Expense',
                      value: '- 4.6k',
                      color: Colors.red.shade300,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  Positioned(
                    left: 48,
                    bottom: 38,
                    child: _buildBar(0.72, progress * 8),
                  ),
                  Positioned(
                    left: 120,
                    bottom: 26,
                    child: _buildBar(0.54, progress * 10),
                  ),
                  Positioned(
                    right: 80,
                    bottom: 30,
                    child: _buildBar(0.34, progress * 6),
                  ),
                  Positioned(
                    bottom: 20,
                    child: Row(
                      children: const [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white70,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Income vs Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to FilerFlow',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Track income and expenses, sign in, create a new account, or continue with tax calculator only.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.fromARGB((0.18 * 255).round(), red, green, blue),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color.fromARGB((0.35 * 255).round(), red, green, blue),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor, double shift) {
    return Transform.translate(
      offset: Offset(0, math.sin(shift) * 10),
      child: Container(
        width: 16,
        height: 120 * heightFactor,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.92),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegisterMode ? 'Create account' : 'Sign in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            validator: _validatePassword,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(_isRegisterMode ? 'Create account' : 'Sign in'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Signed in',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.email ?? 'Signed in user',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (user.displayName != null) Text('Name: ${user.displayName!}'),
          ],
        ),
      ),
    );
  }
}
