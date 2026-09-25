import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Update _ComparisonPeriodTotals to expose income and expenses explicitly.
totals_pattern = r'''class _ComparisonPeriodTotals \{
  const _ComparisonPeriodTotals\(\{
    required this\.activity,
    required this\.balance,
  \}\);

  factory _ComparisonPeriodTotals\.from\(List<entity\.Transaction> transactions\) \{
    var income = 0\.0;
    var expenses = 0\.0;
    for \(final transaction in transactions\) \{
      if \(transaction\.isExpense\) \{
        expenses \+= transaction\.amount;
      \} else \{
        income \+= transaction\.amount;
      \}
    \}
    return _ComparisonPeriodTotals\(
      activity: income \+ expenses,
      balance: income - expenses,
    \);
  \}

  final double activity;
  final double balance;
\}'''

totals_replace = '''class _ComparisonPeriodTotals {
  const _ComparisonPeriodTotals({
    required this.activity,
    required this.balance,
    required this.income,
    required this.expenses,
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
      income: income,
      expenses: expenses,
    );
  }

  final double activity;
  final double balance;
  final double income;
  final double expenses;
}'''

code = re.sub(totals_pattern, totals_replace, code)

# Update _ComparisonTotalsSummary to display income and expenses.
summary_pattern = r'''          Row\(
            children: \[
              Expanded\(
                child: _ComparisonTotalCell\(
                  label: firstLabel,
                  value: _formatComparisonMoney\(first\.activity\),
                  color: const Color\(0xFF16194F\),
                \),
              \),
              const SizedBox\(width: 8\),
              Expanded\(
                child: _ComparisonTotalCell\(
                  label: secondLabel,
                  value: _formatComparisonMoney\(second\.activity\),
                  color: const Color\(0xFF16194F\),
                \),
              \),
            \],
          \),
          const SizedBox\(height: 8\),
          _ComparisonTotalCell\(
            label: 'Difference in activity',
            value:
                '\$\{difference >= 0 \? '\+' : ''\}\$\{_formatComparisonMoney\(difference\)\}',
            color: differenceColor,
          \),
          const SizedBox\(height: 14\),
          const Divider\(height: 1, color: AppColors\.border\),
          const SizedBox\(height: 14\),
          Row\(
            children: \[
              Expanded\(
                child: _ComparisonTotalCell\(
                  label: firstLabel,
                  value: _formatComparisonMoney\(first\.balance\),
                  color: const Color\(0xFF16194F\),
                \),
              \),
              const SizedBox\(width: 8\),
              Expanded\(
                child: _ComparisonTotalCell\(
                  label: secondLabel,
                  value: _formatComparisonMoney\(second\.balance\),
                  color: const Color\(0xFF16194F\),
                \),
              \),
            \],
          \),
          const SizedBox\(height: 8\),
          _ComparisonTotalCell\(
            label: 'Difference in balance',
            value:
                '\$\{balanceDifference >= 0 \? '\+' : ''\}\$\{_formatComparisonMoney\(balanceDifference\)\}',
            color: balanceDifference >= 0 \? AppColors\.primary : AppColors\.coral,
          \),'''

summary_replace = '''          Row(
            children: [
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Income',
                  value: _formatComparisonMoney(first.income),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Income',
                  value: _formatComparisonMoney(second.income),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ComparisonTotalCell(
            label: 'Difference in Income',
            value:
                '',
            color: second.income - first.income >= 0 ? AppColors.primary : AppColors.coral,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Expenses',
                  value: _formatComparisonMoney(first.expenses),
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Expenses',
                  value: _formatComparisonMoney(second.expenses),
                  color: AppColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ComparisonTotalCell(
            label: 'Difference in Expenses',
            value:
                '',
            color: second.expenses - first.expenses >= 0 ? AppColors.coral : AppColors.primary,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Net',
                  value: _formatComparisonMoney(first.balance),
                  color: const Color(0xFF16194F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ComparisonTotalCell(
                  label: ' Net',
                  value: _formatComparisonMoney(second.balance),
                  color: const Color(0xFF16194F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ComparisonTotalCell(
            label: 'Difference in Net Balance',
            value:
                '',
            color: balanceDifference >= 0 ? AppColors.primary : AppColors.coral,
          ),'''

code = re.sub(summary_pattern, summary_replace, code)

# Fix charts so they are separate
chart_pattern = r'''                AnimatedSwitcher\(
                  duration: const Duration\(milliseconds: 240\),
                  child: _SelectableComparisonChart\(
                    key: ValueKey\(
                      'comparison-\$\(_mode\.name\)-\-\-\-\',
                    \),
                    firstValues: _comparisonSeries\(
                      widget\.transactions,
                      mode: _mode,
                      month: firstMonth,
                      year: firstYear,
                    \),
                    secondValues: _comparisonSeries\(
                      widget\.transactions,
                      mode: _mode,
                      month: secondMonth,
                      year: secondYear,
                    \),
                    firstLabel: firstLabel,
                    secondLabel: secondLabel,
                    mode: _mode,
                  \),
                \),'''

chart_replace = '''                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Column(
                    key: ValueKey(
                      'comparison-----',
                    ),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Income Comparison',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      _SelectableComparisonChart(
                        firstValues: _comparisonSeries(
                          firstTransactions.where((t) => !t.isExpense).toList(),
                          mode: _mode,
                          month: firstMonth,
                          year: firstYear,
                        ),
                        secondValues: _comparisonSeries(
                          secondTransactions.where((t) => !t.isExpense).toList(),
                          mode: _mode,
                          month: secondMonth,
                          year: secondYear,
                        ),
                        firstLabel: firstLabel,
                        secondLabel: secondLabel,
                        mode: _mode,
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Expense Comparison',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      _SelectableComparisonChart(
                        firstValues: _comparisonSeries(
                          firstTransactions.where((t) => t.isExpense).toList(),
                          mode: _mode,
                          month: firstMonth,
                          year: firstYear,
                        ),
                        secondValues: _comparisonSeries(
                          secondTransactions.where((t) => t.isExpense).toList(),
                          mode: _mode,
                          month: secondMonth,
                          year: secondYear,
                        ),
                        firstLabel: firstLabel,
                        secondLabel: secondLabel,
                        mode: _mode,
                      ),
                    ],
                  ),
                ),'''

code = re.sub(chart_pattern, chart_replace, code)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Done summary and charts update")
