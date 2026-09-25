part of '../../../dashboard/presentation/pages/dashboard_screen.dart';

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

String _formatPieBalance(double amount) {
  final absolute = amount.abs();
  final sign = amount < 0
      ? '-'
      : amount > 0
      ? '+'
      : '';
  if (absolute >= 1000000) {
    final millions = (absolute / 1000000).toStringAsFixed(1);
    return '$sign${millions}M';
  }
  return '$sign${_formatNumber(absolute)}';
}

