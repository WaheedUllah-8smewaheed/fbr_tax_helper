import 'package:fbr_tax_helper/features/auth/domain/models/app_user.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TermsAgreementGate extends StatefulWidget {
  const TermsAgreementGate({
    required this.user,
    required this.child,
    super.key,
  });

  final AppUser user;
  final Widget child;

  @override
  State<TermsAgreementGate> createState() => _TermsAgreementGateState();
}

class _TermsAgreementGateState extends State<TermsAgreementGate> {
  static const _storage = FlutterSecureStorage();
  static const _termsVersion = '1';
  static const _brandGreen = Color(0xFF006B57);
  final _termsScrollController = ScrollController();

  bool _isLoading = true;
  bool _hasAccepted = false;
  bool _isChecked = false;
  bool _isSaving = false;
  String? _error;

  String get _acceptanceKey =>
      'terms_license_v${_termsVersion}_accepted_${widget.user.uid}';

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  @override
  void didUpdateWidget(covariant TermsAgreementGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      setState(() {
        _isLoading = true;
        _hasAccepted = false;
        _isChecked = false;
        _error = null;
      });
      _loadAcceptance();
    }
  }

  @override
  void dispose() {
    _termsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAcceptance() async {
    try {
      final accepted = await _storage.read(key: _acceptanceKey) == 'true';
      if (!mounted) return;
      setState(() {
        _hasAccepted = accepted;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not check your agreement status. Please try again.';
      });
    }
  }

  Future<void> _accept() async {
    if (!_isChecked || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _storage.write(key: _acceptanceKey, value: 'true');
      if (!mounted) return;
      setState(() {
        _hasAccepted = true;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not save your agreement. Please try again.';
      });
    }
  }

  Future<void> _decline() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AuthService>().signOut();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasAccepted) return widget.child;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380, maxHeight: 650),
              child: Material(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: _brandGreen,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Terms & license agreement',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please review before continuing to Filer Flow',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _termsScrollController,
                        thumbVisibility: true,
                        radius: const Radius.circular(10),
                        thickness: 8,
                        child: ListView(
                          controller: _termsScrollController,
                          padding: const EdgeInsets.fromLTRB(20, 18, 26, 16),
                          children: const [
                            _TermSection(
                              number: 1,
                              title: 'Acceptance of terms',
                              body:
                                  'By continuing, you agree to be bound by these terms of use for Filer Flow.',
                            ),
                            _TermSection(
                              number: 2,
                              title: 'Your data stays with you',
                              body:
                                  'All financial data is stored locally on your device. We have no access to your transactions or balances at any time.',
                            ),
                            _TermSection(
                              number: 3,
                              title: 'Optional Google Drive backup',
                              body:
                                  'Backups only occur when you request them, and are stored in your own Google Drive account.',
                            ),
                            _TermSection(
                              number: 4,
                              title: 'Tax calculator disclaimer',
                              body:
                                  'Tax estimates are informational only and not a substitute for professional advice.',
                            ),
                            _TermSection(
                              number: 5,
                              title: 'Account & security',
                              body:
                                  "Login is handled via Firebase Authentication and Google Sign-In. You're responsible for your credentials and any 2FA you enable.",
                              showDivider: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            value: _isChecked,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _brandGreen,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(
                                    () => _isChecked = value ?? false,
                                  ),
                            title: const Text(
                              'I have read and agree to the terms of service and license agreement',
                              style: TextStyle(fontSize: 13.5, height: 1.35),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 45,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _brandGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isChecked && !_isSaving
                                  ? _accept
                                  : null,
                              child: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Agree and continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(
                            height: 32,
                            child: TextButton(
                              onPressed: _isSaving ? null : _decline,
                              child: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  const _TermSection({
    required this.number,
    required this.title,
    required this.body,
    this.showDivider = true,
  });

  final int number;
  final String title;
  final String body;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $title',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: const Color(0xFF4B4B4B),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}
