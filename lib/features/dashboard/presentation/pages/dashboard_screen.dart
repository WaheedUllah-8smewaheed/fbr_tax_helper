import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/pages/tax_calculator_screen.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/services/transaction_report_service.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

import 'package:fbr_tax_helper/core/platform/app_storage.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/auth/services/biometric_lock_service.dart';
import 'package:fbr_tax_helper/features/backup/services/drive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

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
    if (kIsWeb) return;
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
              'Please enable fingerprint for two-factor authentication in the Profile menu.',
            ),
            duration: const Duration(seconds: 5),
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
    const titles = ['DASHBOARD', 'TRANSACTIONS', 'SETTINGS', 'MORE'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: ListenableBuilder(
        listenable: _categoryPreferences,
        builder: (context, _) => IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeDashboard(categoryPreferences: _categoryPreferences),
            _TransactionsPage(categoryPreferences: _categoryPreferences),
            _CategorySettingsPage(categoryPreferences: _categoryPreferences),
            const _MorePage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_outlined),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}

enum _TransactionFilter { income, expense, both }

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  _TransactionFilter _filter = _TransactionFilter.income;

  void _openParentTransaction(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          parentCategory: parentCategory,
          categoryOptions: categoryOptions,
        ),
      ),
    );
  }

  bool _isVisible(TransactionCategory category) {
    if (!widget.categoryPreferences.isEnabled(category.name)) return false;
    return switch (_filter) {
      _TransactionFilter.income =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: false,
        ),
      _TransactionFilter.expense =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: true,
        ),
      _TransactionFilter.both => widget.categoryPreferences.isDualMode(
        category.name,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_TransactionFilter>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _TransactionFilter.income,
                label: Text('Income'),
              ),
              ButtonSegment(
                value: _TransactionFilter.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: _TransactionFilter.both,
                label: Text('Both'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _AllTransactionsPage(
                    categoryPreferences: widget.categoryPreferences,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View All Transactions'),
          ),
          const SizedBox(height: 20),
          ...TransactionCategory.hierarchy.entries.expand((superCategory) {
            final visibleParents = superCategory.value.entries
                .map(
                  (parent) => MapEntry(
                    parent.key,
                    parent.value.where(_isVisible).toList(),
                  ),
                )
                .where((parent) => parent.value.isNotEmpty)
                .toList();
            if (visibleParents.isEmpty) return const <Widget>[];
            return <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  superCategory.key,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    for (
                      var parentIndex = 0;
                      parentIndex < visibleParents.length;
                      parentIndex++
                    ) ...[
                      ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForCategory(
                            visibleParents[parentIndex].key,
                          ).withValues(alpha: 0.12),
                          foregroundColor: _getColorForCategory(
                            visibleParents[parentIndex].key,
                          ),
                          child: Icon(
                            _getIconForCategory(
                              visibleParents[parentIndex].key,
                            ),
                            size: 20,
                          ),
                        ),
                        title: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openParentTransaction(
                            visibleParents[parentIndex].key,
                            visibleParents[parentIndex].value,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              visibleParents[parentIndex].key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        children: [
                          for (
                            var categoryIndex = 0;
                            categoryIndex <
                                visibleParents[parentIndex].value.length;
                            categoryIndex++
                          ) ...[
                            ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                              ),
                              title: Text(
                                visibleParents[parentIndex]
                                    .value[categoryIndex]
                                    .name,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final category = visibleParents[parentIndex]
                                    .value[categoryIndex];
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        _CategoryTransactionsPage(
                                          category: category.name,
                                          categoryPreferences:
                                              widget.categoryPreferences,
                                        ),
                                  ),
                                );
                              },
                            ),
                            if (categoryIndex <
                                visibleParents[parentIndex].value.length - 1)
                              const Divider(height: 1, indent: 72),
                          ],
                        ],
                      ),
                      if (parentIndex < visibleParents.length - 1)
                        const Divider(height: 1, indent: 72),
                    ],
                  ],
                ),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

enum _TransactionDateFilter { all, month, range }

class _AllTransactionsPage extends StatefulWidget {
  const _AllTransactionsPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<_AllTransactionsPage> {
  _TransactionDateFilter _dateFilter = _TransactionDateFilter.all;
  DateTime? _selectedMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  Future<void> _pickRangeDate({required bool isStart}) async {
    final now = DateTime.now();
    final firstDate = isStart
        ? DateTime(2000)
        : (_rangeStart ?? DateTime(2000));
    final lastDate = isStart ? (_rangeEnd ?? now) : now;
    final initialDate = isStart
        ? (_rangeStart ?? _rangeEnd ?? now)
        : (_rangeEnd ?? _rangeStart ?? now);
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      if (isStart) {
        _rangeStart = selectedDate;
      } else {
        _rangeEnd = selectedDate;
      }
    });
  }

  List<entity.Transaction> _applyFilters(
    List<entity.Transaction> transactions,
  ) {
    return transactions.where((transaction) {
      return switch (_dateFilter) {
        _TransactionDateFilter.all => true,
        _TransactionDateFilter.month =>
          _selectedMonth == null ||
              (transaction.date.year == _selectedMonth!.year &&
                  transaction.date.month == _selectedMonth!.month),
        _TransactionDateFilter.range => _isInsideSelectedRange(
          transaction.date,
        ),
      };
    }).toList();
  }

  bool _isInsideSelectedRange(DateTime date) {
    final rangeStart = _rangeStart;
    final rangeEnd = _rangeEnd;
    if (rangeStart == null || rangeEnd == null) return true;
    final value = DateTime(date.year, date.month, date.day);
    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
    return !value.isBefore(start) && !value.isAfter(end);
  }

  String _filterLabel() {
    final period = switch (_dateFilter) {
      _TransactionDateFilter.all => 'All dates',
      _TransactionDateFilter.month =>
        _selectedMonth == null
            ? 'All months'
            : DateFormat('MMMM yyyy').format(_selectedMonth!),
      _TransactionDateFilter.range =>
        _rangeStart == null || _rangeEnd == null
            ? 'Select from and to dates'
            : '${DateFormat('MMM d, yyyy').format(_rangeStart!)} – ${DateFormat('MMM d, yyyy').format(_rangeEnd!)}',
    };
    return 'All transactions • $period';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          final storedTransactions =
              state is TransactionLoaded && state.userId == currentUserId
              ? state.transactions
              : const <entity.Transaction>[];
          final resolvedTransactions = storedTransactions
              .map(
                (transaction) => transaction.copyWith(
                  isExpense: widget.categoryPreferences
                      .resolveTransactionTypeForCategory(
                        categoryName: transaction.category,
                        transactionIsExpense: transaction.isExpense,
                      ),
                ),
              )
              .toList();
          final monthOptions = _buildMonthOptions(resolvedTransactions);
          final visibleTransactions = _applyFilters(resolvedTransactions);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_TransactionDateFilter>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _TransactionDateFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: _TransactionDateFilter.month,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: _TransactionDateFilter.range,
                    label: Text('Range'),
                  ),
                ],
                selected: {_dateFilter},
                onSelectionChanged: (selection) {
                  setState(() {
                    _dateFilter = selection.first;
                    if (_dateFilter == _TransactionDateFilter.month &&
                        _selectedMonth == null &&
                        monthOptions.isNotEmpty) {
                      _selectedMonth = monthOptions.first;
                    }
                  });
                },
              ),
              if (_dateFilter == _TransactionDateFilter.month) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<DateTime>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: monthOptions
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text(_monthLabel(month)),
                        ),
                      )
                      .toList(),
                  onChanged: (month) => setState(() => _selectedMonth = month),
                ),
              ],
              if (_dateFilter == _TransactionDateFilter.range) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_rangeStart),
                        readOnly: true,
                        initialValue: _rangeStart == null
                            ? ''
                            : DateFormat('dd MMM yyyy').format(_rangeStart!),
                        decoration: const InputDecoration(
                          labelText: 'From',
                          hintText: 'Select date',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () => _pickRangeDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(_rangeEnd),
                        readOnly: true,
                        initialValue: _rangeEnd == null
                            ? ''
                            : DateFormat('dd MMM yyyy').format(_rangeEnd!),
                        decoration: const InputDecoration(
                          labelText: 'To',
                          hintText: 'Select date',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () => _pickRangeDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                if (_rangeStart == null || _rangeEnd == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Select both dates to filter transactions in between.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visibleTransactions.length} transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _PrintTransactionsButton(
                    transactions: visibleTransactions,
                    filterLabel: _filterLabel(),
                    buttonLabel: 'Print',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TransactionList(
                state: state,
                currentUserId: currentUserId,
                transactions: visibleTransactions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MorePage extends StatefulWidget {
  const _MorePage();

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  static const _profileStorage = FlutterSecureStorage();
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  String _profileImageKey(String? userId) =>
      'profile_image_${userId ?? 'signed_out'}';

  Future<void> _loadProfileImage() async {
    final userId = context.read<AuthService>().currentUser?.uid;
    final storedPath = await _profileStorage.read(
      key: _profileImageKey(userId),
    );
    if (!mounted) return;
    setState(() {
      _profileImagePath = storedPath != null && File(storedPath).existsSync()
          ? storedPath
          : null;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('You will need to sign in again to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;
    final photoUrl = user?.photoURL;
    final hasLocalProfileImage =
        _profileImagePath != null && File(_profileImagePath!).existsSync();
    final ImageProvider<Object>? profileImage = hasLocalProfileImage
        ? FileImage(File(_profileImagePath!))
        : photoUrl != null && photoUrl.isNotEmpty
        ? NetworkImage(photoUrl)
        : null;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: profileImage,
                child: profileImage == null
                    ? const Icon(Icons.person_outline, size: 30)
                    : null,
              ),
              title: Text(
                user?.displayName ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(user?.email ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const _ProfilePage()),
                );
                if (context.mounted) await _loadProfileImage();
              },
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Tax Calculator'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TaxCalculatorScreen(appBarTitle: 'Tax Calculator'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                const _DriveSyncButton(asListTile: true),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _InformationPage(
                        title: 'Help & Support',
                        icon: Icons.help_outline,
                        message:
                            'If you experience any issues or have questions about using the application, please reach out to our support team at:',
                        supportEmail: 'graphie-codesolutions@gmail.com',
                        footerMessage:
                            "We're here to assist you and will respond as soon as possible.",
                        messageTextAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _InformationPage(
                        title: 'About',
                        icon: Icons.info_outline,
                        message:
                            '''Filer Flow is your all-in-one personal finance companion — track income and expenses, calculate taxes, and stay on top of your money effortlessly.

Key Features:

• Visual dashboard with income, expense & balance overview
• Quick transaction entry — manually or via receipt scan
• Customizable income/expense categories
• Built-in tax calculator (Salary, PSEB Export, WHT)
• Secure backup & restore via Google Drive
• Fingerprint-secured profile with 2FA

Your data stays on your device , you control when and where it's backed up.

Version: 1.0
Developed by: Graphie-Code Solutions''',
                        messageTextAlign: TextAlign.left,
                        useSmallMessageText: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({
    required this.title,
    required this.icon,
    required this.message,
    this.messageTextAlign = TextAlign.center,
    this.useSmallMessageText = false,
    this.supportEmail,
    this.footerMessage,
  });

  final String title;
  final IconData icon;
  final String message;
  final TextAlign messageTextAlign;
  final bool useSmallMessageText;
  final String? supportEmail;
  final String? footerMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 52),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: messageTextAlign == TextAlign.left
                            ? Alignment.centerLeft
                            : Alignment.center,
                        child: Text(
                          message,
                          textAlign: messageTextAlign,
                          style: useSmallMessageText
                              ? Theme.of(context).textTheme.bodySmall
                              : null,
                        ),
                      ),
                      if (supportEmail != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: SelectableText(
                                  supportEmail!,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (footerMessage != null) ...[
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            footerMessage!,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySettingsPage extends StatelessWidget {
  const _CategorySettingsPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  Future<void> _updateEnabled(
    BuildContext context,
    String categoryName,
    bool enabled,
  ) async {
    try {
      await categoryPreferences.setEnabled(categoryName, enabled: enabled);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  Future<void> _updateParentMode(
    BuildContext context,
    String parentName,
    CategoryMode mode,
  ) async {
    try {
      await categoryPreferences.setParentMode(parentName, mode: mode);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  Future<void> _updateParentEnabled(
    BuildContext context,
    String parentName,
    bool enabled,
  ) async {
    try {
      await categoryPreferences.setParentEnabled(parentName, enabled: enabled);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  IconData _iconForSuperCategory(String name) {
    return switch (name) {
      'Money In' => Icons.account_balance_wallet_outlined,
      'Home' => Icons.home_outlined,
      'Travel' => Icons.directions_car_outlined,
      'Food' => Icons.restaurant_outlined,
      'Shopping' => Icons.shopping_bag_outlined,
      'Health' => Icons.favorite_outline,
      'Education' => Icons.school_outlined,
      'Personal Care' => Icons.spa_outlined,
      'Entertainment' => Icons.tv_outlined,
      'Gifts' => Icons.card_giftcard_outlined,
      'Charity' => Icons.volunteer_activism_outlined,
      'Taxes' => Icons.request_quote_outlined,
      'Banking' => Icons.account_balance_outlined,
      'Others' => Icons.inventory_2_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: categoryPreferences.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'CATEGORY SETTINGS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toggle a category to show or hide all its items. You can also turn on individual items and set each as Income, Expense, or Both.',
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
                ...TransactionCategory.hierarchy.entries.map((superCategory) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: Icon(_iconForSuperCategory(superCategory.key)),
                        title: Text(
                          superCategory.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        children: [
                          for (final parent in superCategory.value.entries)
                            ExpansionTile(
                              tilePadding: const EdgeInsets.only(
                                left: 28,
                                right: 16,
                              ),
                              childrenPadding: EdgeInsets.zero,
                              leading: Icon(
                                _getIconForCategory(parent.key),
                                size: 21,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      parent.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: categoryPreferences.isParentEnabled(
                                      parent.key,
                                    ),
                                    onChanged: (enabled) =>
                                        _updateParentEnabled(
                                          context,
                                          parent.key,
                                          enabled,
                                        ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    10,
                                  ),
                                  child: SegmentedButton<CategoryMode>(
                                    expandedInsets: EdgeInsets.zero,
                                    showSelectedIcon: false,
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    segments: const [
                                      ButtonSegment(
                                        value: CategoryMode.income,
                                        label: Text('Income'),
                                      ),
                                      ButtonSegment(
                                        value: CategoryMode.expense,
                                        label: Text('Expense'),
                                      ),
                                      ButtonSegment(
                                        value: CategoryMode.both,
                                        label: Text('Both'),
                                      ),
                                    ],
                                    selected: {
                                      categoryPreferences.modeForParent(
                                        parent.key,
                                      ),
                                    },
                                    onSelectionChanged: (selection) =>
                                        _updateParentMode(
                                          context,
                                          parent.key,
                                          selection.first,
                                        ),
                                  ),
                                ),
                                for (final category in parent.value)
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 48,
                                      right: 16,
                                    ),
                                    title: Text(category.name),
                                    subtitle: Text(
                                      categoryPreferences.isDualMode(
                                            category.name,
                                          )
                                          ? 'Income or Expense'
                                          : categoryPreferences.isExpense(
                                              category.name,
                                            )
                                          ? 'Expense'
                                          : 'Income',
                                    ),
                                    value: categoryPreferences.isEnabled(
                                      category.name,
                                    ),
                                    onChanged: (enabled) => _updateEnabled(
                                      context,
                                      category.name,
                                      enabled,
                                    ),
                                  ),
                              ],
                            ),
                        ],
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

      final supportDirectory = await AppStorage.getSupportDirectory();
      if (supportDirectory == null) {
        throw UnsupportedError('Profile image storage is unavailable on web.');
      }
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
    final photoUrl = user?.photoURL;
    final hasProfileImage =
        _profileImagePath != null && File(_profileImagePath!).existsSync();
    final ImageProvider<Object>? profileImage = hasProfileImage
        ? FileImage(File(_profileImagePath!))
        : photoUrl != null && photoUrl.isNotEmpty
        ? NetworkImage(photoUrl)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
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
                        backgroundImage: profileImage,
                        child: profileImage != null
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
                        isExpense: widget.categoryPreferences
                            .resolveTransactionTypeForCategory(
                              categoryName: transaction.category,
                              transactionIsExpense: transaction.isExpense,
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
                    _TopCategoryCharts(transactions: visibleTransactions),
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
  const _DriveSyncButton({this.asListTile = false});

  final bool asListTile;

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
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw const AuthServiceException(
          'Sign in before using Google Drive backup and restore.',
        );
      }
      final driveService = DriveService(
        ownerId: currentUser.uid,
        ownerEmail: currentUser.email,
      );
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
    final filerFlowEmail = context.read<AuthService>().currentUser?.email;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.restore_outlined),
            title: const Text('Restore Drive backup?'),
            content: Text(
              'This restores transactions and receipt images for ${filerFlowEmail ?? 'the signed-in Filer Flow account'} and replaces local data on this device. When Google asks, select the same Drive account used for the backup.',
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
      child: IgnorePointer(
        child: widget.asListTile
            ? ListTile(
                leading: _isWorking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_outlined),
                title: const Text('Backup & Restore'),
                trailing: const Icon(Icons.chevron_right),
              )
            : FloatingActionButton.extended(
                heroTag: 'drive-backup-button',
                onPressed: () {},
                icon: _isWorking
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_isWorking ? 'Working…' : 'Backup'),
              ),
      ),
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
    case 'business':
      return Icons.trending_up;
    case 'tax':
    case 'taxes':
    case 'income tax':
    case 'property tax':
    case 'salary tax (withholding)':
    case 'sales tax/gst':
      return Icons.payments;
    case 'health':
      return Icons.local_hospital;
    case 'food & drinks':
    case 'food':
      return Icons.restaurant;
    case 'shopping':
      return Icons.shopping_bag;
    case 'housing & utils':
    case 'bills':
      return Icons.home_work;
    case 'rent':
      return Icons.key_outlined;
    case 'transport':
    case 'travel':
      return Icons.directions_car_outlined;
    case 'personal care':
      return Icons.spa;
    case 'subscriptions':
    case 'entertainment':
      return Icons.subscriptions;
    case 'education':
      return Icons.local_library;
    case 'tuition & fees':
    case 'exam fees':
      return Icons.assignment_outlined;
    case 'courses & training':
      return Icons.workspace_premium_outlined;
    case 'books & supplies':
      return Icons.menu_book_outlined;
    case 'school transport':
      return Icons.directions_bus_outlined;
    case 'gifts & rewards':
    case 'gifts':
      return Icons.card_giftcard;
    case 'zakat':
    case 'charity':
      return Icons.volunteer_activism;
    case 'misc':
    case 'others':
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
    case 'business':
      return Colors.indigo;
    case 'tax':
    case 'taxes':
      return Colors.deepOrange;
    case 'health':
      return Colors.red;
    case 'food & drinks':
    case 'food':
      return Colors.amber.shade800;
    case 'shopping':
      return Colors.purple;
    case 'housing & utils':
    case 'bills':
      return Colors.blueGrey;
    case 'rent':
      return Colors.brown;
    case 'transport':
    case 'travel':
      return Colors.cyan.shade800;
    case 'personal care':
      return Colors.pink;
    case 'subscriptions':
    case 'entertainment':
      return Colors.blue;
    case 'gifts & rewards':
    case 'gifts':
      return const Color(0xFF0F6B57);
    case 'zakat':
    case 'charity':
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

class _TopCategoryCharts extends StatelessWidget {
  const _TopCategoryCharts({required this.transactions});

  final List<entity.Transaction> transactions;

  List<_CategoryTotal> _topCategories({required bool isExpense}) {
    final totals = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.isExpense != isExpense) continue;
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final ranked =
        totals.entries
            .map((entry) => _CategoryTotal(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return ranked.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final income = _topCategories(isExpense: false);
    final expenses = _topCategories(isExpense: true);
    final totalActivity = transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount.abs(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Top Categories',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Top five categories based on range. Percentages show each category’s share of total activity.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            _TopCategoryLollipopChart(
              incomeItems: income,
              expenseItems: expenses,
              totalActivity: totalActivity,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCategoryLollipopChart extends StatelessWidget {
  const _TopCategoryLollipopChart({
    required this.incomeItems,
    required this.expenseItems,
    required this.totalActivity,
  });

  final List<_CategoryTotal> incomeItems;
  final List<_CategoryTotal> expenseItems;
  final double totalActivity;

  @override
  Widget build(BuildContext context) {
    final rankedItems = <_CategoryChartBar>[
      for (final item in incomeItems)
        _CategoryChartBar(
          category: item.category,
          total: item.total,
          isExpense: false,
        ),
      for (final item in expenseItems)
        _CategoryChartBar(
          category: item.category,
          total: item.total,
          isExpense: true,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    final items = rankedItems.take(5).toList();
    final incomeColor = Colors.green.shade600;
    final expenseColor = Colors.red.shade600;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 8,
              children: [
                _ChartLegend(label: 'Income', color: incomeColor),
                _ChartLegend(label: 'Expense', color: expenseColor),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const SizedBox(
                height: 160,
                child: Center(child: Text('No transactions for this period')),
              )
            else
              Column(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == items.length - 1 ? 0 : 14,
                      ),
                      child: _HorizontalCategoryLollipop(
                        item: items[index],
                        totalActivity: totalActivity,
                        color: items[index].isExpense
                            ? expenseColor
                            : incomeColor,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalCategoryLollipop extends StatelessWidget {
  const _HorizontalCategoryLollipop({
    required this.item,
    required this.totalActivity,
    required this.color,
  });

  final _CategoryChartBar item;
  final double totalActivity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = categoryShareOfActivity(item.total, totalActivity);
    final percentage = fraction * 100;
    final percentageLabel = _formatChartPercentage(percentage);
    final type = item.isExpense ? 'Expense' : 'Income';

    return Semantics(
      label:
          '${item.category}, $type, ${_formatDashboardMoney(item.total)}, $percentageLabel of total activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatDashboardMoney(item.total),
                    maxLines: 1,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              const markerSize = 36.0;
              final markerCenter = constraints.maxWidth * fraction;
              final markerLeft = (markerCenter - markerSize / 2)
                  .clamp(0.0, constraints.maxWidth - markerSize)
                  .toDouble();
              final activeLineWidth = markerCenter
                  .clamp(item.total > 0 ? 1.0 : 0.0, constraints.maxWidth)
                  .toDouble();

              return SizedBox(
                height: markerSize,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 16,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 16,
                      width: activeLineWidth,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: markerLeft,
                      top: 0,
                      width: markerSize,
                      height: markerSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.24),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                percentageLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CategoryChartBar {
  const _CategoryChartBar({
    required this.category,
    required this.total,
    required this.isExpense,
  });

  final String category;
  final double total;
  final bool isExpense;
}

class _CategoryTotal {
  const _CategoryTotal(this.category, this.total);

  final String category;
  final double total;
}

double categoryShareOfActivity(double categoryTotal, double totalActivity) {
  if (categoryTotal <= 0 || totalActivity <= 0) return 0;
  return (categoryTotal / totalActivity).clamp(0.0, 1.0).toDouble();
}

String _formatChartPercentage(double percentage) {
  if (percentage > 0 && percentage < 0.1) return '<0.1%';
  if (percentage < 10) return '${percentage.toStringAsFixed(1)}%';
  return '${percentage.toStringAsFixed(0)}%';
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
          initialIsExpense: categoryPreferences.isDualMode(category)
              ? null
              : categoryPreferences.isExpense(category),
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
                  isExpense: categoryPreferences
                      .resolveTransactionTypeForCategory(
                        categoryName: category,
                        transactionIsExpense: transaction.isExpense,
                      ),
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
                filterLabel: 'Selected transactions',
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
