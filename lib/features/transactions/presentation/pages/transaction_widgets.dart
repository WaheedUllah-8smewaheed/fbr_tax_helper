import 'transactions_page.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;
import 'package:fbr_tax_helper/features/transactions/services/transaction_report_service.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/assets/domain/entities/asset.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fbr_tax_helper/features/transactions/presentation/pages/comparison_dashboard_page.dart';

class PrintTransactionsButton extends StatefulWidget {
  const PrintTransactionsButton({
    super.key,
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
  State<PrintTransactionsButton> createState() =>
      PrintTransactionsButtonState();
}

class PrintTransactionsButtonState extends State<PrintTransactionsButton> {
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

String monthLabel(DateTime month) {
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

enum ComparisonScope { overall, category }



enum TransactionListMode { normal, khata, asset }

class TransactionList extends StatelessWidget {
  const TransactionList({
    super.key,
    required this.state,
    required this.currentUserId,
    required this.transactions,
    this.mode = TransactionListMode.normal,
  });
  
  final TransactionListMode mode;

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
      
      final displayTransactions = transactions.where((t) {
        if (mode == TransactionListMode.khata) return t.khataEntryId != null;
        if (mode == TransactionListMode.asset) return t.assetId != null;
        return t.khataEntryId == null && t.assetId == null;
      }).toList();

      if (displayTransactions.isEmpty) {
        return const Center(child: Text('No transactions yet. Add one!'));
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayTransactions.length,
        itemBuilder: (context, index) {
          return _TransactionTile(transaction: displayTransactions[index]);
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
    final icon = getIconForCategory(transaction.category);
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
                      ],
                      if (transaction.assetId != null) ...[
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
                if (transaction.khataEntryId == null &&
                    transaction.assetId == null) ...[
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
                ],
                TextButton.icon(
                  onPressed: transaction.id == null
                      ? null
                      : () => _confirmDelete(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
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

IconData getIconForCategory(String category) {
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

Color getColorForCategory(String category) {
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

List<DateTime> buildMonthOptions(List<entity.Transaction> transactions) {
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
      .where((transaction) => !transaction.isExpense && transaction.khataEntryId == null && transaction.assetId == null)
      .fold<double>(0, (total, transaction) => total + transaction.amount);
}

double _totalExpenses(List<entity.Transaction> transactions) {
  return transactions
      .where((transaction) => transaction.isExpense && transaction.khataEntryId == null && transaction.assetId == null)
      .fold<double>(0, (total, transaction) => total + transaction.amount);
}

String formatMoney(num value) {
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

String formatNetBalance(double netBalance) {
  if (netBalance < 0) {
    return '-PKR ${formatMoney(netBalance.abs())}';
  } else if (netBalance > 0) {
    return '+PKR ${formatMoney(netBalance)}';
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
          amount: formatMoney(totalIncome),
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
          amount: formatMoney(totalExpenses),
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
          amount: formatNetBalance(netBalance),
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
          '${item.category}, $type, ${formatMoney(item.total)}, $percentageLabel of total ${item.isExpense ? "expenses" : "income"}',
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
                          formatMoney(item.total),
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
    return switch (filter) {
      TransactionTypeFilter.income => !transaction.isExpense,
      TransactionTypeFilter.expense => transaction.isExpense,
    };
  }).toList();
}

String transactionFilterLabel({
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
                                formatPieBalance(netBalance),
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
                          '${formatMoney(totalExpenses)} ($spentPct% spent)',
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
                          text: formatMoney(netBalance.abs()),
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
                formatMoney(netBalance.abs()),
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
                          formatMoney(totalIncome),
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
                          formatMoney(totalExpenses),
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



