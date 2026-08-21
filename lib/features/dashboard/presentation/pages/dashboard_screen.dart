import 'dart:io';
import 'dart:math' as math;

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
import 'package:fbr_tax_helper/core/database/tax_database.dart';
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
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  TransactionTypeFilter _transactionFilter = TransactionTypeFilter.income;
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
    const titles = ['Dashboard', 'Transactions', 'Settings', 'More'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_selectedIndex])),
      body: ListenableBuilder(
        listenable: _categoryPreferences,
        builder: (context, _) => IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeDashboard(categoryPreferences: _categoryPreferences),
            _TransactionsPage(
              categoryPreferences: _categoryPreferences,
              filter: _transactionFilter,
              onFilterChanged: (filter) {
                setState(() => _transactionFilter = filter);
              },
            ),
            _CategorySettingsPage(categoryPreferences: _categoryPreferences),
            const _MorePage(),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'open-comparison-dashboard',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _ComparisonDashboardPage(
                      categoryPreferences: _categoryPreferences,
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Comparison'),
            )
          : null,
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

enum TransactionTypeFilter { income, expense, both }

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({
    required this.categoryPreferences,
    required this.filter,
    required this.onFilterChanged,
  });

  final CategoryPreferencesService categoryPreferences;
  final TransactionTypeFilter filter;
  final ValueChanged<TransactionTypeFilter> onFilterChanged;

  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  void _openParentTransaction(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          parentCategory: parentCategory,
          categoryOptions: categoryOptions,
          onViewCategoryHistory: (category) {
            Navigator.of(this.context).push(
              MaterialPageRoute(
                builder: (context) => _AllTransactionsPage(
                  categoryPreferences: widget.categoryPreferences,
                  initialCategory: category,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isVisible(TransactionCategory category) {
    if (!widget.categoryPreferences.isEnabled(category.name)) return false;
    return switch (widget.filter) {
      TransactionTypeFilter.income =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: false,
        ),
      TransactionTypeFilter.expense =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: true,
        ),
      TransactionTypeFilter.both => widget.categoryPreferences.isDualMode(
        category.name,
      ),
    };
  }

  List<_TransactionCategoryCardData> _visibleCategoryCards() {
    return TransactionCategory.hierarchy.entries.expand((superCategory) {
      return superCategory.value.entries
          .map(
            (parent) => _TransactionCategoryCardData(
              groupName: superCategory.key,
              categoryName: parent.key,
              options: parent.value.where(_isVisible).toList(),
            ),
          )
          .where((card) => card.options.isNotEmpty);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categoryCards = _visibleCategoryCards();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionTypeFilter>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TransactionTypeFilter.income,
                label: Text('Income'),
              ),
              ButtonSegment(
                value: TransactionTypeFilter.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: TransactionTypeFilter.both,
                label: Text('Both'),
              ),
            ],
            selected: {widget.filter},
            onSelectionChanged: (selection) {
              widget.onFilterChanged(selection.first);
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: LayoutBuilder(
              key: ValueKey(widget.filter),
              builder: (context, constraints) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryCards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth < 360 ? 1.12 : 1.3,
                ),
                itemBuilder: (context, index) {
                  final card = categoryCards[index];
                  return _AnimatedTransactionCategoryCard(
                    key: ValueKey('${widget.filter.name}-${card.categoryName}'),
                    data: card,
                    index: index,
                    onTap: () =>
                        _openParentTransaction(card.categoryName, card.options),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCategoryCardData {
  const _TransactionCategoryCardData({
    required this.groupName,
    required this.categoryName,
    required this.options,
  });

  final String groupName;
  final String categoryName;
  final List<TransactionCategory> options;
}

class _AnimatedTransactionCategoryCard extends StatefulWidget {
  const _AnimatedTransactionCategoryCard({
    super.key,
    required this.data,
    required this.index,
    required this.onTap,
  });

  final _TransactionCategoryCardData data;
  final int index;
  final VoidCallback onTap;

  @override
  State<_AnimatedTransactionCategoryCard> createState() =>
      _AnimatedTransactionCategoryCardState();
}

class _AnimatedTransactionCategoryCardState
    extends State<_AnimatedTransactionCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(widget.data.categoryName);
    final accent = HSLColor.fromColor(
      color,
    ).withHue((HSLColor.fromColor(color).hue + 28) % 360).toColor();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (widget.index % 6) * 45),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: _pressed ? 0.24 : 0.17),
                accent.withValues(alpha: _pressed ? 0.18 : 0.09),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _pressed ? 0.12 : 0.2),
                blurRadius: _pressed ? 7 : 14,
                offset: Offset(0, _pressed ? 3 : 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    top: -20,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, accent],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getIconForCategory(widget.data.categoryName),
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 20,
                              color: color,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.data.groupName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.data.categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
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
    );
  }
}

enum _TransactionDateFilter { all, month, range }

class _AllTransactionsPage extends StatefulWidget {
  const _AllTransactionsPage({
    required this.categoryPreferences,
    this.initialCategory,
  });

  final CategoryPreferencesService categoryPreferences;
  final String? initialCategory;

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
      if (widget.initialCategory != null &&
          transaction.category != widget.initialCategory) {
        return false;
      }
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
    final category = widget.initialCategory;
    // The report uses the PDF package's built-in font, which does not include
    // the bullet glyph. Keep this label ASCII so it renders correctly in print.
    return '${category ?? 'All transactions'} - $period';
  }

  Widget _rangeDateField({required bool isStart}) {
    final value = isStart ? _rangeStart : _rangeEnd;
    return TextFormField(
      key: ValueKey(
        '${isStart ? 'range_start' : 'range_end'}_'
        '${value?.millisecondsSinceEpoch ?? 'empty'}',
      ),
      readOnly: true,
      initialValue: value == null
          ? ''
          : DateFormat('dd MMM yyyy').format(value),
      decoration: InputDecoration(
        labelText: isStart ? 'From' : 'To',
        hintText: 'Select date',
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () => _pickRangeDate(isStart: isStart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialCategory ?? 'All Transactions')),
      body: SafeArea(
        top: false,
        child: BlocBuilder<TransactionBloc, TransactionState>(
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
                    onChanged: (month) =>
                        setState(() => _selectedMonth = month),
                  ),
                ],
                if (_dateFilter == _TransactionDateFilter.range) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 430) {
                        return Column(
                          children: [
                            _rangeDateField(isStart: true),
                            const SizedBox(height: 10),
                            _rangeDateField(isStart: false),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _rangeDateField(isStart: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _rangeDateField(isStart: false)),
                        ],
                      );
                    },
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = Text(
                      '${visibleTransactions.length} transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    final printButton = _PrintTransactionsButton(
                      transactions: visibleTransactions,
                      filterLabel: _filterLabel(),
                      buttonLabel: 'Print',
                    );
                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          count,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: printButton,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: count),
                        printButton,
                      ],
                    );
                  },
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
                      builder: (context) => const _SupportPage(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 30),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const _AboutPage()),
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

class _SupportPage extends StatelessWidget {
  const _SupportPage();

  static const _supportEmail = 'kpxdigital@gmail.com';

  Future<void> _contactSupport(BuildContext context) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      //queryParameters: const {'subject': 'Support related to Filer Flow'},
      query: 'subject=${Uri.encodeComponent('Support related to Filer Flow')}',
    );

    final opened = await launchUrl(emailUri);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not open an email application.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Support')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewPadding = MediaQuery.viewPaddingOf(context);
          final isCompact = constraints.maxHeight < 650;
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          final bottomPadding = viewPadding.bottom + 24;
          final topPadding = isCompact ? 16.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding + viewPadding.left,
              topPadding,
              horizontalPadding + viewPadding.right,
              bottomPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - topPadding - bottomPadding,
                ),
              ),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/kpxdigitalgrey.png',
                            width: isCompact ? 130 : 155,
                            height: isCompact ? 44 : 54,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: isCompact ? 14 : 20),
                        Text(
                          'How can we help?',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Questions or problems with Filer Flow? Send our '
                          'support team a message and we will get back to you.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                        SizedBox(height: isCompact ? 18 : 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.mintSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Email support',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(
                                      _supportEmail,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(height: isCompact ? 20 : 32),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: () => _contactSupport(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.send_outlined, size: 19),
                            label: const Text(
                              'Contact support',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  static const _features = [
    'Visual dashboard with income, expense and balance overview',
    'Quick transaction entry — manually or via receipt scan',
    'Customizable income and expense categories',
    'Built-in tax calculator for Salary, PSEB Export and WHT',
    'Secure backup and restore via Google Drive',
    'Fingerprint-secured profile with 2FA',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('About Filer Flow')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewPadding = MediaQuery.viewPaddingOf(context);
          final isCompact = constraints.maxHeight < 720;
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          final verticalPadding = isCompact ? 14.0 : 22.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding + viewPadding.left,
              verticalPadding,
              horizontalPadding + viewPadding.right,
              viewPadding.bottom + verticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/kpxdigitalgrey.png',
                        width: isCompact ? 120 : 145,
                        height: isCompact ? 42 : 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 14),
                    Text(
                      'Personal finance and tax tools in one secure place.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    SizedBox(height: isCompact ? 16 : 22),
                    Text(
                      'Key features',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, contentConstraints) {
                        final columns = contentConstraints.maxWidth >= 540
                            ? 2
                            : 1;
                        final itemWidth = columns == 2
                            ? (contentConstraints.maxWidth - 20) / 2
                            : contentConstraints.maxWidth;

                        return Wrap(
                          spacing: 20,
                          runSpacing: isCompact ? 6 : 8,
                          children: [
                            for (final feature in _features)
                              SizedBox(
                                width: itemWidth,
                                child: _AboutFeature(
                                  label: feature,
                                  compact: isCompact,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isCompact ? 12 : 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 21,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your data stays on your device. You decide when '
                              'and where it is backed up.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.primaryDark,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 12 : 18),
                    Text.rich(
                      TextSpan(
                        text: 'Version 1.0  |  Developed by ',
                        children: [
                          TextSpan(
                            text: 'KPX Digital',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: compact ? 16 : 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ),
      ],
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
                  'Category Settings',
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
  bool _isDeletingAccount = false;
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

  Future<void> _removeAccount() async {
    if (_isDeletingAccount) return;
    final user = _authService.currentUser;
    if (user == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            title: const Text('Remove account permanently?'),
            content: const Text(
              'This permanently deletes your Filer Flow account and removes its local transactions, receipts, preferences, and profile data from this device. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove account'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      final providers = user.providerData
          .map((info) => info.providerId)
          .toSet();
      if (providers.contains('password')) {
        final password = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _ConfirmPasswordDialog(),
        );
        if (password == null) {
          throw const AuthServiceException('Account removal was canceled.');
        }
        await _authService.reauthenticateCurrentUserWithPassword(password);
      } else if (providers.contains('google.com')) {
        await _authService.reauthenticateCurrentUserWithGoogle();
      }

      final userId = user.uid;
      final profileImagePath = await _profileStorage.read(
        key: _profileImageKey,
      );
      await _authService.deleteCurrentUser();
      await _deleteLocalAccountData(userId, profileImagePath);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove account: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove account: $error')),
      );
    }
  }

  Future<void> _deleteLocalAccountData(
    String userId,
    String? profileImagePath,
  ) async {
    await TaxDatabase.instance.deleteDataForUser(userId);
    await Future.wait([
      _profileStorage.delete(key: 'profile_image_$userId'),
      _profileStorage.delete(key: 'pending_email_$userId'),
      _profileStorage.delete(key: 'biometric_lock_enabled_$userId'),
      _profileStorage.delete(key: 'category_preferences_$userId'),
      _profileStorage.delete(key: 'CACHED_TAX_PROFILE'),
      _profileStorage.delete(key: 'terms_license_v1_accepted_$userId'),
    ]);
    if (profileImagePath != null) {
      final profileImage = File(profileImagePath);
      if (await profileImage.exists()) await profileImage.delete();
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
      body: SafeArea(
        top: false,
        child: ListView(
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
                            onPressed: _isPickingImage
                                ? null
                                : _pickProfileImage,
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
                    subtitle: const Text(
                      'Receive a secure password reset email',
                    ),
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
                  const Divider(height: 1),
                  ListTile(
                    leading: _isDeletingAccount
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.person_remove_outlined,
                            color: Colors.red.shade700,
                          ),
                    title: Text(
                      _isDeletingAccount
                          ? 'Removing account…'
                          : 'Remove account',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text('Permanently delete your account'),
                    onTap: _isDeletingAccount || _isUpdatingProfile
                        ? null
                        : _removeAccount,
                  ),
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
      title: const Text('Edit Profile'),
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
                    _TopCategoryCharts(
                      transactions: visibleTransactions,
                      onCategoryTap: (category) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => _AllTransactionsPage(
                              categoryPreferences: widget.categoryPreferences,
                              initialCategory: category,
                            ),
                          ),
                        );
                      },
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
      return Icons.bolt_rounded;
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
      return Icons.school_rounded;
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
    case 'banking':
      return Icons.account_balance_wallet_rounded;
    case 'others':
      return Icons.widgets_rounded;
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
      return const Color(0xFF2563EB);
    case 'rent':
      return Colors.brown;
    case 'transport':
    case 'travel':
      return const Color(0xFF0891B2);
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
    case 'banking':
      return const Color(0xFF4F46E5);
    case 'others':
      return const Color(0xFF64748B);
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
  const _TopCategoryCharts({
    required this.transactions,
    required this.onCategoryTap,
  });

  final List<entity.Transaction> transactions;
  final ValueChanged<String> onCategoryTap;

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
              'Top five categories based on range. Tap a category to view all of its transactions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            _TopCategoryLollipopChart(
              incomeItems: income,
              expenseItems: expenses,
              totalActivity: totalActivity,
              onCategoryTap: onCategoryTap,
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
    required this.onCategoryTap,
  });

  final List<_CategoryTotal> incomeItems;
  final List<_CategoryTotal> expenseItems;
  final double totalActivity;
  final ValueChanged<String> onCategoryTap;

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
                        onTap: () => onCategoryTap(items[index].category),
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
    required this.onTap,
  });

  final _CategoryChartBar item;
  final double totalActivity;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = categoryShareOfActivity(item.total, totalActivity);
    final percentage = fraction * 100;
    final percentageLabel = _formatChartPercentage(percentage);
    final type = item.isExpense ? 'Expense' : 'Income';

    return Semantics(
      button: true,
      label:
          '${item.category}, $type, ${_formatDashboardMoney(item.total)}, $percentageLabel of total activity',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDashboardMoney(item.total),
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
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
          ),
        ),
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

List<entity.Transaction> filterTransactionsForSelection(
  List<entity.Transaction> transactions,
  TransactionTypeFilter filter,
  CategoryPreferencesService categoryPreferences,
) {
  return transactions.where((transaction) {
    final isDualMode = categoryPreferences.isDualMode(transaction.category);
    return switch (filter) {
      TransactionTypeFilter.income => !isDualMode && !transaction.isExpense,
      TransactionTypeFilter.expense => !isDualMode && transaction.isExpense,
      TransactionTypeFilter.both => isDualMode,
    };
  }).toList();
}

String _transactionFilterLabel(DateTime? selectedMonth) {
  final periodLabel = selectedMonth == null
      ? 'All dates'
      : DateFormat('MMMM yyyy').format(selectedMonth);
  // Keep printable filter labels ASCII; the PDF's default font lacks bullets.
  return 'All transactions - $periodLabel';
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

enum _ComparisonScope { overall, category }

class _ComparisonDashboardPage extends StatefulWidget {
  const _ComparisonDashboardPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_ComparisonDashboardPage> createState() =>
      _ComparisonDashboardPageState();
}

class _ComparisonDashboardPageState extends State<_ComparisonDashboardPage> {
  final _ComparisonScope _scope = _ComparisonScope.overall;
  String? _selectedCategory;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // ignore: unused_element
  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _rangeStart : _rangeEnd;
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: isStart ? 'Select Start Date' : 'Select End Date',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: current == null
          ? (isStart
                ? const TimeOfDay(hour: 0, minute: 0)
                : const TimeOfDay(hour: 23, minute: 59))
          : TimeOfDay.fromDateTime(current),
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
    );
    if (pickedTime == null || !mounted) return;

    final result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!isStart && _rangeStart != null && result.isBefore(_rangeStart!)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
      return;
    }

    setState(() {
      if (isStart) {
        _rangeStart = result;
        if (_rangeEnd != null && _rangeEnd!.isBefore(result)) {
          _rangeEnd = null;
        }
      } else {
        _rangeEnd = result;
      }
    });
  }

  List<entity.Transaction> _applyComparisonFilters(
    List<entity.Transaction> transactions,
  ) {
    return transactions.where((transaction) {
      if (_scope == _ComparisonScope.category &&
          transaction.category != _selectedCategory) {
        return false;
      }
      if (_rangeStart != null && transaction.date.isBefore(_rangeStart!)) {
        return false;
      }
      if (_rangeEnd != null && transaction.date.isAfter(_rangeEnd!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparison Dashboard'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.categoryPreferences,
          builder: (context, _) =>
              BlocBuilder<TransactionBloc, TransactionState>(
                builder: (context, state) {
                  final storedTransactions =
                      state is TransactionLoaded &&
                          state.userId == currentUserId
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
                  final filteredTransactions = _applyComparisonFilters(
                    transactions,
                  );

                  return _ReferenceComparisonDashboard(
                    transactions: filteredTransactions,
                  );
                },
              ),
        ),
      ),
    );
  }
}

// Legacy chart types are retained for compatibility with the older dashboard.
// ignore: unused_field
enum _ComparisonDisplay { statement, trend }

enum _ComparisonRange { week, month, quarter }

class _ReferenceComparisonDashboard extends StatefulWidget {
  const _ReferenceComparisonDashboard({required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  State<_ReferenceComparisonDashboard> createState() =>
      _ReferenceComparisonDashboardState();
}

class _ReferenceComparisonDashboardState
    extends State<_ReferenceComparisonDashboard> {
  static const _accent = Color(0xFF168C91);
  _SelectableComparisonMode _mode = _SelectableComparisonMode.month;
  DateTime? _firstMonth;
  DateTime? _secondMonth;
  int? _firstYear;
  int? _secondYear;

  @override
  Widget build(BuildContext context) {
    final months = _availableComparisonMonths(widget.transactions);
    final years = _availableComparisonYears(widget.transactions);
    final firstMonth = _effectiveSelection(_firstMonth, months, 0);
    final secondMonth = _effectiveSelection(_secondMonth, months, 1);
    final firstYear = _effectiveSelection(_firstYear, years, 0);
    final secondYear = _effectiveSelection(_secondYear, years, 1);
    final isMonth = _mode == _SelectableComparisonMode.month;
    final firstLabel = isMonth
        ? _monthComparisonLabel(firstMonth)
        : (firstYear?.toString() ?? 'No year');
    final secondLabel = isMonth
        ? _monthComparisonLabel(secondMonth)
        : (secondYear?.toString() ?? 'No year');
    final firstTransactions = _transactionsForComparisonPeriod(
      widget.transactions,
      mode: _mode,
      month: firstMonth,
      year: firstYear,
    );
    final secondTransactions = _transactionsForComparisonPeriod(
      widget.transactions,
      mode: _mode,
      month: secondMonth,
      year: secondYear,
    );

    return ColoredBox(
      color: const Color(0xFFF2F4F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ComparisonSwitch<_SelectableComparisonMode>(
                  values: const [
                    (_SelectableComparisonMode.month, 'Month'),
                    (_SelectableComparisonMode.year, 'Year'),
                  ],
                  selected: _mode,
                  selectedColor: _accent,
                  height: 58,
                  onChanged: (value) => setState(() => _mode = value),
                ),
                const SizedBox(height: 24),
                Text(
                  isMonth ? 'Select two months' : 'Select two years',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final selectors = isMonth
                        ? <Widget>[
                            _ComparisonDropdown<DateTime>(
                              label: 'First month',
                              value: firstMonth,
                              values: months,
                              itemLabel: (value) =>
                                  DateFormat('MMMM yyyy').format(value),
                              onChanged: (value) =>
                                  setState(() => _firstMonth = value),
                            ),
                            _ComparisonDropdown<DateTime>(
                              label: 'Second month',
                              value: secondMonth,
                              values: months,
                              itemLabel: (value) =>
                                  DateFormat('MMMM yyyy').format(value),
                              onChanged: (value) =>
                                  setState(() => _secondMonth = value),
                            ),
                          ]
                        : <Widget>[
                            _ComparisonDropdown<int>(
                              label: 'First year',
                              value: firstYear,
                              values: years,
                              itemLabel: (value) => value.toString(),
                              onChanged: (value) =>
                                  setState(() => _firstYear = value),
                            ),
                            _ComparisonDropdown<int>(
                              label: 'Second year',
                              value: secondYear,
                              values: years,
                              itemLabel: (value) => value.toString(),
                              onChanged: (value) =>
                                  setState(() => _secondYear = value),
                            ),
                          ];
                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: [
                          selectors.first,
                          const SizedBox(height: 12),
                          selectors.last,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: selectors.first),
                        const SizedBox(width: 12),
                        Expanded(child: selectors.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _SelectableComparisonLegend(
                  firstLabel: firstLabel,
                  secondLabel: secondLabel,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _SelectableComparisonChart(
                    key: ValueKey(
                      'comparison-${_mode.name}-$firstMonth-$secondMonth-$firstYear-$secondYear',
                    ),
                    firstValues: _comparisonSeries(
                      widget.transactions,
                      mode: _mode,
                      month: firstMonth,
                      year: firstYear,
                    ),
                    secondValues: _comparisonSeries(
                      widget.transactions,
                      mode: _mode,
                      month: secondMonth,
                      year: secondYear,
                    ),
                    firstLabel: firstLabel,
                    secondLabel: secondLabel,
                    mode: _mode,
                  ),
                ),
                const SizedBox(height: 18),
                _ComparisonTotalsSummary(
                  firstLabel: firstLabel,
                  secondLabel: secondLabel,
                  firstTransactions: firstTransactions,
                  secondTransactions: secondTransactions,
                ),
                const SizedBox(height: 14),
                _PrintComparisonButton(
                  firstTransactions: firstTransactions,
                  secondTransactions: secondTransactions,
                  firstLabel: firstLabel,
                  secondLabel: secondLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SelectableComparisonMode { month, year }

T? _effectiveSelection<T>(T? selected, List<T> values, int fallbackIndex) {
  if (selected != null && values.contains(selected)) return selected;
  if (values.isEmpty) return null;
  return values[math.min(fallbackIndex, values.length - 1)];
}

List<DateTime> _availableComparisonMonths(
  List<entity.Transaction> transactions,
) {
  final values =
      transactions
          .map(
            (transaction) =>
                DateTime(transaction.date.year, transaction.date.month),
          )
          .toSet()
          .toList()
        ..sort((left, right) => right.compareTo(left));
  return values;
}

List<int> _availableComparisonYears(List<entity.Transaction> transactions) {
  final values =
      transactions.map((transaction) => transaction.date.year).toSet().toList()
        ..sort((left, right) => right.compareTo(left));
  return values;
}

String _monthComparisonLabel(DateTime? month) {
  return month == null ? 'No month' : DateFormat('MMM yyyy').format(month);
}

List<entity.Transaction> _transactionsForComparisonPeriod(
  List<entity.Transaction> transactions, {
  required _SelectableComparisonMode mode,
  DateTime? month,
  int? year,
}) {
  return transactions.where((transaction) {
    if (mode == _SelectableComparisonMode.month) {
      return month != null &&
          transaction.date.year == month.year &&
          transaction.date.month == month.month;
    }
    return year != null && transaction.date.year == year;
  }).toList();
}

class _ComparisonPeriodTotals {
  const _ComparisonPeriodTotals({
    required this.activity,
    required this.balance,
  });

  factory _ComparisonPeriodTotals.from(List<entity.Transaction> transactions) {
    var income = 0.0;
    var expenses = 0.0;
    for (final transaction in transactions) {
      if (transaction.isExpense) {
        expenses += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }
    return _ComparisonPeriodTotals(
      activity: income + expenses,
      balance: income - expenses,
    );
  }

  final double activity;
  final double balance;
}

class _ComparisonTotalsSummary extends StatelessWidget {
  const _ComparisonTotalsSummary({
    required this.firstLabel,
    required this.secondLabel,
    required this.firstTransactions,
    required this.secondTransactions,
  });

  final String firstLabel;
  final String secondLabel;
  final List<entity.Transaction> firstTransactions;
  final List<entity.Transaction> secondTransactions;

  @override
  Widget build(BuildContext context) {
    final first = _ComparisonPeriodTotals.from(firstTransactions);
    final second = _ComparisonPeriodTotals.from(secondTransactions);
    final difference = second.activity - first.activity;
    final balanceDifference = second.balance - first.balance;
    final differenceColor = difference >= 0
        ? AppColors.primary
        : AppColors.coral;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Comparison result',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ComparisonTotalCell(
                  label: firstLabel,
                  value: _formatComparisonMoney(first.activity),
                  color: const Color(0xFF16194F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComparisonTotalCell(
                  label: secondLabel,
                  value: _formatComparisonMoney(second.activity),
                  color: const Color(0xFF168C91),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Difference',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatComparisonMoney(difference, signed: true),
                      style: TextStyle(
                        color: differenceColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Balance change\n${_formatComparisonMoney(balanceDifference, signed: true)}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$secondLabel minus $firstLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTotalCell extends StatelessWidget {
  const _ComparisonTotalCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintComparisonButton extends StatefulWidget {
  const _PrintComparisonButton({
    required this.firstTransactions,
    required this.secondTransactions,
    required this.firstLabel,
    required this.secondLabel,
  });

  final List<entity.Transaction> firstTransactions;
  final List<entity.Transaction> secondTransactions;
  final String firstLabel;
  final String secondLabel;

  @override
  State<_PrintComparisonButton> createState() => _PrintComparisonButtonState();
}

class _PrintComparisonButtonState extends State<_PrintComparisonButton> {
  bool _isPrinting = false;

  Future<void> _print() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await const TransactionReportService().printComparisonReport(
        firstTransactions: widget.firstTransactions,
        secondTransactions: widget.secondTransactions,
        firstLabel: widget.firstLabel,
        secondLabel: widget.secondLabel,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not prepare the comparison report: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData =
        widget.firstTransactions.isNotEmpty ||
        widget.secondTransactions.isNotEmpty;
    return FilledButton.icon(
      onPressed: hasData && !_isPrinting ? _print : null,
      icon: _isPrinting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.print_outlined),
      label: Text(
        hasData ? 'Print comparison report' : 'No comparison data to print',
      ),
    );
  }
}

String _formatComparisonMoney(double value, {bool signed = false}) {
  if (!signed) return 'PKR ${NumberFormat('#,##0.00').format(value)}';
  final sign = value > 0 ? '+' : (value < 0 ? '-' : '');
  return 'PKR $sign${NumberFormat('#,##0.00').format(value.abs())}';
}

class _ComparisonDropdown<T> extends StatelessWidget {
  const _ComparisonDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month_outlined),
        fillColor: Colors.white,
      ),
      hint: Text(values.isEmpty ? 'No transaction data' : 'Select'),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: values.isEmpty ? null : onChanged,
    );
  }
}

class _SelectableComparisonLegend extends StatelessWidget {
  const _SelectableComparisonLegend({
    required this.firstLabel,
    required this.secondLabel,
  });

  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        _PeriodLegendItem(color: const Color(0xFF16194F), label: firstLabel),
        _PeriodLegendItem(color: const Color(0xFF168C91), label: secondLabel),
      ],
    );
  }
}

class _SelectableComparisonChart extends StatelessWidget {
  const _SelectableComparisonChart({
    super.key,
    required this.firstValues,
    required this.secondValues,
    required this.firstLabel,
    required this.secondLabel,
    required this.mode,
  });

  final List<double> firstValues;
  final List<double> secondValues;
  final String firstLabel;
  final String secondLabel;
  final _SelectableComparisonMode mode;

  @override
  Widget build(BuildContext context) {
    final highest = [...firstValues, ...secondValues].fold<double>(0, math.max);
    final maxY = _roundedComparisonMaximum(highest);
    final interval = maxY / 6;
    final pointCount = math.max(firstValues.length, secondValues.length);

    return Container(
      height: 330,
      padding: const EdgeInsets.fromLTRB(12, 24, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, pointCount - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFE8ECEE), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: _selectableComparisonTitles(mode, interval, pointCount),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF25275C),
              getTooltipItems: (spots) => spots.map((spot) {
                final label = spot.barIndex == 0 ? firstLabel : secondLabel;
                return LineTooltipItem(
                  '$label\nPKR ${NumberFormat.compact().format(spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            _selectableComparisonLine(firstValues, const Color(0xFF16194F)),
            _selectableComparisonLine(secondValues, const Color(0xFF168C91)),
          ],
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

LineChartBarData _selectableComparisonLine(List<double> values, Color color) {
  return LineChartBarData(
    spots: values.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), entry.$2))
        .toList(),
    color: color,
    barWidth: 3.5,
    isCurved: true,
    curveSmoothness: 0.2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: values.length <= 12),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.06)),
  );
}

FlTitlesData _selectableComparisonTitles(
  _SelectableComparisonMode mode,
  double interval,
  int pointCount,
) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 78,
        interval: interval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          axisSide: meta.axisSide,
          space: 6,
          child: Text(
            NumberFormat('#,##0').format(value),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (value != index || index < 0 || index >= pointCount) {
            return const SizedBox.shrink();
          }
          final day = index + 1;
          final isLastPoint = index == pointCount - 1;
          final hasRoomBeforeLast = pointCount - day >= 3;
          final show = mode == _SelectableComparisonMode.year
              ? true
              : index == 0 ||
                    isLastPoint ||
                    (day % 5 == 0 && hasRoomBeforeLast);
          if (!show) return const SizedBox.shrink();
          final label = mode == _SelectableComparisonMode.year
              ? DateFormat('MMM').format(DateTime(2020, index + 1))
              : '${index + 1}';
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 9,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.ink),
            ),
          );
        },
      ),
    ),
  );
}

List<double> _comparisonSeries(
  List<entity.Transaction> transactions, {
  required _SelectableComparisonMode mode,
  DateTime? month,
  int? year,
}) {
  if (mode == _SelectableComparisonMode.month) {
    if (month == null) return const [];
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final values = List<double>.filled(days, 0);
    for (final transaction in transactions) {
      if (transaction.date.year == month.year &&
          transaction.date.month == month.month) {
        values[transaction.date.day - 1] += transaction.amount;
      }
    }
    return values;
  }

  if (year == null) return const [];
  final values = List<double>.filled(12, 0);
  for (final transaction in transactions) {
    if (transaction.date.year == year) {
      values[transaction.date.month - 1] += transaction.amount;
    }
  }
  return values;
}

class _ComparisonSwitch<T> extends StatelessWidget {
  const _ComparisonSwitch({
    required this.values,
    required this.selected,
    required this.selectedColor,
    required this.height,
    required this.onChanged,
    this.separated = false,
  });

  final List<(T, String)> values;
  final T selected;
  final Color selectedColor;
  final double height;
  final ValueChanged<T> onChanged;
  final bool separated;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(separated ? 0 : 5),
      decoration: separated
          ? null
          : BoxDecoration(
              color: const Color(0xFFE7EBEC),
              borderRadius: BorderRadius.circular(18),
            ),
      child: Row(
        children: values.indexed.expand((entry) {
          final item = entry.$2;
          final isSelected = item.$1 == selected;
          final button = Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: Material(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(item.$1),
                  child: Center(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF161A1D),
                        fontSize: separated ? 16 : 17,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          return [
            button,
            if (separated && entry.$1 < values.length - 1)
              const SizedBox(width: 14),
          ];
        }).toList(),
      ),
    );
  }
}

// ignore: unused_element
class _ComparisonPlotCard extends StatelessWidget {
  // ignore: unused_element_parameter
  const _ComparisonPlotCard({
    // ignore: unused_element_parameter
    super.key,
    required this.buckets,
    required this.display,
    required this.lineColor,
  });

  final List<_ReferenceComparisonBucket> buckets;
  final _ComparisonDisplay display;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final highest = buckets.fold<double>(
      0,
      (value, bucket) => math.max(
        value,
        display == _ComparisonDisplay.trend
            ? bucket.activity
            : math.max(bucket.income, bucket.expense),
      ),
    );
    final maxY = _roundedComparisonMaximum(highest);
    final interval = maxY / 6;

    return Container(
      height: 315,
      padding: const EdgeInsets.fromLTRB(14, 24, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: display == _ComparisonDisplay.trend
          ? LineChart(
              LineChartData(
                minX: 0,
                maxX: (buckets.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: _referenceComparisonTitles(buckets, interval),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF25275C),
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            'PKR ${NumberFormat.compact().format(spot.y)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: buckets.indexed
                        .map(
                          (entry) =>
                              FlSpot(entry.$1.toDouble(), entry.$2.activity),
                        )
                        .toList(),
                    color: lineColor,
                    barWidth: 4,
                    isCurved: true,
                    curveSmoothness: 0.22,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: Colors.white,
                            strokeWidth: 4,
                            strokeColor: lineColor,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF95B2C7).withValues(alpha: 0.42),
                          const Color(0xFF95B2C7).withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            )
          : BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: _referenceComparisonTitles(buckets, interval),
                barGroups: buckets.indexed
                    .map(
                      (entry) => BarChartGroupData(
                        x: entry.$1,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: entry.$2.income,
                            width: 8,
                            color: const Color(0xFF168C91),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: entry.$2.expense,
                            width: 8,
                            color: const Color(0xFF16194F),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

FlTitlesData _referenceComparisonTitles(
  List<_ReferenceComparisonBucket> buckets,
  double interval,
) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        interval: interval,
        getTitlesWidget: (value, meta) {
          if (value == meta.max) return const SizedBox.shrink();
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 7,
            child: Text(
              _compactChartAmount(value),
              style: const TextStyle(color: Color(0xFF555B60), fontSize: 12),
            ),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 38,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (value != index || index < 0 || index >= buckets.length) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 10,
            child: Text(
              DateFormat('dd/MM').format(buckets[index].date),
              style: const TextStyle(color: Color(0xFF33383C), fontSize: 11),
            ),
          );
        },
      ),
    ),
  );
}

class _ReferenceComparisonBucket {
  _ReferenceComparisonBucket(this.date);

  final DateTime date;
  double income = 0;
  double expense = 0;

  double get activity => income + expense;
}

// ignore: unused_element
List<_ReferenceComparisonBucket> _referenceComparisonBuckets(
  List<entity.Transaction> transactions,
  _ComparisonRange range,
) {
  final latestTransaction = transactions.isEmpty
      ? null
      : transactions.reduce(
          (left, right) => left.date.isAfter(right.date) ? left : right,
        );
  final source = latestTransaction?.date ?? DateTime.now();
  final anchor = DateTime(source.year, source.month, source.day);
  final daysPerBucket = switch (range) {
    _ComparisonRange.week => 1,
    _ComparisonRange.month => 5,
    _ComparisonRange.quarter => 15,
  };
  const bucketCount = 7;
  final start = anchor.subtract(
    Duration(days: (bucketCount * daysPerBucket) - 1),
  );
  final buckets = List.generate(
    bucketCount,
    (index) => _ReferenceComparisonBucket(
      start.add(Duration(days: index * daysPerBucket)),
    ),
  );

  for (final transaction in transactions) {
    final date = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final dayOffset = date.difference(start).inDays;
    final index = dayOffset ~/ daysPerBucket;
    if (dayOffset < 0 || index < 0 || index >= buckets.length) continue;
    if (transaction.isExpense) {
      buckets[index].expense += transaction.amount;
    } else {
      buckets[index].income += transaction.amount;
    }
  }
  return buckets;
}

double _roundedComparisonMaximum(double value) {
  if (value <= 0) return 60000;
  final rawStep = value / 5;
  final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor());
  final step = (rawStep / magnitude).ceil() * magnitude;
  return step * 6;
}

// ignore: unused_element
class _ComparisonFilterPanel extends StatelessWidget {
  const _ComparisonFilterPanel({
    required this.scope,
    required this.categories,
    required this.selectedCategory,
    required this.rangeStart,
    required this.rangeEnd,
    required this.transactionCount,
    required this.onScopeChanged,
    required this.onCategoryChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearRange,
  });

  final _ComparisonScope scope;
  final List<String> categories;
  final String? selectedCategory;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int transactionCount;
  final ValueChanged<_ComparisonScope> onScopeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearRange;

  @override
  Widget build(BuildContext context) {
    final hasRange = rangeStart != null || rangeEnd != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comparison options',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<_ComparisonScope>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ComparisonScope.overall,
                  icon: Icon(Icons.dashboard_outlined),
                  label: Text('Overall'),
                ),
                ButtonSegment(
                  value: _ComparisonScope.category,
                  icon: Icon(Icons.category_outlined),
                  label: Text('Category'),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (selection) =>
                  onScopeChanged(selection.first),
            ),
            if (scope == _ComparisonScope.category) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Specific category',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                hint: Text(
                  categories.isEmpty
                      ? 'No categories available'
                      : 'Select a category',
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: categories.isEmpty ? null : onCategoryChanged,
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Date & time range',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (hasRange)
                  TextButton.icon(
                    onPressed: onClearRange,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final startButton = _DateTimeRangeButton(
                  label: 'Start',
                  value: rangeStart,
                  icon: Icons.first_page_rounded,
                  onPressed: onPickStart,
                );
                final endButton = _DateTimeRangeButton(
                  label: 'End',
                  value: rangeEnd,
                  icon: Icons.last_page_rounded,
                  onPressed: onPickEnd,
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      startButton,
                      const SizedBox(height: 10),
                      endButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: startButton),
                    const SizedBox(width: 10),
                    Expanded(child: endButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blueSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$transactionCount matching transaction${transactionCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRangeButton extends StatelessWidget {
  const _DateTimeRangeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                value == null
                    ? 'Any date and time'
                    : DateFormat('d MMM yyyy, h:mm a').format(value!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PeriodComparisonMode { month, year }

enum _ComparisonValueKind { expenses, income }

abstract final class _ComparisonChartColors {
  static const current = Color(0xFF174EA6);
  static const previous = Color(0xFF4B5563);
  static const positive = Color(0xFF06603E);
  static const negative = Color(0xFFA30D2D);
  static const historical = [
    Color(0xFF4C1D95),
    Color(0xFF8A4B08),
    Color(0xFF065F46),
    Color(0xFF881337),
    Color(0xFF1E3A8A),
  ];
}

class _PeriodComparisonDashboard extends StatefulWidget {
  const _PeriodComparisonDashboard({required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  State<_PeriodComparisonDashboard> createState() =>
      _PeriodComparisonDashboardState();
}

class _PeriodComparisonDashboardState
    extends State<_PeriodComparisonDashboard> {
  _PeriodComparisonMode _mode = _PeriodComparisonMode.month;
  _ComparisonValueKind _kind = _ComparisonValueKind.expenses;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final matchingType = widget.transactions
        .where((transaction) => transaction.isExpense == _isExpense)
        .toList();
    final categories =
        matchingType.map((transaction) => transaction.category).toSet().toList()
          ..sort((left, right) => left.compareTo(right));
    final effectiveCategory = categories.contains(_category) ? _category : null;
    final selectedTransactions = matchingType.where((transaction) {
      return effectiveCategory == null ||
          transaction.category == effectiveCategory;
    }).toList();
    final availableYears = widget.transactions
        .map((transaction) => transaction.date.year)
        .toSet();
    final comparison = _buildPeriodComparison(
      selectedTransactions,
      _mode,
      availableYears: availableYears,
    );

    return Card(
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_PeriodComparisonMode>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primaryDark
                      : Colors.white,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColors.ink,
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _PeriodComparisonMode.month,
                  label: Text('Month vs month'),
                ),
                ButtonSegment(
                  value: _PeriodComparisonMode.year,
                  label: Text('Year vs year'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final kindDropdown =
                    DropdownButtonFormField<_ComparisonValueKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ComparisonValueKind.expenses,
                          child: Text('Expenses'),
                        ),
                        DropdownMenuItem(
                          value: _ComparisonValueKind.income,
                          child: Text('Income'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _kind = value;
                          _category = null;
                        });
                      },
                    );
                final categoryDropdown = DropdownButtonFormField<String?>(
                  initialValue: effectiveCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      child: Text('All categories'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    children: [
                      kindDropdown,
                      const SizedBox(height: 10),
                      categoryDropdown,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: kindDropdown),
                    const SizedBox(width: 10),
                    Expanded(child: categoryDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _PeriodComparisonLegend(comparison: comparison),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: _PeriodComparisonLineChart(
                comparison: comparison,
                mode: _mode,
              ),
            ),
            const Divider(height: 28),
            _PeriodComparisonSummary(
              comparison: comparison,
              isExpense: _isExpense,
            ),
          ],
        ),
      ),
    );
  }

  bool get _isExpense => _kind == _ComparisonValueKind.expenses;
}

class _PeriodComparisonLegend extends StatelessWidget {
  const _PeriodComparisonLegend({required this.comparison});

  final _PeriodComparisonData comparison;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _PeriodLegendItem(
          color: _ComparisonChartColors.current,
          label: comparison.currentLabel,
        ),
        _PeriodLegendItem(
          color: _ComparisonChartColors.previous,
          label: comparison.previousLabel,
          dashed: true,
        ),
        ...comparison.olderSeries.indexed.map(
          (entry) => _PeriodLegendItem(
            color: _olderPeriodColor(entry.$1),
            label: entry.$2.label,
            dashed: true,
          ),
        ),
      ],
    );
  }
}

class _PeriodLegendItem extends StatelessWidget {
  const _PeriodLegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 11,
          child: Divider(
            height: 2,
            thickness: 2,
            color: color,
            indent: dashed ? 3 : 0,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _PeriodComparisonLineChart extends StatelessWidget {
  const _PeriodComparisonLineChart({
    required this.comparison,
    required this.mode,
  });

  final _PeriodComparisonData comparison;
  final _PeriodComparisonMode mode;

  @override
  Widget build(BuildContext context) {
    final highest = [
      ...comparison.currentValues,
      ...comparison.previousValues,
      ...comparison.olderSeries.expand((series) => series.values),
    ].fold<double>(0, math.max);
    final chartMax = highest <= 0 ? 1.0 : highest * 1.18;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (comparison.currentValues.length - 1).toDouble(),
        minY: 0,
        maxY: chartMax,
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMax / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (!_showPeriodAxisLabel(index, mode)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8,
                  child: Text(
                    mode == _PeriodComparisonMode.month
                        ? '${index + 1}'
                        : DateFormat('MMM').format(DateTime(2024, index + 1)),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          ...comparison.olderSeries.indexed.map(
            (entry) => _periodLine(
              entry.$2.values,
              _olderPeriodColor(entry.$1),
              dashed: true,
            ),
          ),
          _periodLine(
            comparison.previousValues,
            _ComparisonChartColors.previous,
            dashed: true,
          ),
          _periodLine(comparison.currentValues, _ComparisonChartColors.current),
        ],
      ),
    );
  }
}

Color _olderPeriodColor(int index) {
  return _ComparisonChartColors.historical[index %
      _ComparisonChartColors.historical.length];
}

LineChartBarData _periodLine(
  List<double> values,
  Color color, {
  bool dashed = false,
}) {
  return LineChartBarData(
    spots: List.generate(
      values.length,
      (index) => FlSpot(index.toDouble(), values[index]),
    ),
    color: color,
    barWidth: 2.5,
    isCurved: false,
    dashArray: dashed ? [5, 4] : null,
    dotData: FlDotData(show: !dashed && values.length <= 12),
    belowBarData: BarAreaData(show: false),
  );
}

bool _showPeriodAxisLabel(int index, _PeriodComparisonMode mode) {
  if (mode == _PeriodComparisonMode.year) return index.isEven || index == 11;
  return const {0, 6, 13, 20, 27, 30}.contains(index);
}

class _PeriodComparisonSummary extends StatelessWidget {
  const _PeriodComparisonSummary({
    required this.comparison,
    required this.isExpense,
  });

  final _PeriodComparisonData comparison;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final change = comparison.percentageChange;
    final increased = change != null && change > 0;
    final decreased = change != null && change < 0;
    final favorable = isExpense ? decreased : increased;
    final changeColor = change == null || change == 0
        ? AppColors.muted
        : favorable
        ? _ComparisonChartColors.positive
        : _ComparisonChartColors.negative;
    final changeText = change == null
        ? (comparison.currentTotal > 0 ? 'New' : '—')
        : '${increased
              ? '↗'
              : decreased
              ? '↘'
              : '→'} ${change.abs().toStringAsFixed(1)}%';

    final dominant = comparison.dominantTransaction;
    final dominantShare = dominant == null || comparison.currentTotal <= 0
        ? 0.0
        : (dominant.amount / comparison.currentTotal) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This period',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatDashboardMoney(comparison.currentTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'vs last period',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    changeText,
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (dominant != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8A4B08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.priority_high_rounded,
                  color: Color(0xFF8A4B08),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dominant transaction',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${dominant.title.isEmpty ? dominant.category : dominant.title} · '
                        '${_formatDashboardMoney(dominant.amount)} '
                        '(${dominantShare.toStringAsFixed(1)}% of this period)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodComparisonData {
  const _PeriodComparisonData({
    required this.currentLabel,
    required this.previousLabel,
    required this.currentValues,
    required this.previousValues,
    this.olderSeries = const [],
    this.dominantTransaction,
  });

  final String currentLabel;
  final String previousLabel;
  final List<double> currentValues;
  final List<double> previousValues;
  final List<_OlderPeriodSeries> olderSeries;
  final entity.Transaction? dominantTransaction;

  double get currentTotal => currentValues.fold(0, (sum, value) => sum + value);
  double get previousTotal =>
      previousValues.fold(0, (sum, value) => sum + value);
  double? get percentageChange => previousTotal == 0
      ? null
      : ((currentTotal - previousTotal) / previousTotal) * 100;
}

class _OlderPeriodSeries {
  const _OlderPeriodSeries({required this.label, required this.values});

  final String label;
  final List<double> values;
}

_PeriodComparisonData _buildPeriodComparison(
  List<entity.Transaction> transactions,
  _PeriodComparisonMode mode, {
  Set<int> availableYears = const {},
}) {
  final anchor = transactions.isEmpty
      ? DateTime.now()
      : transactions
            .map((transaction) => transaction.date)
            .reduce((left, right) => left.isAfter(right) ? left : right);
  final currentStart = mode == _PeriodComparisonMode.month
      ? DateTime(anchor.year, anchor.month)
      : DateTime(anchor.year);
  final previousStart = mode == _PeriodComparisonMode.month
      ? DateTime(anchor.year, anchor.month - 1)
      : DateTime(anchor.year - 1);
  final currentEnd = mode == _PeriodComparisonMode.month
      ? DateTime(anchor.year, anchor.month + 1)
      : DateTime(anchor.year + 1);
  final previousEnd = currentStart;
  final pointCount = mode == _PeriodComparisonMode.month ? 31 : 12;
  final currentValues = List<double>.filled(pointCount, 0);
  final previousValues = List<double>.filled(pointCount, 0);
  final currentTransactions = <entity.Transaction>[];
  final olderYears = mode == _PeriodComparisonMode.year
      ? availableYears.where((year) => year < previousStart.year).toList()
      : <int>[];
  olderYears.sort((left, right) => right.compareTo(left));
  final olderValues = {
    for (final year in olderYears) year: List<double>.filled(12, 0),
  };

  for (final transaction in transactions) {
    if (!transaction.date.isBefore(currentStart) &&
        transaction.date.isBefore(currentEnd)) {
      final index = mode == _PeriodComparisonMode.month
          ? transaction.date.day - 1
          : transaction.date.month - 1;
      currentValues[index] += transaction.amount;
      currentTransactions.add(transaction);
    } else if (!transaction.date.isBefore(previousStart) &&
        transaction.date.isBefore(previousEnd)) {
      final index = mode == _PeriodComparisonMode.month
          ? transaction.date.day - 1
          : transaction.date.month - 1;
      previousValues[index] += transaction.amount;
    } else if (mode == _PeriodComparisonMode.year &&
        olderValues.containsKey(transaction.date.year)) {
      olderValues[transaction.date.year]![transaction.date.month - 1] +=
          transaction.amount;
    }
  }

  return _PeriodComparisonData(
    currentLabel: mode == _PeriodComparisonMode.month
        ? DateFormat('MMM yyyy').format(currentStart)
        : DateFormat('yyyy').format(currentStart),
    previousLabel: mode == _PeriodComparisonMode.month
        ? DateFormat('MMM yyyy').format(previousStart)
        : DateFormat('yyyy').format(previousStart),
    currentValues: currentValues,
    previousValues: previousValues,
    dominantTransaction: findDominantTransaction(
      currentTransactions,
      currentValues.fold(0, (sum, value) => sum + value),
    ),
    olderSeries: olderYears
        .map(
          (year) =>
              _OlderPeriodSeries(label: '$year', values: olderValues[year]!),
        )
        .toList(),
  );
}

entity.Transaction? findDominantTransaction(
  List<entity.Transaction> periodTransactions,
  double periodTotal,
) {
  if (periodTransactions.isEmpty || periodTotal <= 0) return null;
  final sorted = [...periodTransactions]
    ..sort((left, right) => right.amount.compareTo(left.amount));
  final top = sorted.first;
  return (top.amount / periodTotal) > 0.5 ? top : null;
}

enum _ComparisonPeriod { daily, monthly, yearly }

class _IncomeExpenseTrendDashboard extends StatefulWidget {
  const _IncomeExpenseTrendDashboard({required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  State<_IncomeExpenseTrendDashboard> createState() =>
      _IncomeExpenseTrendDashboardState();
}

class _IncomeExpenseTrendDashboardState
    extends State<_IncomeExpenseTrendDashboard> {
  _ComparisonPeriod _period = _ComparisonPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final buckets = _comparisonBuckets(widget.transactions, _period);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, AppColors.mintSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.compare_arrows_rounded,
                              color: AppColors.violet,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Income & Expense Comparison',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compare every income and expense category over time.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<_ComparisonPeriod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _ComparisonPeriod.daily,
                        icon: Icon(Icons.today_outlined),
                        label: Text('Daily'),
                      ),
                      ButtonSegment(
                        value: _ComparisonPeriod.monthly,
                        icon: Icon(Icons.calendar_month_outlined),
                        label: Text('Monthly'),
                      ),
                      ButtonSegment(
                        value: _ComparisonPeriod.yearly,
                        icon: Icon(Icons.event_note_outlined),
                        label: Text('Yearly'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (selection) {
                      setState(() => _period = selection.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _TrendLegend(color: AppColors.primary, label: 'Income'),
                  _TrendLegend(color: AppColors.coral, label: 'Expenses'),
                ],
              ),
              const SizedBox(height: 12),
              if (buckets.isEmpty)
                const _EmptyTrendComparison()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final charts = [
                      _ComparisonChartCard(
                        title: 'Histogram',
                        icon: Icons.bar_chart_rounded,
                        child: _ComparisonHistogram(
                          buckets: buckets,
                          period: _period,
                        ),
                      ),
                      _ComparisonChartCard(
                        title: 'Trend line',
                        icon: Icons.show_chart_rounded,
                        child: _ComparisonLineChart(
                          buckets: buckets,
                          period: _period,
                        ),
                      ),
                    ];

                    if (constraints.maxWidth >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: charts.first),
                          const SizedBox(width: 14),
                          Expanded(child: charts.last),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        charts.first,
                        const SizedBox(height: 14),
                        charts.last,
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonChartCard extends StatelessWidget {
  const _ComparisonChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: AppColors.violet),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(height: 250, child: child),
          ],
        ),
      ),
    );
  }
}

class _ComparisonHistogram extends StatelessWidget {
  const _ComparisonHistogram({required this.buckets, required this.period});

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;

  @override
  Widget build(BuildContext context) {
    final chartMax = _trendChartMax(buckets);
    final interval = chartMax / 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final step = _axisLabelStep(buckets.length, constraints.maxWidth);
        final rodWidth = math.max(
          4.0,
          math.min(10.0, constraints.maxWidth / (buckets.length * 4.2)),
        );
        return BarChart(
          BarChartData(
            maxY: chartMax,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(enabled: true),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _trendTitles(buckets, period, interval, step),
            barGroups: List.generate(buckets.length, (index) {
              final bucket = buckets[index];
              return BarChartGroupData(
                x: index,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: bucket.income,
                    width: rodWidth,
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: bucket.expense,
                    width: rodWidth,
                    color: AppColors.coral,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

class _ComparisonLineChart extends StatelessWidget {
  const _ComparisonLineChart({required this.buckets, required this.period});

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;

  @override
  Widget build(BuildContext context) {
    final chartMax = _trendChartMax(buckets);
    final interval = chartMax / 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final step = _axisLabelStep(buckets.length, constraints.maxWidth);
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, buckets.length - 1).toDouble(),
            minY: 0,
            maxY: chartMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _trendTitles(buckets, period, interval, step),
            lineTouchData: const LineTouchData(enabled: true),
            lineBarsData: [
              _trendLine(buckets, (bucket) => bucket.income, AppColors.primary),
              _trendLine(buckets, (bucket) => bucket.expense, AppColors.coral),
            ],
          ),
        );
      },
    );
  }
}

LineChartBarData _trendLine(
  List<_TrendBucket> buckets,
  double Function(_TrendBucket bucket) value,
  Color color,
) {
  return LineChartBarData(
    spots: List.generate(
      buckets.length,
      (index) => FlSpot(index.toDouble(), value(buckets[index])),
    ),
    color: color,
    barWidth: 3,
    isCurved: buckets.length > 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: buckets.length <= 12),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
  );
}

FlTitlesData _trendTitles(
  List<_TrendBucket> buckets,
  _ComparisonPeriod period,
  double interval,
  int labelStep,
) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        interval: interval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          axisSide: meta.axisSide,
          space: 6,
          child: Text(
            _compactChartAmount(value),
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 38,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (value != index ||
              index < 0 ||
              index >= buckets.length ||
              index % labelStep != 0) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 8,
            child: Text(
              _trendBucketLabel(buckets[index].date, period),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.ink),
            ),
          );
        },
      ),
    ),
  );
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EmptyTrendComparison extends StatelessWidget {
  const _EmptyTrendComparison();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold),
      ),
      child: const Column(
        children: [
          Icon(Icons.query_stats_rounded, size: 38, color: AppColors.violet),
          SizedBox(height: 8),
          Text(
            'Add income or expense transactions to see comparisons.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendBucket {
  _TrendBucket(this.date);

  final DateTime date;
  double income = 0;
  double expense = 0;
}

List<_TrendBucket> _comparisonBuckets(
  List<entity.Transaction> transactions,
  _ComparisonPeriod period,
) {
  final values = <DateTime, _TrendBucket>{};
  for (final transaction in transactions) {
    final date = transaction.date;
    final key = switch (period) {
      _ComparisonPeriod.daily => DateTime(date.year, date.month, date.day),
      _ComparisonPeriod.monthly => DateTime(date.year, date.month),
      _ComparisonPeriod.yearly => DateTime(date.year),
    };
    final bucket = values.putIfAbsent(key, () => _TrendBucket(key));
    if (transaction.isExpense) {
      bucket.expense += transaction.amount;
    } else {
      bucket.income += transaction.amount;
    }
  }

  final buckets = values.values.toList()
    ..sort((left, right) => left.date.compareTo(right.date));
  final limit = switch (period) {
    _ComparisonPeriod.daily => 14,
    _ComparisonPeriod.monthly => 12,
    _ComparisonPeriod.yearly => 8,
  };
  return buckets.length <= limit
      ? buckets
      : buckets.sublist(buckets.length - limit);
}

double _trendChartMax(List<_TrendBucket> buckets) {
  final highest = buckets.fold<double>(
    0,
    (current, bucket) =>
        math.max(current, math.max(bucket.income, bucket.expense)),
  );
  return highest <= 0 ? 1 : highest * 1.15;
}

int _axisLabelStep(int bucketCount, double width) {
  final visibleLabels = math.max(2, (width / 58).floor());
  return math.max(1, (bucketCount / visibleLabels).ceil());
}

String _trendBucketLabel(DateTime date, _ComparisonPeriod period) {
  return switch (period) {
    _ComparisonPeriod.daily => DateFormat('d MMM').format(date),
    _ComparisonPeriod.monthly => DateFormat('MMM yy').format(date),
    _ComparisonPeriod.yearly => DateFormat('yyyy').format(date),
  };
}

String _compactChartAmount(double amount) {
  final absolute = amount.abs();
  if (absolute >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}B';
  }
  if (absolute >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
  return amount.toStringAsFixed(0);
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
