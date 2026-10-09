// ignore_for_file: unused_import

import 'package:fbr_tax_helper/features/dashboard/presentation/pages/history_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';
import 'dart:async';
import 'dart:io';



import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;

import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/khata/presentation/bloc/khata_bloc.dart';
import 'package:fbr_tax_helper/features/assets/domain/entities/asset.dart';
import 'package:fbr_tax_helper/features/assets/presentation/bloc/asset_bloc.dart';

import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/auth/services/biometric_lock_service.dart';
import 'package:fbr_tax_helper/features/backup/services/drive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/all_transactions_page.dart';
import 'package:fbr_tax_helper/features/khata/presentation/pages/khata_page.dart';
import 'package:fbr_tax_helper/features/assets/presentation/pages/assets_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/more_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/profile_page.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:fbr_tax_helper/core/widgets/filer_flow_logo.dart';
import '../../../../features/transactions/presentation/pages/transactions_page.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  TransactionTypeFilter _transactionFilter = TransactionTypeFilter.income;
  late final CategoryPreferencesService _categoryPreferences;
  final _homeDashboardKey = GlobalKey<_HomeDashboardState>();
  final _khataPageKey = GlobalKey<KhataPageState>();
  final _assetsPageKey = GlobalKey<AssetsPageState>();

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
            content: Row(
              children: const [
                FilerFlowLogo(size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please enable fingerprint for two-factor authentication in the Profile menu.',
                  ),
                ),
              ],
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
    final isReturningToDashboard = index == 0 && _selectedIndex != 0;
    setState(() {
      _selectedIndex = index;
    });
    if (isReturningToDashboard) {
      _homeDashboardKey.currentState?._loadKhataAndAssetMetrics();
    }
    if (index == 1) {
      context.read<KhataBloc>().add(
        LoadKhataEntries(
          userId: context.read<AuthService>().currentUser?.uid ?? '',
        ),
      );
    } else if (index == 2) {
      context.read<AssetBloc>().add(
        LoadAssets(userId: context.read<AuthService>().currentUser?.uid ?? ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Dashboard', 'Khata', 'Assets', 'Settings', 'More'];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          _homeDashboardKey.currentState?._loadKhataAndAssetMetrics();
          } else {
          final shouldQuit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App'),
              content: const Text(
                'Are you sure you want to exit the application?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
          if (shouldQuit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? null
            : AppBar(
                title: Text(titles[_selectedIndex]),
                actions: [
                  if (_selectedIndex == 1 || _selectedIndex == 2)
                    IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        if (_selectedIndex == 1) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryPage(
                                title: 'Payable/Receivable History',
                                mode: TransactionListMode.khata,
                              ),
                            ),
                          );
                        } else if (_selectedIndex == 2) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryPage(
                                title: 'Asset History',
                                mode: TransactionListMode.asset,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
        body: ListenableBuilder(
          listenable: _categoryPreferences,
          builder: (context, _) =>
              BlocListener<TransactionBloc, TransactionState>(
                listener: (context, state) {
                  if (state is TransactionLoaded) {
                    final userId =
                        context.read<AuthService>().currentUser?.uid ?? '';
                    if (userId.isNotEmpty) {
                      context.read<KhataBloc>().add(
                        LoadKhataEntries(userId: userId),
                      );
                      context.read<AssetBloc>().add(LoadAssets(userId: userId));
                    }
                  }
                },
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _HomeDashboard(
                      key: _homeDashboardKey,
                      categoryPreferences: _categoryPreferences,
                      onOpenKhata: () => _onItemTapped(1),
                      onOpenAssets: () => _onItemTapped(2),
                    ),
                    KhataPage(
                      key: _khataPageKey,
                      categoryPreferences: _categoryPreferences,
                    ),
                    AssetsPage(
                      key: _assetsPageKey,
                      categoryPreferences: _categoryPreferences,
                    ),
                    CategorySettingsPage(
                      categoryPreferences: _categoryPreferences,
                    ),
                    MorePage(categoryPreferences: _categoryPreferences),
                  ],
                ),
              ),
        ),
        floatingActionButton: _selectedIndex != 0
            ? null
            : FloatingActionButton(
                heroTag: 'add-transaction-fab',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TransactionsPage(
                        categoryPreferences: _categoryPreferences,
                        filter: _transactionFilter,
                        onFilterChanged: (filter) {
                          setState(() => _transactionFilter = filter);
                        },
                        showAppBar: true,
                      ),
                    ),
                  );
                },
                backgroundColor: AppColors.warmGold,
                foregroundColor: AppColors.forest,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded, size: 30),
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.cream,
                elevation: 0,
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                selectedItemColor: AppColors.forest,
                unselectedItemColor: const Color(0xFF6B7280),
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_rounded),
                    activeIcon: Icon(Icons.grid_view_rounded),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.currency_exchange_rounded),
                    activeIcon: Icon(Icons.currency_exchange_rounded),
                    label: 'Khata',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_rounded),
                    activeIcon: Icon(Icons.account_balance_rounded),
                    label: 'Assets',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_rounded),
                    activeIcon: Icon(Icons.menu_rounded),
                    label: 'More',
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



class TransactionFilterTotals {
  const TransactionFilterTotals({required this.income, required this.expenses});

  final double income;
  final double expenses;
}

TransactionFilterTotals calculateTransactionFilterTotals(
  Iterable<entity.Transaction> transactions,
) {
  var income = 0.0;
  var expenses = 0.0;
  for (final transaction in transactions) {
    if (transaction.isExpense) {
      expenses += transaction.amount;
    } else {
      income += transaction.amount;
    }
  }
  return TransactionFilterTotals(income: income, expenses: expenses);
}

CategoryMode resolveCategoryMode({
  required String? categoryName,
  required CategoryPreferencesService categoryPreferences,
}) {
  if (categoryName == null) {
    return CategoryMode.both;
  }
  if (categoryPreferences.childrenOf(categoryName).isNotEmpty) {
    return categoryPreferences.modeForParent(categoryName);
  }
  if (categoryPreferences.isDualMode(categoryName)) {
    return CategoryMode.both;
  }
  return categoryPreferences.isExpense(categoryName)
      ? CategoryMode.expense
      : CategoryMode.income;
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({
    super.key,
    required this.categoryPreferences,
    required this.onOpenKhata,
    required this.onOpenAssets,
  });

  final CategoryPreferencesService categoryPreferences;
  final VoidCallback onOpenKhata;
  final VoidCallback onOpenAssets;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  static const _profileStorage = FlutterSecureStorage();
  String? _selectedFinancialYear;
  int? _selectedMonth;
  String? _profileImagePath;
  double _totalPayable = 0.0;
  double _totalReceivable = 0.0;
  double _totalAssets = 0.0;
  BannerAd? _bannerAd;
  final bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedFinancialYear = null;
    _selectedMonth = null;
    _loadProfileImage();
    _loadKhataAndAssetMetrics();
    // _loadBannerAd(); // Disabled for now to prevent ad loading crashes
  }


  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadKhataAndAssetMetrics() async {
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      final khataRows = await TaxDatabase.instance.fetchKhataEntries(
        userId: userId,
      );
      final khataList = khataRows.map((r) => KhataEntry.fromMap(r)).toList();
      final openPayable = khataList
          .where((e) => e.isPayable && !e.isPaid && !e.isWrittenOff)
          .fold(0.0, (sum, e) => sum + e.remainingAmount);
      final openReceivable = khataList
          .where((e) => !e.isPayable && !e.isPaid && !e.isWrittenOff)
          .fold(0.0, (sum, e) => sum + e.remainingAmount);

      final assetRows = await TaxDatabase.instance.fetchAssets(userId: userId);
      final assetList = assetRows.map((r) => Asset.fromMap(r)).toList();
      final assetsVal = assetList.fold(0.0, (sum, a) => sum + a.value);

      if (mounted) {
        setState(() {
          _totalPayable = openPayable;
          _totalReceivable = openReceivable;
          _totalAssets = assetsVal;
        });
      }
    } catch (_) {}
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

  String _getUserInitial(dynamic user) {
    final name = (user?.displayName as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    final email = (user?.email as String?)?.trim();
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'W';
  }

  Widget _buildDashboardHeader({
    required BuildContext context,
    required List<String> financialYearOptions,
  }) {
    final isSelectedYearPresent =
        _selectedFinancialYear == null ||
        financialYearOptions.contains(_selectedFinancialYear);
    final effectiveYearValue = isSelectedYearPresent
        ? _selectedFinancialYear
        : null;

    final user = context.read<AuthService>().currentUser;
    final photoUrl = user?.photoURL;
    final hasLocalProfileImage =
        _profileImagePath != null && File(_profileImagePath!).existsSync();
    final ImageProvider<Object>? profileImage = hasLocalProfileImage
        ? FileImage(File(_profileImagePath!))
        : photoUrl != null && photoUrl.isNotEmpty
        ? NetworkImage(photoUrl)
        : null;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 18,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Financial Year Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF133E35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: effectiveYearValue,
                          dropdownColor: const Color(0xFF0F3A30),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All FY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (final fy in financialYearOptions)
                              DropdownMenuItem<String?>(
                                value: fy,
                                child: Text(
                                  'FY $fy',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (newYear) {
                            setState(() {
                              _selectedFinancialYear = newYear;
                            });
                          },
                        ),
                      ),
                    ),
                    // Month Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF133E35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedMonth,
                          dropdownColor: const Color(0xFF0F3A30),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'All Months',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem<int?>(
                                value: m,
                                child: Text(
                                  dashboardMonthNames[m - 1],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (newMonth) {
                            setState(() {
                              _selectedMonth = newMonth;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // User profile avatar button on the top right
          Semantics(
            button: true,
            label: 'Open user profile',
            child: Tooltip(
              message: 'Profile',
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                  if (mounted) await _loadProfileImage();
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8B961),
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Text(
                          _getUserInitial(user),
                          style: const TextStyle(
                            color: Color(0xFF1E3A2F),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser;

    return Scaffold(
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          final currentUserId = user?.uid ?? '';
          final storedTransactions =
              state is TransactionLoaded && state.userId == currentUserId
              ? state.transactions.where((t) => t.khataEntryId == null && t.assetId == null).toList()
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
          final visibleTransactions = filterDashboardTransactions(
            transactions,
            financialYear: _selectedFinancialYear,
            month: _selectedMonth,
          );
          final financialYearOptions = buildFinancialYearOptions(transactions);
          final periodLabel = dashboardPeriodLabel(
            selectedFinancialYear: _selectedFinancialYear,
            selectedMonth: _selectedMonth,
          );

          return Column(
            children: [
              _buildDashboardHeader(
                context: context,
                financialYearOptions: financialYearOptions,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 14.0,
                    right: 14.0,
                    top: 14.0,
                    bottom: 84.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IncomeExpensePiePanel(transactions: visibleTransactions),
                      const SizedBox(height: 14),
                      TopCategoryCharts(
                        transactions: visibleTransactions,
                        periodLabel: periodLabel,
                        onCategoryTap: (category) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AllTransactionsPage(
                                categoryPreferences: widget.categoryPreferences,
                                initialCategory: category,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildKhataAndAssetsMetricsCards(),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: PrintTransactionsButton(
                                transactions: visibleTransactions,
                                filterLabel: transactionFilterLabel(
                                  selectedFinancialYear: _selectedFinancialYear,
                                  selectedMonth: _selectedMonth,
                                ),
                                accentColor: AppColors.forest,
                                allTransactions: transactions,
                                comprehensive: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AllTransactionsPage(
                                        categoryPreferences:
                                            widget.categoryPreferences,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('View All Transactions'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.forest,
                                  side: const BorderSide(
                                    color: AppColors.forest,
                                  ),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isBannerAdLoaded && _bannerAd != null)
                SafeArea(
                  top: false,
                  child: Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKhataAndAssetsMetricsCards() {
    final formatter = NumberFormat('#,##0.00', 'en_US');

    Widget balanceCard({
      required String title,
      required double amount,
      required Color color,
      required Color borderColor,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap ?? widget.onOpenKhata,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    title == 'Total Payable'
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Rs ${formatter.format(amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Open balance',
                style: TextStyle(fontSize: 9.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: balanceCard(
                title: 'Total Payable',
                amount: _totalPayable,
                color: const Color(0xFFC62828),
                borderColor: const Color(0xFFFFCDD2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: balanceCard(
                title: 'Total Receivable',
                amount: _totalReceivable,
                color: const Color(0xFF2E7D32),
                borderColor: const Color(0xFFC8E6C9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: widget.onOpenAssets,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8DCC0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6B57).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 20,
                    color: Color(0xFF0F6B57),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Assets Value',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A2F),
                        ),
                      ),
                      Text(
                        'Vehicles, property, savings, and investments',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs ${formatter.format(_totalAssets)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F6B57),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DriveSyncButton extends StatefulWidget {
  const DriveSyncButton({super.key, this.asListTile = false, this.action});

  final bool asListTile;
  final DriveAction? action;

  @override
  State<DriveSyncButton> createState() => _DriveSyncButtonState();
}

class _DriveSyncButtonState extends State<DriveSyncButton> {
  bool _isWorking = false;

  Future<void> _runDriveOperation(DriveAction action) async {
    if (_isWorking) return;
    if (action == DriveAction.restore && !await _confirmRestore()) return;
    if (!mounted) return;

    setState(() {
      _isWorking = true;
    });

    final isRestore = action == DriveAction.restore;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        strokeWidth: 4.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0F9D58),
                        ),
                      ),
                    ),
                    Icon(
                      isRestore
                          ? Icons.restore_rounded
                          : Icons.cloud_upload_rounded,
                      color: const Color(0xFF0F9D58),
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  isRestore ? 'Restoring Data...' : 'Backing Up Data...',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isRestore
                      ? 'Please wait while we safely download your backup from Google Drive.'
                      : 'Please wait while we securely upload your data to Google Drive.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    final messenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    try {
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw const AuthServiceException(
          'Sign in before using Google Drive backup and restore.',
        );
      }
      await authService.getGoogleDriveHeaders(promptIfNecessary: true);
      final driveService = DriveService(
        ownerId: currentUser.uid,
        ownerEmail: currentUser.email,
      );
      final result = action == DriveAction.backup
          ? await driveService.syncDatabaseToCloud()
          : await driveService.restoreBackupFromCloud();

      if (!mounted) return;
      if (result.success && action == DriveAction.restore) {
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
      final message = _isNetworkError(e)
          ? 'No internet connection. Check your connection and try again.'
          : 'Google Drive operation failed. Please try again.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  bool _isNetworkError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('no internet') ||
        message.contains('internet connection');
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
    if (widget.action != null) {
      final isRestore = widget.action == DriveAction.restore;
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: _isWorking ? null : () => _runDriveOperation(widget.action!),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isRestore
                      ? Icons.restore_outlined
                      : Icons.cloud_upload_outlined,
                  color: const Color(0xFF1565C0),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  isRestore ? 'Restore' : 'Backup',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isRestore ? 'Restore from Google Drive' : 'Back up your data',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PopupMenuButton<DriveAction>(
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
          value: DriveAction.backup,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_upload_outlined),
            title: Text('Back up now'),
            subtitle: Text('Database and receipt images'),
          ),
        ),
        PopupMenuItem(
          value: DriveAction.restore,
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

enum DriveAction { backup, restore }


