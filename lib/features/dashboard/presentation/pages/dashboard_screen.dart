import 'dart:async';
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
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/assets/domain/entities/asset.dart';

import 'package:fbr_tax_helper/core/platform/app_storage.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/auth/services/biometric_lock_service.dart';
import 'package:fbr_tax_helper/features/backup/services/drive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:fbr_tax_helper/core/widgets/filer_flow_logo.dart';
import 'package:url_launcher/url_launcher.dart';


part '../../../transactions/presentation/pages/all_transactions_page.dart';
part '../../../khata/presentation/pages/khata_page.dart';
part '../../../assets/presentation/pages/assets_page.dart';
part 'more_page.dart';
part 'profile_page.dart';
part '../../../transactions/presentation/pages/comparison_dashboard_page.dart';
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
  final _khataPageKey = GlobalKey<_KhataPageState>();
  final _assetsPageKey = GlobalKey<_AssetsPageState>();

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
      _khataPageKey.currentState?._loadEntries();
    } else if (index == 2) {
      _assetsPageKey.currentState?._loadAssets();
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
        } else {
          final shouldQuit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App'),
              content: const Text('Are you sure you want to exit the application?'),
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
            : AppBar(title: Text(titles[_selectedIndex])),
      body: ListenableBuilder(
        listenable: _categoryPreferences,
        builder: (context, _) => IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeDashboard(
              key: _homeDashboardKey,
              categoryPreferences: _categoryPreferences,
              onOpenKhata: () => _onItemTapped(1),
              onOpenAssets: () => _onItemTapped(2),
            ),
            _KhataPage(
              key: _khataPageKey,
              categoryPreferences: _categoryPreferences,
            ),
            _AssetsPage(
              key: _assetsPageKey,
              categoryPreferences: _categoryPreferences,
            ),
            _CategorySettingsPage(categoryPreferences: _categoryPreferences),
            _MorePage(categoryPreferences: _categoryPreferences),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex != 0 ? null : FloatingActionButton(
        heroTag: 'add-transaction-fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _TransactionsPage(
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
    ));
  }
}

enum TransactionTypeFilter { income, expense, both }

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

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({
    required this.categoryPreferences,
    required this.filter,
    required this.onFilterChanged,
    this.showAppBar = false,
    this.onParentCategorySelected,
    this.showTypeFilter = true,
  });

  final CategoryPreferencesService categoryPreferences;
  final TransactionTypeFilter filter;
  final ValueChanged<TransactionTypeFilter> onFilterChanged;
  final bool showAppBar;
  final bool showTypeFilter;
  final Future<void> Function(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  )?
  onParentCategorySelected;

  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  late TransactionTypeFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  @override
  void didUpdateWidget(covariant _TransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _filter = widget.filter;
    }
  }

  Future<void> _openParentTransaction(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  ) async {
    final onParentCategorySelected = widget.onParentCategorySelected;
    if (onParentCategorySelected != null) {
      return onParentCategorySelected(parentCategory, categoryOptions);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          parentCategory: parentCategory,
          categoryOptions: categoryOptions,
          categoryPreferences: widget.categoryPreferences,
          initialIsExpense: _filter == TransactionTypeFilter.expense
              ? true
              : (_filter == TransactionTypeFilter.income
                    ? false
                    : widget.categoryPreferences.isExpense(parentCategory)),
          onViewCategoryHistory: (category, {required includeSubcategories}) {
            Navigator.of(this.context).push(
              MaterialPageRoute(
                builder: (context) => _AllTransactionsPage(
                  categoryPreferences: widget.categoryPreferences,
                  initialCategory: category,
                  initialCategoryIncludesChildren: includeSubcategories,
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
    return switch (_filter) {
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
    return widget.categoryPreferences.hierarchy.entries.expand((superCategory) {
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
    return ListenableBuilder(
      listenable: widget.categoryPreferences,
      builder: (context, _) {
        final categoryCards = _visibleCategoryCards();

        final bottomPadding = MediaQuery.paddingOf(context).bottom + 90.0;
        return Scaffold(
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Transactions'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                )
              : null,
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: [
              if (widget.showTypeFilter) ...[
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
                  selected: {_filter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _filter = selection.first;
                    });
                    widget.onFilterChanged(selection.first);
                  },
                ),
                const SizedBox(height: 20),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: LayoutBuilder(
                  key: ValueKey(_filter),
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
                        key: ValueKey('${_filter.name}-${card.categoryName}'),
                        data: card,
                        index: index,
                        onTap: () => _openParentTransaction(
                          card.categoryName,
                          card.options,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get a clear overview of your income, expenses, and net balance.',
            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14),
          ),
        ],
      ),
    );
  }

  static const _profileStorage = FlutterSecureStorage();
  String? _selectedFinancialYear;
  int? _selectedMonth;
  String? _profileImagePath;
  double _totalPayable = 0.0;
  double _totalReceivable = 0.0;
  double _totalAssets = 0.0;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedFinancialYear = null;
    _selectedMonth = null;
    _loadProfileImage();
    _loadKhataAndAssetMetrics();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Dashboard-Banner
    const dashboardBannerAdUnitId = 'ca-app-pub-9761861396179823/6624819291';
    final adUnitId = Platform.isAndroid
        ? dashboardBannerAdUnitId
        : dashboardBannerAdUnitId;
    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Dashboard banner failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
    bannerAd.load();
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
                      builder: (context) => const _ProfilePage(),
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
                      _buildIntroCard(),
                        IncomeExpensePiePanel(transactions: visibleTransactions),
                      const SizedBox(height: 14),
                      TopCategoryCharts(
                        transactions: visibleTransactions,
                        periodLabel: periodLabel,
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
                      const SizedBox(height: 14),
                      _buildKhataAndAssetsMetricsCards(),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _PrintTransactionsButton(
                                transactions: visibleTransactions,
                                filterLabel: _transactionFilterLabel(
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
                                      builder: (context) =>
                                          _AllTransactionsPage(
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
    }) {
      return InkWell(
        onTap: widget.onOpenKhata,
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

class _DriveSyncButton extends StatefulWidget {
  const _DriveSyncButton({this.asListTile = false, this.action});

  final bool asListTile;
  final _DriveAction? action;

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
      final message = _isNetworkError(e)
          ? 'No internet connection. Check your connection and try again.'
          : 'Google Drive operation failed. Please try again.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
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
      final isRestore = widget.action == _DriveAction.restore;
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
    case 'khata wasooli':
      return Icons.call_received_rounded;
    case "khata ada'igi":
    case 'khata adaigi':
      return Icons.call_made_rounded;
    case 'asset sale':
      return Icons.sell_outlined;
    case 'asset purchase':
      return Icons.shopping_cart_outlined;
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

String _formatSignedDashboardMoney(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  final sign = value > 0 ? '+' : (value < 0 ? '-' : '');
  return '${sign}PKR ${buffer.toString()}';
}

const dashboardMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String getFinancialYear(DateTime date) {
  final startYear = date.month >= 7 ? date.year : date.year - 1;
  final endYearShort = (startYear + 1) % 100;
  final endYearStr = endYearShort.toString().padLeft(2, '0');
  return '$startYear-$endYearStr';
}

List<String> buildFinancialYearOptions(List<entity.Transaction> transactions) {
  final years = transactions
      .map((t) => getFinancialYear(t.date))
      .toSet()
      .toList();
  final currentFY = getFinancialYear(DateTime.now());
  if (!years.contains(currentFY)) {
    years.add(currentFY);
  }
  years.sort((a, b) => b.compareTo(a));
  return years;
}

List<entity.Transaction> filterDashboardTransactions(
  List<entity.Transaction> transactions, {
  String? financialYear,
  int? month,
}) {
  return transactions.where((transaction) {
    if (financialYear != null &&
        getFinancialYear(transaction.date) != financialYear) {
      return false;
    }
    if (month != null && transaction.date.month != month) {
      return false;
    }
    return true;
  }).toList();
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

String _formatNumber(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatNetBalance(double netBalance) {
  if (netBalance < 0) {
    return '-PKR ${_formatNumber(netBalance.abs())}';
  } else if (netBalance > 0) {
    return '+PKR ${_formatNumber(netBalance)}';
  } else {
    return 'PKR 0';
  }
}

class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key, required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalIncome(transactions);
    final totalExpenses = _totalExpenses(transactions);
    final totalActivity = totalIncome + totalExpenses;
    final netBalance = totalIncome - totalExpenses;

    final incomeShare = totalActivity > 0
        ? ((totalIncome / totalActivity) * 100).round()
        : (totalIncome > 0 ? 100 : 0);

    final expenseToIncomePct = totalIncome > 0
        ? ((totalExpenses / totalIncome) * 100).round()
        : (totalExpenses > 0 ? 100 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useThreeColumns = width >= 660;
        final useTwoColumns = width >= 440 && width < 660;

        final card1 = KpiMetricCard(
          title: 'Income',
          amount: _formatDashboardMoney(totalIncome),
          subtitle: '$incomeShare% of income',
          icon: Icons.arrow_upward_rounded,
          badgeColor: const Color(0xFF0F9D58),
          badgeTextColor: const Color(0xFF0F9D58),
          bgColor: const Color(0xFFEDF9F2),
          borderColor: const Color(0xFFC8EEDC),
          amountColor: const Color(0xFF111827),
          subtitleColor: const Color(0xFF0F9D58),
        );

        final card2 = KpiMetricCard(
          title: 'Expenses',
          amount: _formatDashboardMoney(totalExpenses),
          subtitle: '$expenseToIncomePct% of income',
          icon: Icons.arrow_downward_rounded,
          badgeColor: const Color(0xFFE52E3D),
          badgeTextColor: const Color(0xFFE52E3D),
          bgColor: const Color(0xFFFDF2F3),
          borderColor: const Color(0xFFFBD3D6),
          amountColor: const Color(0xFF111827),
          subtitleColor: const Color(0xFFE52E3D),
        );

        final netSubtitle = netBalance < 0
            ? 'You spent more than you earned'
            : (netBalance > 0
                  ? 'You saved more than you spent'
                  : 'Income equals expenses');

        final card3 = KpiMetricCard(
          title: 'Net Balance',
          amount: _formatNetBalance(netBalance),
          subtitle: netSubtitle,
          icon: Icons.account_balance_wallet_rounded,
          badgeColor: const Color(0xFFF59E0B),
          badgeTextColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFF8F0),
          borderColor: const Color(0xFFFDE6D2),
          amountColor: netBalance < 0
              ? const Color(0xFFE52E3D)
              : (netBalance > 0
                    ? const Color(0xFF0F9D58)
                    : const Color(0xFF111827)),
          subtitleColor: const Color(0xFF6B7280),
        );

        if (useThreeColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
              const SizedBox(width: 12),
              Expanded(child: card3),
            ],
          );
        }

        if (useTwoColumns) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 12),
              card3,
            ],
          );
        }

        return Column(
          children: [
            card1,
            const SizedBox(height: 10),
            card2,
            const SizedBox(height: 10),
            card3,
          ],
        );
      },
    );
  }
}

class KpiMetricCard extends StatelessWidget {
  const KpiMetricCard({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.bgColor,
    required this.borderColor,
    required this.amountColor,
    required this.subtitleColor,
  });

  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color bgColor;
  final Color borderColor;
  final Color amountColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: badgeTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w900,
                fontSize: 19,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subtitleColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class TopCategoryCharts extends StatelessWidget {
  const TopCategoryCharts({
    super.key,
    required this.transactions,
    required this.periodLabel,
    required this.onCategoryTap,
  });

  final List<entity.Transaction> transactions;
  final String periodLabel;
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
    final totalIncome = _totalIncome(transactions);
    final totalExpenses = _totalExpenses(transactions);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showTopCategories(
              context,
              title: 'Top 5 Income',
              subtitle: 'Your highest income sources for $periodLabel.',
              items: income,
              totalAmount: totalIncome,
              isExpense: false,
              color: Colors.green.shade600,
              icon: Icons.trending_up_rounded,
            ),
            icon: const Icon(Icons.trending_up_rounded, size: 18),
            label: const Text('Top 5 Income'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.forest),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showTopCategories(
              context,
              title: 'Top 5 Expenses',
              subtitle: 'Your highest spending categories for $periodLabel.',
              items: expenses,
              totalAmount: totalExpenses,
              isExpense: true,
              color: Colors.red.shade600,
              icon: Icons.trending_down_rounded,
            ),
            icon: Icon(
              Icons.trending_down_rounded,
              size: 18,
              color: Colors.red.shade700,
            ),
            label: const Text('Top 5 Expenses'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade700),
            ),
          ),
        ),
      ],
    );
  }

  void _showTopCategories(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<_CategoryTotal> items,
    required double totalAmount,
    required bool isExpense,
    required Color color,
    required IconData icon,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _TopCategorySectionCard(
                      title: title,
                      subtitle: subtitle,
                      items: items,
                      totalAmount: totalAmount,
                      isExpense: isExpense,
                      color: color,
                      icon: icon,
                      showHeader: false,
                      onCategoryTap: (category) {
                        Navigator.of(pageContext).pop();
                        onCategoryTap(category);
                      },
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

class _TopCategorySectionCard extends StatelessWidget {
  const _TopCategorySectionCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.totalAmount,
    required this.isExpense,
    required this.color,
    required this.icon,
    required this.onCategoryTap,
    this.showHeader = true,
  });

  final String title;
  final String subtitle;
  final List<_CategoryTotal> items;
  final double totalAmount;
  final bool isExpense;
  final Color color;
  final IconData icon;
  final ValueChanged<String> onCategoryTap;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: items.isEmpty
                    ? SizedBox(
                        height: 90,
                        child: Center(
                          child: Text(
                            isExpense
                                ? 'No expense transactions for this period'
                                : 'No income transactions for this period',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == items.length - 1 ? 0 : 14,
                              ),
                              child: _HorizontalCategoryLollipop(
                                item: _CategoryChartBar(
                                  category: items[index].category,
                                  total: items[index].total,
                                  isExpense: isExpense,
                                ),
                                totalActivity: totalAmount,
                                color: color,
                                onTap: () =>
                                    onCategoryTap(items[index].category),
                              ),
                            ),
                        ],
                      ),
              ),
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
          '${item.category}, $type, ${_formatDashboardMoney(item.total)}, $percentageLabel of total ${item.isExpense ? "expenses" : "income"}',
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
                      height: markerSize + 18,
                      child: Stack(
                        children: [
                          Positioned(
                            left: (markerCenter - 24)
                                .clamp(0.0, constraints.maxWidth - 48)
                                .toDouble(),
                            top: 0,
                            width: 48,
                            height: 16,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                percentageLabel,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 34,
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
                            top: 34,
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
                            top: 18,
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
  if (percentage <= 0) return '0%';
  if (percentage > 0 && percentage < 0.1) return '<0.1%';
  final rounded = double.parse(percentage.toStringAsFixed(2));
  if (rounded % 1 == 0) return '${rounded.toStringAsFixed(0)}%';
  final fixed = percentage.toStringAsFixed(2);
  if (fixed.endsWith('0')) return '${percentage.toStringAsFixed(1)}%';
  return '$fixed%';
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

String _transactionFilterLabel({
  String? selectedFinancialYear,
  int? selectedMonth,
}) {
  if (selectedFinancialYear == null && selectedMonth == null) {
    return 'All transactions - All dates';
  }
  final parts = <String>[];
  if (selectedFinancialYear != null) {
    parts.add('FY $selectedFinancialYear');
  }
  if (selectedMonth != null && selectedMonth >= 1 && selectedMonth <= 12) {
    parts.add(dashboardMonthNames[selectedMonth - 1]);
  }
  return 'All transactions - ${parts.join(', ')}';
}

String dashboardPeriodLabel({
  String? selectedFinancialYear,
  int? selectedMonth,
}) {
  if (selectedMonth != null && selectedMonth >= 1 && selectedMonth <= 12) {
    var year = DateTime.now().year;
    final financialYear = selectedFinancialYear;
    if (financialYear != null) {
      final startYear = int.tryParse(financialYear.split('-').first);
      if (startYear != null) {
        year = selectedMonth >= 7 ? startYear : startYear + 1;
      }
    }
    return '${dashboardMonthNames[selectedMonth - 1]} $year';
  }
  if (selectedFinancialYear != null) return 'FY $selectedFinancialYear';
  return 'All Time';
}

class _PrintTransactionsButton extends StatefulWidget {
  const _PrintTransactionsButton({
    required this.transactions,
    required this.filterLabel,
    this.buttonLabel = 'Print report',
    this.accentColor,
    this.allTransactions,
    this.comprehensive = false,
  });

  final List<entity.Transaction> transactions;
  final String filterLabel;
  final String buttonLabel;
  final Color? accentColor;
  final List<entity.Transaction>? allTransactions;
  final bool comprehensive;

  @override
  State<_PrintTransactionsButton> createState() =>
      _PrintTransactionsButtonState();
}

class _PrintTransactionsButtonState extends State<_PrintTransactionsButton> {
  bool _isPrinting = false;

  Future<void> _print() async {
    if (_isPrinting || (!widget.comprehensive && widget.transactions.isEmpty)) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      if (widget.comprehensive) {
        final userId = context.read<AuthService>().currentUser?.uid;
        final assetRows = await TaxDatabase.instance.fetchAssets(
          userId: userId,
        );
        final khataRows = await TaxDatabase.instance.fetchKhataEntries(
          userId: userId,
        );
        await const TransactionReportService().printFinancialReport(
          periodTransactions: widget.transactions,
          allTransactions: widget.allTransactions ?? widget.transactions,
          assets: assetRows.map(Asset.fromMap).toList(),
          khataEntries: khataRows.map(KhataEntry.fromMap).toList(),
          periodLabel: _financialPeriodLabel(widget.filterLabel),
        );
      } else {
        await const TransactionReportService().printReport(
          transactions: widget.transactions,
          filterLabel: widget.filterLabel,
        );
      }
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

  String _financialPeriodLabel(String label) {
    if (label == 'All transactions - All dates') return 'All Time';
    return label.replaceFirst('All transactions - ', '');
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        !_isPrinting &&
        (widget.comprehensive || widget.transactions.isNotEmpty);
    final icon = _isPrinting
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.print_outlined);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.accentColor,
        side: widget.accentColor == null
            ? null
            : BorderSide(color: widget.accentColor!),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: enabled ? _print : null,
      icon: icon,
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.transactions.isEmpty && !widget.comprehensive
              ? 'No transactions to print'
              : widget.buttonLabel,
        ),
      ),
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

class IncomeExpensePiePanel extends StatelessWidget {
  const IncomeExpensePiePanel({super.key, required this.transactions});

  final List<entity.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totalIncome = _totalIncome(transactions);
    final totalExpenses = _totalExpenses(transactions);
    final netBalance = totalIncome - totalExpenses;
    final positiveBalance = math.max(0.0, netBalance);

    final chartTotal = totalExpenses + positiveBalance;

    final spentPctValue = totalIncome > 0
        ? (totalExpenses / totalIncome) * 100
        : (totalExpenses > 0 ? 100.0 : 0.0);
    final savedPctValue = totalIncome > 0
        ? ((netBalance / totalIncome) * 100).clamp(0.0, 100.0)
        : 0.0;

    final spentPct = formatPiePercentage(spentPctValue);
    final savedPct = formatPiePercentage(savedPctValue);

    final isLoss = netBalance < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Expenses vs Balance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Expenses vs Balance'),
                      content: const Text(
                        'This chart displays the share of Expenses (red) and remaining Balance (green).',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: chartTotal <= 0
                ? const _EmptyPieChart()
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          sections: [
                            if (positiveBalance > 0)
                              PieChartSectionData(
                                value: positiveBalance,
                                color: const Color(0xFF00C853),
                                radius: 48,
                                title: '$savedPct%',
                                showTitle: true,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                                titlePositionPercentageOffset: 0.55,
                              ),
                            if (totalExpenses > 0)
                              PieChartSectionData(
                                value: totalExpenses,
                                color: const Color(0xFFFF1744),
                                radius: 48,
                                title: '$spentPct%',
                                showTitle: true,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                                titlePositionPercentageOffset: 0.55,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Net Balance',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'PKR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Text(
                                _formatPieBalance(netBalance),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: netBalance < 0
                                      ? const Color(0xFFE52E3D)
                                      : const Color(0xFF0F9D58),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Left Chip (Net Surplus / Balance)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isLoss
                        ? const Color(0xFFFDF2F3)
                        : const Color(0xFFEDF9F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLoss
                          ? const Color(0xFFFCDADB)
                          : const Color(0xFFC8EEDC),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLoss
                                ? Icons.trending_down_rounded
                                : Icons.trending_up_rounded,
                            size: 14,
                            color: isLoss
                                ? const Color(0xFFE52E3D)
                                : const Color(0xFF0F9D58),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isLoss ? 'Net Deficit' : 'Net Surplus',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isLoss
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_formatSignedDashboardMoney(netBalance)} ($savedPct% remaining)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isLoss
                                ? const Color(0xFFE52E3D)
                                : const Color(0xFF0F9D58),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Right Chip (Total Expenses / Spent)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFCDADB),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_down_rounded,
                            size: 14,
                            color: Color(0xFFE52E3D),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Spent',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_formatDashboardMoney(totalExpenses)} ($spentPct% spent)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE52E3D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String formatPiePercentage(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded % 1 == 0) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class NetLossAlertBanner extends StatelessWidget {
  const NetLossAlertBanner({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
  });

  final double totalIncome;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final netBalance = totalIncome - totalExpenses;
    final isLoss = netBalance < 0;
    final isSurplus = netBalance > 0;

    final diffPct = totalIncome > 0
        ? (((totalExpenses - totalIncome).abs() / totalIncome) * 100).round()
        : 100;

    final bgColor = isLoss
        ? const Color(0xFFFDF2F3)
        : (isSurplus ? const Color(0xFFEDF9F2) : const Color(0xFFF3F4F6));
    final borderColor = isLoss
        ? const Color(0xFFFCDADB)
        : (isSurplus ? const Color(0xFFC8EEDC) : const Color(0xFFE5E7EB));
    final accentColor = isLoss
        ? const Color(0xFFE52E3D)
        : (isSurplus ? const Color(0xFF0F9D58) : const Color(0xFF4B5563));

    final badgeBg = isLoss
        ? const Color(0xFFFFD6D9)
        : (isSurplus ? const Color(0xFFD1F2E0) : const Color(0xFFE5E7EB));

    final title = isLoss
        ? 'Net Loss'
        : (isSurplus ? 'Net Surplus' : 'Balanced');
    final subtitlePrefix = isLoss
        ? 'You are over budget by '
        : (isSurplus
              ? 'You are under budget by '
              : 'Income matches expenses exactly');

    final rightSubtitle = isLoss
        ? 'Expenses are $diffPct% higher\nthan income'
        : (isSurplus
              ? 'Income is $diffPct% higher\nthan expenses'
              : 'Balanced budget');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(
              isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    children: [
                      TextSpan(text: subtitlePrefix),
                      if (netBalance != 0)
                        TextSpan(
                          text: _formatDashboardMoney(netBalance.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDashboardMoney(netBalance.abs()),
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rightSubtitle,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class IncomeVsExpensesComparisonPanel extends StatelessWidget {
  const IncomeVsExpensesComparisonPanel({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
  });

  final double totalIncome;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final maxAmount = math.max(totalIncome, totalExpenses);
    final incomeBarFraction = maxAmount > 0
        ? (totalIncome / maxAmount).clamp(0.02, 1.0)
        : 0.02;
    final expenseBarFraction = maxAmount > 0
        ? (totalExpenses / maxAmount).clamp(0.02, 1.0)
        : 0.02;

    final incomePctLabel = totalIncome > 0 && totalExpenses > 0
        ? '${((totalIncome / (totalIncome + totalExpenses)) * 100).round()}%'
        : (totalIncome > 0 ? '100%' : '0%');
    final expensePctLabel = totalIncome > 0 && totalExpenses > 0
        ? '${((totalExpenses / (totalIncome + totalExpenses)) * 100).round()}%'
        : (totalExpenses > 0 ? '100%' : '0%');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Income vs Expenses Comparison',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Income',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          _formatDashboardMoney(totalIncome),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          flex: (incomeBarFraction * 100).round().clamp(2, 100),
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          incomePctLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Flexible(
                          flex: ((1.0 - incomeBarFraction) * 100).round().clamp(
                            0,
                            100,
                          ),
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expenses',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          _formatDashboardMoney(totalExpenses),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          flex: (expenseBarFraction * 100).round().clamp(
                            2,
                            100,
                          ),
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1744),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          expensePctLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Flexible(
                          flex: ((1.0 - expenseBarFraction) * 100)
                              .round()
                              .clamp(0, 100),
                          child: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 98),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '0%',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '25%',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '50%',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '75%',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '100%',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Percentage of Income',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
            'Add income or expense transactions to update the chart.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
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
                      if (transaction.khataEntryId != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'via Khata: ${transaction.linkedCounterpartyOrAsset ?? transaction.beneficiary}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF0369A1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (transaction.assetId != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'via Asset: ${transaction.linkedCounterpartyOrAsset ?? transaction.title}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

