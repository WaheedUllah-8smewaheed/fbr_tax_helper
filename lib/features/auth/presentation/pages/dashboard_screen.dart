import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/screens/tax_calculator_screen.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/services/transaction_report_service.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:fbr_tax_helper/services/biometric_lock_service.dart';
import 'package:fbr_tax_helper/services/drive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late final CategoryPreferencesService _categoryPreferences;

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(const LoadTransactions());
    _categoryPreferences = CategoryPreferencesService();
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      _categoryPreferences.loadForUser(userId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBiometricReminderIfNeeded();
    });
  }

  Future<void> _showBiometricReminderIfNeeded() async {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    try {
      final biometricLock = BiometricLockService();
      if (!await biometricLock.isSupported()) return;
      final isEnabled = await biometricLock.isEnabled(userId);
      if (!mounted || isEnabled) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Fingerprint app lock is optional. You can enable it from your profile.',
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Profile',
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
          ),
        );
    } on BiometricLockException {
      // The optional reminder must never block dashboard access.
    }
  }

  @override
  void dispose() {
    _categoryPreferences.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _categoryPreferences,
        builder: (context, _) => IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeDashboard(categoryPreferences: _categoryPreferences),
            const TaxCalculatorScreen(),
            _CategorySettingsPage(categoryPreferences: _categoryPreferences),
            const _ProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _CategorySettingsPage extends StatelessWidget {
  const _CategorySettingsPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  Future<void> _updateCategory(
    BuildContext context,
    String categoryName,
    bool isExpense,
  ) async {
    try {
      await categoryPreferences.setExpenseClassification(
        categoryName,
        isExpense: isExpense,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: categoryPreferences.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Category classification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose whether each category belongs under Income or Expenses. Your dashboard totals, category sections, reports, and new transactions will follow these choices.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (categoryPreferences.loadError != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Saved category settings could not be loaded. Default classifications are currently shown.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...TransactionCategory.all.map((category) {
                  final isExpense = categoryPreferences.isExpense(
                    category.name,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getColorForCategory(
                                    category.name,
                                  ).withValues(alpha: 0.12),
                                  foregroundColor: _getColorForCategory(
                                    category.name,
                                  ),
                                  child: Icon(
                                    _getIconForCategory(category.name),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<bool>(
                              expandedInsets: EdgeInsets.zero,
                              segments: const [
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('Income'),
                                  icon: Icon(Icons.arrow_upward),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('Expense'),
                                  icon: Icon(Icons.arrow_downward),
                                ),
                              ],
                              selected: {isExpense},
                              onSelectionChanged: (selection) {
                                final newValue = selection.first;
                                if (newValue == isExpense) return;
                                _updateCategory(
                                  context,
                                  category.name,
                                  newValue,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage>
    with WidgetsBindingObserver {
  static const _profileStorage = FlutterSecureStorage();
  final _biometricLock = BiometricLockService();

  bool _isLoadingBiometric = true;
  bool _isBiometricEnabled = false;
  bool _isBiometricSupported = false;
  bool _isUpdatingProfile = false;
  bool _isPickingImage = false;
  String? _profileImagePath;
  String? _pendingEmailChange;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricStatus();
    _loadProfileImage();
    _loadPendingEmailChange();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAccount(showFeedback: false);
    }
  }

  String get _profileImageKey =>
      'profile_image_${_authService.currentUser?.uid ?? 'signed_out'}';

  String get _pendingEmailKey =>
      'pending_email_${_authService.currentUser?.uid ?? 'signed_out'}';

  bool _emailsMatch(String? first, String? second) {
    if (first == null || second == null) return false;
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  Future<void> _loadPendingEmailChange() async {
    final pendingEmail = await _profileStorage.read(key: _pendingEmailKey);
    if (pendingEmail == null) return;

    // Secure-storage loading and the app-resume refresh can finish in either
    // order. Reload before restoring the notice so an already-applied email
    // change is not shown as pending again.
    try {
      await _authService.reloadCurrentUser();
    } on AuthServiceException {
      // Keep the pending notice when Firebase cannot currently be reached.
    }
    final wasApplied = _emailsMatch(
      pendingEmail,
      _authService.currentUser?.email,
    );
    if (wasApplied) {
      await _profileStorage.delete(key: _pendingEmailKey);
    }
    if (!mounted) return;
    setState(() => _pendingEmailChange = wasApplied ? null : pendingEmail);
  }

  Future<void> _loadProfileImage() async {
    final storedPath = await _profileStorage.read(key: _profileImageKey);
    if (!mounted) return;
    setState(() {
      _profileImagePath = storedPath != null && File(storedPath).existsSync()
          ? storedPath
          : null;
    });
  }

  Future<void> _pickProfileImage() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null || _isPickingImage) return;

    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final supportDirectory = await getApplicationSupportDirectory();
      final imageDirectory = Directory(
        path.join(supportDirectory.path, 'profile_images'),
      );
      await imageDirectory.create(recursive: true);
      final extension = path.extension(picked.path).toLowerCase();
      final targetPath = path.join(
        imageDirectory.path,
        '$userId${extension.isEmpty ? '.jpg' : extension}',
      );
      await File(picked.path).copy(targetPath);
      await FileImage(File(targetPath)).evict();
      await _profileStorage.write(key: _profileImageKey, value: targetPath);

      if (!mounted) return;
      setState(() {
        _profileImagePath = targetPath;
        _isPickingImage = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile image: $error')),
      );
    }
  }

  Future<void> _loadBiometricStatus() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    try {
      final supported = await _biometricLock.isSupported();
      final enabled = await _biometricLock.isEnabled(userId);
      if (!mounted) return;
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
        _isLoadingBiometric = false;
      });
    } on BiometricLockException {
      if (mounted) setState(() => _isLoadingBiometric = false);
    }
  }

  Future<void> _toggleBiometricLock() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null || _isLoadingBiometric) return;
    setState(() => _isLoadingBiometric = true);
    try {
      if (_isBiometricEnabled) {
        await _biometricLock.disable(userId);
      } else {
        await _biometricLock.enable(userId);
      }
      if (!mounted) return;
      final enabled = !_isBiometricEnabled;
      setState(() {
        _isBiometricEnabled = enabled;
        _isLoadingBiometric = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Fingerprint app lock enabled.'
                : 'Fingerprint app lock disabled.',
          ),
        ),
      );
    } on BiometricLockException catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingBiometric = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _editProfile() async {
    final user = _authService.currentUser;
    if (user == null || _isUpdatingProfile) return;

    final update = await showDialog<_ProfileUpdate>(
      context: context,
      builder: (context) => _EditProfileDialog(
        initialName: user.displayName ?? '',
        initialEmail: user.email ?? '',
      ),
    );
    if (update == null || !mounted) return;

    setState(() => _isUpdatingProfile = true);
    try {
      final nameChanged = update.displayName != (user.displayName ?? '');
      final emailChanged = update.email != (user.email ?? '');
      if (nameChanged) {
        await _authService.updateCurrentUserDisplayName(update.displayName);
      }
      if (emailChanged) {
        await _requestEmailChangeWithReauthentication(update.email);
        _pendingEmailChange = update.email;
        await _profileStorage.write(key: _pendingEmailKey, value: update.email);
      }
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      if (emailChanged) {
        await _showEmailChangeLinkSent(update.email);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: ${error.message}')),
      );
    }
  }

  Future<void> _refreshAccount({bool showFeedback = true}) async {
    if (_isUpdatingProfile) return;
    setState(() => _isUpdatingProfile = true);
    try {
      final previousEmail = _authService.currentUser?.email;
      await _authService.reloadCurrentUser();
      final refreshedEmail = _authService.currentUser?.email;
      final emailChanged = previousEmail != refreshedEmail;
      final pendingWasApplied = _emailsMatch(
        _pendingEmailChange,
        refreshedEmail,
      );
      if (!mounted) return;
      setState(() {
        _isUpdatingProfile = false;
        if (pendingWasApplied) {
          _pendingEmailChange = null;
        }
      });
      if (pendingWasApplied) {
        await _profileStorage.delete(key: _pendingEmailKey);
      }
      if (!mounted) return;
      if (showFeedback || emailChanged || pendingWasApplied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailChanged || pendingWasApplied
                  ? 'Account email updated to $refreshedEmail.'
                  : _pendingEmailChange != null
                  ? 'Firebase still reports $refreshedEmail. The email-change link has not been applied yet.'
                  : 'Account information refreshed.',
            ),
          ),
        );
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _dismissPendingEmailChange() async {
    await _profileStorage.delete(key: _pendingEmailKey);
    if (!mounted) return;
    setState(() => _pendingEmailChange = null);
  }

  Future<void> _resendPendingEmailChange() async {
    final pendingEmail = _pendingEmailChange;
    if (pendingEmail == null || _isUpdatingProfile) return;
    setState(() => _isUpdatingProfile = true);
    try {
      await _requestEmailChangeWithReauthentication(pendingEmail);
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      await _showEmailChangeLinkSent(pendingEmail);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend link: ${error.message}')),
      );
    }
  }

  Future<void> _showEmailChangeLinkSent(String newEmail) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined),
        title: const Text('Check your new email'),
        content: Text(
          'Firebase accepted the request for:\n\n$newEmail\n\nOpen the newest verification link to finish changing the account email. Check Spam, Junk, and Promotions if it is not in the inbox. Delivery can be delayed or limited after repeated requests.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestEmailChangeWithReauthentication(String email) async {
    try {
      await _authService.requestCurrentUserEmailChange(email);
    } on RecentLoginRequiredException {
      if (!mounted) rethrow;
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _ConfirmPasswordDialog(),
      );
      if (password == null) {
        throw const AuthServiceException('Email change was canceled.');
      }
      await _authService.reauthenticateCurrentUserWithPassword(password);
      await _authService.requestCurrentUserEmailChange(email);
    }
  }

  Future<void> _sendPasswordReset() async {
    try {
      await _authService.sendCurrentUserPasswordReset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await _authService.sendCurrentUserEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingProfile = true);
    try {
      await _authService.signOut();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingProfile = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final hasProfileImage =
        _profileImagePath != null && File(_profileImagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: _isUpdatingProfile ? null : _editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Refresh account',
            onPressed: _isUpdatingProfile ? null : _refreshAccount,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _isUpdatingProfile ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: hasProfileImage
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: hasProfileImage
                            ? null
                            : const Icon(Icons.person_outline, size: 42),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: IconButton.filled(
                          tooltip: 'Change profile image',
                          onPressed: _isPickingImage ? null : _pickProfileImage,
                          icon: _isPickingImage
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(user?.email ?? ''),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      user?.emailVerified == true
                          ? Icons.verified
                          : Icons.warning_amber,
                      size: 18,
                    ),
                    label: Text(
                      user?.emailVerified == true
                          ? 'Email verified'
                          : 'Email not verified',
                    ),
                  ),
                  if (_isUpdatingProfile) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          if (_pendingEmailChange != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: const Text('Email change pending'),
                      subtitle: Text(
                        'Verify the change link sent to ${_pendingEmailChange!}.',
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _isUpdatingProfile
                              ? null
                              : _dismissPendingEmailChange,
                          child: const Text('Dismiss'),
                        ),
                        TextButton.icon(
                          onPressed: _isUpdatingProfile
                              ? null
                              : _resendPendingEmailChange,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Resend link'),
                        ),
                        FilledButton.icon(
                          onPressed: _isUpdatingProfile
                              ? null
                              : _refreshAccount,
                          icon: const Icon(Icons.refresh),
                          label: const Text('I verified, refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Account',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Name and email'),
                  subtitle: const Text('Update your account information'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isUpdatingProfile ? null : _editProfile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: const Text('Receive a secure password reset email'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _sendPasswordReset,
                ),
                if (user?.emailVerified != true &&
                    _pendingEmailChange == null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.mark_email_unread_outlined),
                    title: const Text('Verify email'),
                    subtitle: const Text('Send another verification link'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _sendEmailVerification,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Security',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                _isBiometricEnabled ? Icons.fingerprint : Icons.lock_outline,
                color: _isBiometricEnabled ? Colors.green : Colors.teal,
              ),
              title: Text(
                _isBiometricEnabled
                    ? 'Fingerprint app lock enabled'
                    : 'Enable fingerprint app lock',
              ),
              subtitle: Text(
                !_isBiometricSupported
                    ? 'Set up biometrics or a device screen lock first'
                    : _isBiometricEnabled
                    ? 'This app requires device authentication to open.'
                    : 'Protect this app with your device security.',
              ),
              trailing: _isLoadingBiometric
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isBiometricSupported && !_isLoadingBiometric
                  ? _toggleBiometricLock
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'When enabled, Filer Flow asks for your fingerprint, Face ID, or device screen lock on launch and after returning from the background.',
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialEmail,
  });

  final String initialName;
  final String initialEmail;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ProfileUpdate(
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ProfileUpdate {
  const _ProfileUpdate({required this.displayName, required this.email});

  final String displayName;
  final String email;
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog();

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
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
      icon: const Icon(Icons.lock_outline),
      title: const Text('Confirm your password'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Firebase requires a recent login before changing your email.',
            ),
            const SizedBox(height: 14),
            TextField(
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
          ],
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

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          const _DriveSyncButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                final currentUserId = user?.uid ?? '';
                final storedTransactions =
                    state is TransactionLoaded && state.userId == currentUserId
                    ? state.transactions
                    : const <entity.Transaction>[];
                final transactions = storedTransactions
                    .map(
                      (transaction) => transaction.copyWith(
                        isExpense: widget.categoryPreferences.isExpense(
                          transaction.category,
                        ),
                      ),
                    )
                    .toList();
                final visibleTransactions = filterTransactionsByMonth(
                  transactions,
                  _selectedMonth,
                );
                final monthOptions = _buildMonthOptions(transactions);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useTwoColumnHeader = constraints.maxWidth >= 640;

                        if (useTwoColumnHeader) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Welcome, ${user?.displayName ?? user?.email ?? 'User'}!',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                              if (monthOptions.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 180,
                                  child: _MonthFilterDropdown(
                                    selectedMonth: _selectedMonth,
                                    monthOptions: monthOptions,
                                    onChanged: (month) {
                                      setState(() {
                                        _selectedMonth = month;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Welcome, ${user?.displayName ?? user?.email ?? 'User'}!',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            if (monthOptions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: _MonthFilterDropdown(
                                  selectedMonth: _selectedMonth,
                                  monthOptions: monthOptions,
                                  onChanged: (month) {
                                    setState(() {
                                      _selectedMonth = month;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SummaryCards(transactions: visibleTransactions),
                    const SizedBox(height: 16),
                    _IncomeExpensePiePanel(transactions: visibleTransactions),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PrintTransactionsButton(
                        transactions: visibleTransactions,
                        filterLabel: _transactionFilterLabel(_selectedMonth),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Income Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _CategoryCards(
                      transactions: visibleTransactions,
                      isExpense: false,
                      categoryPreferences: widget.categoryPreferences,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Expense Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _CategoryCards(
                      transactions: visibleTransactions,
                      isExpense: true,
                      categoryPreferences: widget.categoryPreferences,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _TransactionList(
                      state: state,
                      currentUserId: currentUserId,
                      transactions: visibleTransactions,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveSyncButton extends StatefulWidget {
  const _DriveSyncButton();

  @override
  State<_DriveSyncButton> createState() => _DriveSyncButtonState();
}

class _DriveSyncButtonState extends State<_DriveSyncButton> {
  bool _isWorking = false;

  Future<void> _runDriveOperation(_DriveAction action) async {
    if (_isWorking) return;
    if (action == _DriveAction.restore && !await _confirmRestore()) return;
    if (!mounted) return;

    setState(() {
      _isWorking = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    try {
      await authService.getGoogleDriveHeaders(promptIfNecessary: true);
      final driveService = DriveService();
      final result = action == _DriveAction.backup
          ? await driveService.syncDatabaseToCloud()
          : await driveService.restoreBackupFromCloud();

      if (!mounted) return;
      if (result.success && action == _DriveAction.restore) {
        context.read<TransactionBloc>().add(const LoadTransactions());
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? null : Colors.red.shade700,
          ),
        );
    } on AuthServiceException catch (error) {
      debugPrint('AUTH SERVICE ERROR: ${error.message}');
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (e, stackTrace) {
      debugPrint('DRIVE BACKUP/RESTORE ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Google Drive operation failed: $e')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<bool> _confirmRestore() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.restore_outlined),
            title: const Text('Restore Drive backup?'),
            content: const Text(
              'This replaces transactions and receipt images on this device with the latest Google Drive backup. Back up current changes first if you need them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DriveAction>(
      tooltip: 'Google Drive backup and restore',
      enabled: !_isWorking,
      onSelected: _runDriveOperation,
      icon: _isWorking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.cloud_sync_outlined),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _DriveAction.backup,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_upload_outlined),
            title: Text('Back up now'),
            subtitle: Text('Database and receipt images'),
          ),
        ),
        PopupMenuItem(
          value: _DriveAction.restore,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restore_outlined),
            title: Text('Restore from Drive'),
            subtitle: Text('Replace data on this device'),
          ),
        ),
      ],
    );
  }
}

enum _DriveAction { backup, restore }

IconData _getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'salary':
      return Icons.work;
    case 'investment':
      return Icons.trending_up;
    case 'tax':
      return Icons.receipt_long;
    case 'health':
      return Icons.local_hospital;
    case 'food & drinks':
      return Icons.restaurant;
    case 'shopping':
      return Icons.shopping_bag;
    case 'housing & utils':
      return Icons.home_work;
    case 'rent':
      return Icons.key_outlined;
    case 'transport':
      return Icons.directions_car_outlined;
    case 'personal care':
      return Icons.spa;
    case 'subscriptions':
      return Icons.subscriptions;
    case 'gifts & rewards':
      return Icons.card_giftcard;
    case 'zakat':
      return Icons.volunteer_activism;
    case 'misc':
      return Icons.more_horiz;
    default:
      return Icons.category;
  }
}

Color _getColorForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'salary':
      return Colors.green;
    case 'investment':
      return Colors.indigo;
    case 'tax':
      return Colors.deepOrange;
    case 'health':
      return Colors.red;
    case 'food & drinks':
      return Colors.amber.shade800;
    case 'shopping':
      return Colors.purple;
    case 'housing & utils':
      return Colors.blueGrey;
    case 'rent':
      return Colors.brown;
    case 'transport':
      return Colors.cyan.shade800;
    case 'personal care':
      return Colors.pink;
    case 'subscriptions':
      return Colors.blue;
    case 'gifts & rewards':
      return const Color(0xFF0F6B57);
    case 'zakat':
      return Colors.lightGreen.shade700;
    default:
      return Colors.grey.shade700;
  }
}

String _formatDashboardMoney(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  final sign = value < 0 ? '-' : '';
  return 'PKR $sign${buffer.toString()}';
}

List<entity.Transaction> filterTransactionsByMonth(
  List<entity.Transaction> transactions,
  DateTime? selectedMonth,
) {
  if (selectedMonth == null) {
    return transactions;
  }

  return transactions.where((transaction) {
    return transaction.date.year == selectedMonth.year &&
        transaction.date.month == selectedMonth.month;
  }).toList();
}

List<DateTime> _buildMonthOptions(List<entity.Transaction> transactions) {
  final months =
      transactions
          .map(
            (transaction) =>
                DateTime(transaction.date.year, transaction.date.month),
          )
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
  return months;
}

double _totalIncome(List<entity.Transaction> transactions) {
  return transactions
      .where((transaction) => !transaction.isExpense)
      .fold<double>(0, (total, transaction) => total + transaction.amount);
}

double _totalExpenses(List<entity.Transaction> transactions) {
  return transactions
      .where((transaction) => transaction.isExpense)
      .fold<double>(0, (total, transaction) => total + transaction.amount);
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalIncome(transactions);
    final totalExpenses = _totalExpenses(transactions);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final useTwoColumns = maxWidth >= 560;
        final cardWidth = useTwoColumns ? (maxWidth - 16) / 2 : maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Income',
                amount: _formatDashboardMoney(totalIncome),
                icon: Icons.arrow_upward,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Expenses',
                amount: _formatDashboardMoney(totalExpenses),
                icon: Icons.arrow_downward,
                color: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 180;

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isCompact
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.titleLarge)
                            ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCards extends StatelessWidget {
  const _CategoryCards({
    required this.transactions,
    required this.isExpense,
    required this.categoryPreferences,
  });

  final List<entity.Transaction> transactions;
  final bool isExpense;
  final CategoryPreferencesService categoryPreferences;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        final isCompact = constraints.maxWidth < 360;

        final categories = TransactionCategory.all
            .where(
              (category) =>
                  categoryPreferences.isExpense(category.name) == isExpense,
            )
            .toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            //mainAxisExtent: isCompact ? 170 : 150,
            mainAxisExtent: isCompact ? 155 : 150,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryTransactions = transactions
                .where((transaction) => transaction.category == category.name)
                .toList();
            return _CategoryCard(
              category: category.name,
              transactions: categoryTransactions,
              categoryPreferences: categoryPreferences,
            );
          },
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.transactions,
    required this.categoryPreferences,
  });

  final String category;
  final List<entity.Transaction> transactions;
  final CategoryPreferencesService categoryPreferences;

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(category);
    final income = transactions
        .where((transaction) => !transaction.isExpense)
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final expenses = transactions
        .where((transaction) => transaction.isExpense)
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final latestTransaction = transactions.isEmpty ? null : transactions.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _CategoryTransactionsPage(
                    category: category,
                    categoryPreferences: categoryPreferences,
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: isCompact ? 15 : 18,
                        backgroundColor: color.withValues(alpha: 0.12),
                        foregroundColor: color,
                        child: Icon(
                          _getIconForCategory(category),
                          size: isCompact ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 10),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            category,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isCompact ? 13 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${transactions.length} transactions',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latestTransaction?.title ?? 'No entries yet',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CategoryAmountRow(
                    label: 'Amount',
                    value: _formatDashboardMoney(
                      transactions.any((transaction) => transaction.isExpense)
                          ? expenses
                          : income,
                    ),
                    color:
                        transactions.any((transaction) => transaction.isExpense)
                        ? Colors.red.shade700
                        : Colors.green.shade700,
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

class _CategoryTransactionsPage extends StatelessWidget {
  const _CategoryTransactionsPage({
    required this.category,
    required this.categoryPreferences,
  });

  final String category;
  final CategoryPreferencesService categoryPreferences;

  void _openAddTransaction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          initialCategory: category,
          initialIsExpense: categoryPreferences.isExpense(category),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(category);
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoading || state is TransactionInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TransactionError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          final transactions = (state as TransactionLoaded).transactions
              .where((transaction) => transaction.category == category)
              .map(
                (transaction) => transaction.copyWith(
                  isExpense: categoryPreferences.isExpense(category),
                ),
              )
              .toList();
          final total = transactions.fold<double>(
            0,
            (sum, transaction) => sum + transaction.amount,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                elevation: 0,
                color: color.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.14),
                        foregroundColor: color,
                        child: Icon(_getIconForCategory(category), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${transactions.length} transactions',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text('Total: ${_formatDashboardMoney(total)}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openAddTransaction(context),
                icon: const Icon(Icons.add),
                label: Text('Add $category transaction'),
              ),
              const SizedBox(height: 10),
              _PrintTransactionsButton(
                transactions: transactions,
                filterLabel: '$category transactions',
                buttonLabel: 'Print $category report',
              ),
              const SizedBox(height: 16),
              Text(
                '$category history',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No transactions in this category yet.'),
                  ),
                )
              else
                ...transactions.map(
                  (transaction) => _TransactionTile(transaction: transaction),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _transactionFilterLabel(DateTime? selectedMonth) {
  if (selectedMonth == null) return 'All transactions';
  return DateFormat('MMMM yyyy').format(selectedMonth);
}

class _PrintTransactionsButton extends StatefulWidget {
  const _PrintTransactionsButton({
    required this.transactions,
    required this.filterLabel,
    this.buttonLabel = 'Print report',
  });

  final List<entity.Transaction> transactions;
  final String filterLabel;
  final String buttonLabel;

  @override
  State<_PrintTransactionsButton> createState() =>
      _PrintTransactionsButtonState();
}

class _PrintTransactionsButtonState extends State<_PrintTransactionsButton> {
  bool _isPrinting = false;

  Future<void> _print() async {
    if (_isPrinting || widget.transactions.isEmpty) return;
    setState(() => _isPrinting = true);
    try {
      await const TransactionReportService().printReport(
        transactions: widget.transactions,
        filterLabel: widget.filterLabel,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not prepare the report: $error')),
        );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_isPrinting && widget.transactions.isNotEmpty;
    final icon = _isPrinting
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.print_outlined);
    return OutlinedButton.icon(
      onPressed: enabled ? _print : null,
      icon: icon,
      label: Text(
        widget.transactions.isEmpty
            ? 'No transactions to print'
            : widget.buttonLabel,
      ),
    );
  }
}

class _MonthFilterDropdown extends StatelessWidget {
  const _MonthFilterDropdown({
    required this.selectedMonth,
    required this.monthOptions,
    required this.onChanged,
  });

  final DateTime? selectedMonth;
  final List<DateTime> monthOptions;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DateTime?>(
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(),
      ),
      initialValue: selectedMonth,
      hint: const Text('Select month'),
      items: [
        const DropdownMenuItem<DateTime?>(
          value: null,
          child: Text('All months'),
        ),
        ...monthOptions.map(
          (month) => DropdownMenuItem<DateTime?>(
            value: month,
            child: Text(_monthLabel(month)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

String _monthLabel(DateTime month) {
  return '${_monthName(month.month)} ${month.year}';
}

String _monthName(int month) {
  switch (month) {
    case 1:
      return 'Jan';
    case 2:
      return 'Feb';
    case 3:
      return 'Mar';
    case 4:
      return 'Apr';
    case 5:
      return 'May';
    case 6:
      return 'Jun';
    case 7:
      return 'Jul';
    case 8:
      return 'Aug';
    case 9:
      return 'Sep';
    case 10:
      return 'Oct';
    case 11:
      return 'Nov';
    default:
      return 'Dec';
  }
}

class _CategoryAmountRow extends StatelessWidget {
  const _CategoryAmountRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _IncomeExpensePiePanel extends StatelessWidget {
  const _IncomeExpensePiePanel({required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalIncome(transactions);
    final totalExpenses = _totalExpenses(transactions);
    final totalActivity = totalIncome + totalExpenses;
    final balance = totalIncome - totalExpenses;
    final comparison = _ComparisonState.fromBalance(balance, totalActivity);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            final chart = totalActivity <= 0
                ? const _EmptyPieChart()
                : _IncomeExpensePieChart(
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                  );
            final comparisonPanel = _IncomeExpenseComparison(
              comparison: comparison,
              totalIncome: totalIncome,
              totalExpenses: totalExpenses,
              balance: balance,
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PiePanelHeader(comparison: comparison),
                  const SizedBox(height: 16),
                  SizedBox(height: 230, child: chart),
                  const SizedBox(height: 16),
                  comparisonPanel,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PiePanelHeader(comparison: comparison),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SizedBox(height: 240, child: chart)),
                    const SizedBox(width: 20),
                    Expanded(child: comparisonPanel),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IncomeExpensePieChart extends StatelessWidget {
  const _IncomeExpensePieChart({
    required this.totalIncome,
    required this.totalExpenses,
  });

  final double totalIncome;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final total = totalIncome + totalExpenses;
    final netBalance = totalIncome - totalExpenses;
    final incomePercent = total == 0 ? 0 : (totalIncome / total) * 100;
    final expensePercent = total == 0 ? 0 : (totalExpenses / total) * 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 54,
            sectionsSpace: 3,
            borderData: FlBorderData(show: false),
            sections: [
              if (totalIncome > 0)
                PieChartSectionData(
                  value: totalIncome,
                  color: Colors.green,
                  radius: 62,
                  title: '${incomePercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              if (totalExpenses > 0)
                PieChartSectionData(
                  value: totalExpenses,
                  color: Colors.red,
                  radius: 62,
                  title: '${expensePercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Net Balance',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatDashboardMoney(netBalance),
                  maxLines: 1,
                  style: TextStyle(
                    color: netBalance < 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePanelHeader extends StatelessWidget {
  const _PiePanelHeader({required this.comparison});

  final _ComparisonState comparison;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.pie_chart_outline, color: comparison.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Income vs Expenses',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _IncomeExpenseComparison extends StatelessWidget {
  const _IncomeExpenseComparison({
    required this.comparison,
    required this.totalIncome,
    required this.totalExpenses,
    required this.balance,
  });

  final _ComparisonState comparison;
  final double totalIncome;
  final double totalExpenses;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: comparison.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: comparison.color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: comparison.color.withValues(alpha: 0.14),
                  foregroundColor: comparison.color,
                  child: Icon(comparison.icon, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    comparison.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              comparison.description(balance.abs()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _LegendAmountRow(
              color: Colors.green,
              label: 'Income',
              value: _formatDashboardMoney(totalIncome),
            ),
            const SizedBox(height: 8),
            _LegendAmountRow(
              color: Colors.red,
              label: 'Expenses',
              value: _formatDashboardMoney(totalExpenses),
            ),
            const Divider(height: 24),
            _LegendAmountRow(
              color: comparison.color,
              label: comparison.balanceLabel,
              value: _formatDashboardMoney(balance.abs()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendAmountRow extends StatelessWidget {
  const _LegendAmountRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPieChart extends StatelessWidget {
  const _EmptyPieChart();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Add income or expense transactions to update the pie chart.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ComparisonState {
  const _ComparisonState({
    required this.title,
    required this.balanceLabel,
    required this.color,
    required this.icon,
    required this.description,
  });

  final String title;
  final String balanceLabel;
  final Color color;
  final IconData icon;
  final String Function(double amount) description;

  static _ComparisonState fromBalance(double balance, double totalActivity) {
    if (totalActivity <= 0) {
      return _ComparisonState(
        title: 'No activity yet',
        balanceLabel: 'Balance',
        color: Colors.blueGrey,
        icon: Icons.insights_outlined,
        description: (_) =>
            'Add transactions to compare income, expenses, and savings.',
      );
    }

    if (balance > 0) {
      return _ComparisonState(
        title: 'Savings / Profit',
        balanceLabel: 'Savings',
        color: Colors.green,
        icon: Icons.savings_outlined,
        description: (amount) =>
            'Income is ${_formatDashboardMoney(amount)} higher than expenses.',
      );
    }

    if (balance < 0) {
      return _ComparisonState(
        title: 'Loss',
        balanceLabel: 'Loss',
        color: Colors.red,
        icon: Icons.trending_down,
        description: (amount) =>
            'Expenses are ${_formatDashboardMoney(amount)} higher than income.',
      );
    }

    return _ComparisonState(
      title: 'Break-even',
      balanceLabel: 'Balance',
      color: Colors.blueGrey,
      icon: Icons.balance_outlined,
      description: (_) => 'Income and expenses are equal.',
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.state,
    required this.currentUserId,
    required this.transactions,
  });

  final TransactionState state;
  final String currentUserId;
  final List<entity.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (state is TransactionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is TransactionLoaded) {
      final loadedState = state as TransactionLoaded;
      if (loadedState.userId != currentUserId) {
        return const Center(child: CircularProgressIndicator());
      }
      if (transactions.isEmpty) {
        return const Center(child: Text('No transactions yet. Add one!'));
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          return _TransactionTile(transaction: transactions[index]);
        },
      );
    }
    if (state is TransactionError) {
      return Center(
        child: Text('Error: ${(state as TransactionError).message}'),
      );
    }
    return const Center(
      child: Text('Press the + button to add a transaction.'),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final entity.Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isExpense
        ? Colors.red.shade700
        : Colors.green.shade700;
    final amountPrefix = transaction.isExpense ? '- ' : '+ ';
    final icon = _getIconForCategory(transaction.category);
    final color = transaction.isExpense ? Colors.orange : Colors.green;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.category} | ${transaction.beneficiary}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transaction.purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transaction.date.toLocal().toString().split(' ')[0],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$amountPrefix PKR ${transaction.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AddTransactionPage(transaction: transaction),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: transaction.id == null
                      ? null
                      : () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: Text('Delete "${transaction.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    final id = transaction.id;
    if (confirmed == true && context.mounted && id != null) {
      context.read<TransactionBloc>().add(DeleteTransaction(id));
    }
  }
}
