import 'package:fbr_tax_helper/features/auth/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/login_page.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:fbr_tax_helper/services/biometric_lock_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionRouter extends StatelessWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listens to native Firebase authentication session changes
      stream: context.read<AuthService>().authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase is reading the local device token key on startup
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If a valid user session token is found on the device hardware
        if (snapshot.hasData && snapshot.data != null) {
          if (kIsWeb) {
            return const DashboardScreen();
          }
          return _BiometricSessionGate(user: snapshot.data!);
        }

        // Signed-out users authenticate before opening account features.
        return const LoginPage();
      },
    );
  }
}

class _BiometricSessionGate extends StatefulWidget {
  const _BiometricSessionGate({required this.user});

  final User user;

  @override
  State<_BiometricSessionGate> createState() => _BiometricSessionGateState();
}

class _BiometricSessionGateState extends State<_BiometricSessionGate>
    with WidgetsBindingObserver {
  final _biometricLock = BiometricLockService();
  bool _isLoading = true;
  bool _isEnabled = false;
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  bool _wentToBackground = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockState();
  }

  @override
  void didUpdateWidget(covariant _BiometricSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _loadLockState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentToBackground = true;
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _wentToBackground &&
        !_isAuthenticating) {
      _wentToBackground = false;
      _refreshLockAfterResume();
    }
  }

  Future<void> _refreshLockAfterResume() async {
    // Allow an enable/disable authentication prompt to finish persisting the
    // setting before deciding whether the returning app should be locked.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      final enabled = await _biometricLock.isEnabled(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _isEnabled = enabled;
        _isUnlocked = !enabled;
      });
      if (enabled) await _unlock();
    } on BiometricLockException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _loadLockState() async {
    try {
      final enabled = await _biometricLock.isEnabled(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _isEnabled = enabled;
        _isUnlocked = !enabled;
        _isLoading = false;
        _error = null;
      });
      if (enabled) await _unlock();
    } on BiometricLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEnabled = true;
        _isUnlocked = false;
        _error = error.message;
      });
    }
  }

  Future<void> _unlock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });
    try {
      final unlocked = await _biometricLock.unlock();
      if (!mounted) return;
      setState(() {
        _isUnlocked = unlocked;
        _isAuthenticating = false;
        _wentToBackground = false;
        if (!unlocked) _error = 'Authentication was cancelled.';
      });
    } on BiometricLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isEnabled || _isUnlocked) return const DashboardScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filer Flow locked'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 88, color: Colors.teal),
                const SizedBox(height: 16),
                Text(
                  'Unlock your account',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your fingerprint, Face ID, or device screen lock.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isAuthenticating ? null : _unlock,
                  icon: _isAuthenticating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
