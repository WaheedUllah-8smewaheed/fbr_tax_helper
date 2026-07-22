import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr/qr.dart';

class TwoFactorAuthPage extends StatefulWidget {
  const TwoFactorAuthPage({
    super.key,
    this.requiredEnrollment = false,
    this.onEnrollmentChanged,
  });

  final bool requiredEnrollment;
  final VoidCallback? onEnrollmentChanged;

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  final _codeController = TextEditingController();
  List<MultiFactorInfo> _factors = const [];
  TotpEnrollmentData? _enrollment;
  bool _isLoading = true;
  bool _isWorking = false;
  late bool _emailVerified;
  String? _error;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    _emailVerified = _authService.currentUser?.emailVerified ?? false;
    _loadFactors();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadFactors() async {
    if (!_authService.supportsTotpMfa) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final factors = await _authService.getEnrolledTotpFactors();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _isLoading = false;
        _error = null;
      });
      if (factors.isEmpty && _emailVerified) {
        await _startEnrollment();
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      TotpEnrollmentData enrollment;
      try {
        enrollment = await _authService.startTotpEnrollment();
      } on RecentLoginRequiredException {
        await _reauthenticateForEnrollment();
        enrollment = await _authService.startTotpEnrollment();
      }
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _isWorking = false;
      });
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = error.message;
      });
    }
  }

  Future<void> _reauthenticateForEnrollment() async {
    final user = _authService.currentUser;
    final usesGoogle =
        user?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;
    if (usesGoogle) {
      await _authService.reauthenticateCurrentUserWithGoogle();
      return;
    }

    if (!mounted) {
      throw const AuthServiceException('Authenticator setup was cancelled.');
    }
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConfirmEnrollmentPasswordDialog(),
    );
    if (password == null) {
      throw const AuthServiceException('Authenticator setup was cancelled.');
    }
    await _authService.reauthenticateCurrentUserWithPassword(password);
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await _authService.sendCurrentUserEmailVerification();
      if (!mounted) return;
      setState(() => _isWorking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = error.message;
      });
    }
  }

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      final verified = await _authService.refreshCurrentUserEmailVerification();
      if (!mounted) return;
      setState(() {
        _emailVerified = verified;
        _isWorking = false;
        if (!verified) {
          _error = 'Email is not verified yet. Open the link, then try again.';
        }
      });
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = error.message;
      });
    }
  }

  Future<void> _completeEnrollment() async {
    final enrollment = _enrollment;
    if (enrollment == null || _codeController.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your app.');
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await _authService.completeTotpEnrollment(
        enrollment,
        _codeController.text,
      );
      _codeController.clear();
      _enrollment = null;
      await _loadFactors();
      widget.onEnrollmentChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authenticator app enabled.')),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = error.message;
      });
    }
  }

  Future<void> _disableFactor(MultiFactorInfo factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset authenticator app?'),
        content: const Text(
          'The current authenticator will be removed and you will be signed out. Two-factor setup will be required again at your next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      await _authService.disableTotp(factor);
      await _authService.signOut();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.requiredEnrollment,
        title: const Text('Two-factor authentication'),
        actions: widget.requiredEnrollment
            ? [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => _authService.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.requiredEnrollment)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Two-factor authentication is required before you can access your account.',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Icon(Icons.security, size: 64, color: Colors.teal),
                const SizedBox(height: 12),
                Text(
                  'Protect your account with an authenticator app',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use Google Authenticator, Microsoft Authenticator, Authy, 1Password, or another TOTP-compatible app.',
                  textAlign: TextAlign.center,
                ),
                if (!_authService.supportsTotpMfa) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Authenticator-app MFA is supported by Firebase on Android, iOS, and web. It is not available in this Windows/macOS build.',
                      ),
                    ),
                  ),
                ] else if (!_emailVerified) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Verify your email first',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Firebase requires a verified email before an authenticator app can be enrolled. Check ${_authService.currentUser?.email ?? 'your inbox'}.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _isWorking
                                ? null
                                : _sendVerificationEmail,
                            child: const Text('Send verification email'),
                          ),
                          FilledButton(
                            onPressed: _isWorking
                                ? null
                                : _checkEmailVerification,
                            child: const Text("I've verified my email"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_factors.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.verified_user,
                        color: Colors.green,
                      ),
                      title: const Text('Authenticator app enabled'),
                      subtitle: Text(
                        _factors.first.displayName ?? 'Authenticator app',
                      ),
                      trailing: widget.requiredEnrollment
                          ? null
                          : TextButton(
                              onPressed: _isWorking
                                  ? null
                                  : () => _disableFactor(_factors.first),
                              child: const Text('Reset'),
                            ),
                    ),
                  ),
                ] else if (_enrollment == null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _startEnrollment,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Set up authenticator app'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const Text(
                    '1. Scan this QR code with your authenticator app.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Center(child: _TotpQrCode(data: _enrollment!.qrCodeUrl)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isWorking
                        ? null
                        : () => _authService.openTotpEnrollmentInAuthenticator(
                            _enrollment!,
                          ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open authenticator app'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Or enter this setup key manually:'),
                  const SizedBox(height: 6),
                  SelectableText(
                    _enrollment!.secretKey,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _enrollment!.secretKey),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Setup key copied.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy setup key'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '2. Enter the current 6-digit code.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    enabled: !_isWorking,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onSubmitted: (_) => _completeEnrollment(),
                    decoration: const InputDecoration(
                      labelText: '6-digit code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _completeEnrollment,
                    icon: const Icon(Icons.check),
                    label: const Text('Verify and enable'),
                  ),
                ],
                if (_isWorking) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ConfirmEnrollmentPasswordDialog extends StatefulWidget {
  const _ConfirmEnrollmentPasswordDialog();

  @override
  State<_ConfirmEnrollmentPasswordDialog> createState() =>
      _ConfirmEnrollmentPasswordDialogState();
}

class _ConfirmEnrollmentPasswordDialogState
    extends State<_ConfirmEnrollmentPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_passwordController.text.isEmpty) return;
    Navigator.of(context).pop(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_clock_outlined),
      title: const Text('Confirm your sign-in'),
      content: TextField(
        controller: _passwordController,
        autofocus: true,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: 'Current password',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Confirm')),
      ],
    );
  }
}

class _TotpQrCode extends StatelessWidget {
  const _TotpQrCode({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    return Semantics(
      label: 'Authenticator setup QR code',
      image: true,
      child: Container(
        width: 232,
        height: 232,
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: CustomPaint(painter: _QrPainter(QrImage(code))),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / image.moduleCount;
    final cellHeight = size.height / image.moduleCount;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (!image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            column * cellWidth,
            row * cellHeight,
            cellWidth + 0.1,
            cellHeight + 0.1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
