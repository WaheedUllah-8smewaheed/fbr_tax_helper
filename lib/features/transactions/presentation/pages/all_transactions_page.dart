part of '../../../dashboard/presentation/pages/dashboard_screen.dart';

enum _TransactionDateFilter { all, month, range }

class _AllTransactionsPage extends StatefulWidget {
  const _AllTransactionsPage({
    required this.categoryPreferences,
    this.initialCategory,
    this.initialCategoryIncludesChildren = false,
  });

  final CategoryPreferencesService categoryPreferences;
  final String? initialCategory;
  final bool initialCategoryIncludesChildren;

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
          !transactionBelongsToCategory(
            transaction,
            widget.initialCategory!,
            includeSubcategories: widget.initialCategoryIncludesChildren,
          )) {
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
            final visibleTotals = calculateTransactionFilterTotals(
              visibleTransactions,
            );
            final categoryMode = resolveCategoryMode(
              categoryName: widget.initialCategory,
              categoryPreferences: widget.categoryPreferences,
            );

            final bottomPadding = MediaQuery.paddingOf(context).bottom + 90.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
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
                    final count = _TransactionFilterSummary(
                      transactionCount: visibleTransactions.length,
                      totals: visibleTotals,
                      mode: categoryMode,
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

class _TransactionFilterSummary extends StatelessWidget {
  const _TransactionFilterSummary({
    required this.transactionCount,
    required this.totals,
    this.mode = CategoryMode.both,
  });

  final int transactionCount;
  final TransactionFilterTotals totals;
  final CategoryMode mode;

  @override
  Widget build(BuildContext context) {
    final countStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final totalStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    final showIncome = mode == CategoryMode.income || mode == CategoryMode.both;
    final showExpense =
        mode == CategoryMode.expense || mode == CategoryMode.both;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
          style: countStyle,
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 12,
          runSpacing: 3,
          children: [
            if (showIncome)
              Text(
                'Income: ${_formatDashboardMoney(totals.income)}',
                style: totalStyle?.copyWith(color: Colors.green.shade700),
              ),
            if (showExpense)
              Text(
                'Expenses: ${_formatDashboardMoney(totals.expenses)}',
                style: totalStyle?.copyWith(color: Colors.red.shade700),
              ),
          ],
        ),
      ],
    );
  }
}

bool transactionBelongsToCategory(
  entity.Transaction transaction,
  String category, {
  bool includeSubcategories = false,
}) {
  if (transaction.category == category) return true;
  return includeSubcategories &&
      TransactionCategory.childrenOf(
        category,
      ).any((child) => child.name == transaction.category);
}

