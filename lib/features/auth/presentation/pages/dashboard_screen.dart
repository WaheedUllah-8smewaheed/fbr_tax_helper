import 'package:fl_chart/fl_chart.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/screens/tax_calculator_screen.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';

import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:fbr_tax_helper/services/drive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(const LoadTransactions());
    _pages = [
      const _HomeDashboard(),
      TaxCalculatorScreen(authService: context.read<AuthService>()),
      const Center(child: Text('Expenses Page (Coming Soon)')),
      const Center(child: Text('Profile Page (Coming Soon)')),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

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
                final transactions =
                    state is TransactionLoaded && state.userId == currentUserId
                    ? state.transactions
                    : const <entity.Transaction>[];
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
                                  style: Theme.of(context).textTheme.headlineSmall,
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
                                style: Theme.of(context).textTheme.headlineSmall,
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
                    const SizedBox(height: 24),
                    Text(
                      'Income Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _CategoryCards(
                      transactions: visibleTransactions,
                      isExpense: false,
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
  bool _isSyncing = false;

  Future<void> _sync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final authService = context.read<AuthService>();

    try {
      await authService.getGoogleDriveHeaders(promptIfNecessary: true);
      final result = await DriveService().syncDatabaseToCloud();

      if (!mounted) return;
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
      debugPrint('DRIVE SYNC ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Google Drive connection failed: $e'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sync Google Drive',
      onPressed: _isSyncing ? null : _sync,
      icon: _isSyncing
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_sync_outlined),
    );
  }
}

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
    case 'personal care':
      return Colors.pink;
    case 'subscriptions':
      return Colors.blue;
    case 'gifts & rewards':
      return Colors.teal;
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
  final months = transactions
      .map((transaction) => DateTime(transaction.date.year, transaction.date.month))
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
                    style: (isCompact
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
  const _CategoryCards({required this.transactions, required this.isExpense});

  final List<entity.Transaction> transactions;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        final isCompact = constraints.maxWidth < 360;

        final categories = TransactionCategory.all
            .where((cat) => cat.isExpense == isExpense)
            .toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: isCompact ? 190 : 168,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryTransactions = transactions
                .where((transaction) => transaction.category == category.name)
                .toList();
            return _CategoryCard(
              category: category.name,
              transactions: categoryTransactions,
            );
          },
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.transactions});

  final String category;
  final List<entity.Transaction> transactions;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddTransactionPage(
                    initialCategory: category,
                    initialIsExpense: true,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(width: isCompact ? 2 : 4),
                      IconButton(
                        tooltip: 'Add $category transaction',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddTransactionPage(
                                initialCategory: category,
                                initialIsExpense: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: isCompact ? 18 : 24,
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
                    color: transactions.any((transaction) => transaction.isExpense)
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
        const DropdownMenuItem<DateTime?>(value: null, child: Text('All months')),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                'Total',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatDashboardMoney(total),
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
