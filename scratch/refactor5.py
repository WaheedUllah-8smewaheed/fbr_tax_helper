import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\transactions\services\transaction_report_service.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Update _ReportPeriodTotals to include income and expenses
totals_pattern = r'''class _ReportPeriodTotals \{
  const _ReportPeriodTotals\(\{
    required this\.activity,
    required this\.balance,
  \}\);

  factory _ReportPeriodTotals\.from\(List<entity\.Transaction> transactions\) \{
    var income = 0\.0;
    var expenses = 0\.0;
    for \(final transaction in transactions\) \{
      if \(transaction\.isExpense\) \{
        expenses \+= transaction\.amount;
      \} else \{
        income \+= transaction\.amount;
      \}
    \}
    return _ReportPeriodTotals\(
      activity: income \+ expenses,
      balance: income - expenses,
    \);
  \}

  final double activity;
  final double balance;
\}'''

totals_replace = '''class _ReportPeriodTotals {
  const _ReportPeriodTotals({
    required this.activity,
    required this.balance,
    required this.income,
    required this.expenses,
  });

  factory _ReportPeriodTotals.from(List<entity.Transaction> transactions) {
    var income = 0.0;
    var expenses = 0.0;
    for (final transaction in transactions) {
      if (transaction.isExpense) {
        expenses += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }
    return _ReportPeriodTotals(
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

# Update buildComparisonReport body
table_pattern = r'''                pw\.TableHelper\.fromTextArray\(
                  context: context,
                  border: null,
                  headerDecoration: pw\.BoxDecoration\(
                    color: PdfColor\.fromHex\('#F2F4F5'\),
                    borderRadius: const pw\.BorderRadius\.vertical\(
                      top: pw\.Radius\.circular\(8\),
                    \),
                  \),
                  headerStyle: pw\.TextStyle\(
                    fontWeight: pw\.FontWeight\.bold,
                    color: PdfColor\.fromHex\('#4A5568'\),
                    fontSize: 10,
                  \),
                  cellStyle: const pw\.TextStyle\(
                    color: PdfColors\.black,
                    fontSize: 10,
                  \),
                  cellPadding: const pw\.EdgeInsets\.all\(12\),
                  headers: \['Metric', firstLabel, secondLabel, 'Difference'\],
                  data: \[
                    \[
                      'Total Activity',
                      _formatMoney\(first\.activity\),
                      _formatMoney\(second\.activity\),
                      '\$\{activityDifference >= 0 \? '\+' : ''\}\$\{_formatMoney\(activityDifference\)\}',
                    \],
                    \[
                      'Net Balance',
                      _formatMoney\(first\.balance\),
                      _formatMoney\(second\.balance\),
                      '\$\{balanceDifference >= 0 \? '\+' : ''\}\$\{_formatMoney\(balanceDifference\)\}',
                    \],
                  \],
                \),'''

table_replace = '''                pw.TableHelper.fromTextArray(
                  context: context,
                  border: null,
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F2F4F5'),
                    borderRadius: const pw.BorderRadius.vertical(
                      top: pw.Radius.circular(8),
                    ),
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#4A5568'),
                    fontSize: 10,
                  ),
                  cellStyle: const pw.TextStyle(
                    color: PdfColors.black,
                    fontSize: 10,
                  ),
                  cellPadding: const pw.EdgeInsets.all(12),
                  headers: ['Metric', firstLabel, secondLabel, 'Difference'],
                  data: [
                    [
                      'Total Income',
                      _formatMoney(first.income),
                      _formatMoney(second.income),
                      '',
                    ],
                    [
                      'Total Expenses',
                      _formatMoney(first.expenses),
                      _formatMoney(second.expenses),
                      '',
                    ],
                    [
                      'Net Balance',
                      _formatMoney(first.balance),
                      _formatMoney(second.balance),
                      '',
                    ],
                  ],
                ),'''

code = re.sub(table_pattern, table_replace, code)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\transactions\services\transaction_report_service.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Done report update")
