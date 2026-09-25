import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Update _ComparisonHistogram
hist_pattern = r'''class _ComparisonHistogram extends StatelessWidget \{
  const _ComparisonHistogram\(\{required this\.buckets, required this\.period\}\);

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;

  @override
  Widget build\(BuildContext context\) \{
    final chartMax = _trendChartMax\(buckets\);
    final interval = chartMax / 4;

    return LayoutBuilder\(
      builder: \(context, constraints\) \{
        final step = _axisLabelStep\(buckets\.length, constraints\.maxWidth\);
        final rodWidth = math\.max\(
          4\.0,
          math\.min\(10\.0, constraints\.maxWidth / \(buckets\.length \* 4\.2\)\),
        \);
        return BarChart\(
          BarChartData\(
            maxY: chartMax,
            alignment: BarChartAlignment\.spaceAround,
            barTouchData: BarTouchData\(enabled: true\),
            gridData: FlGridData\(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: \(_\) =>
                  const FlLine\(color: AppColors\.border, strokeWidth: 1\),
            \),
            borderData: FlBorderData\(show: false\),
            titlesData: _trendTitles\(buckets, period, interval, step\),
            barGroups: List\.generate\(buckets\.length, \(index\) \{
              final bucket = buckets\[index\];
              return BarChartGroupData\(
                x: index,
                barsSpace: 3,
                barRods: \[
                  BarChartRodData\(
                    toY: bucket\.income,
                    width: rodWidth,
                    color: AppColors\.primary,
                    borderRadius: const BorderRadius\.vertical\(
                      top: Radius\.circular\(4\),
                    \),
                  \),
                  BarChartRodData\(
                    toY: bucket\.expense,
                    width: rodWidth,
                    color: AppColors\.coral,
                    borderRadius: const BorderRadius\.vertical\(
                      top: Radius\.circular\(4\),
                    \),
                  \),
                \],
              \);
            \}\),
          \),
        \);
      \},
    \);
  \}
\}'''

hist_replace = '''class _ComparisonHistogram extends StatelessWidget {
  const _ComparisonHistogram({required this.buckets, required this.period, this.showIncome = true, this.showExpense = true});

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;
  final bool showIncome;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    double maxVal = 0;
    for (final b in buckets) {
      if (showIncome && b.income > maxVal) maxVal = b.income;
      if (showExpense && b.expense > maxVal) maxVal = b.expense;
    }
    final chartMax = maxVal == 0 ? 100.0 : maxVal * 1.2;
    final interval = chartMax / 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final step = _axisLabelStep(buckets.length, constraints.maxWidth);
        final rodWidth = math.max(
          4.0,
          math.min(15.0, constraints.maxWidth / (buckets.length * (showIncome && showExpense ? 4.2 : 2.5))),
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
                  if (showIncome)
                    BarChartRodData(
                      toY: bucket.income,
                      width: rodWidth,
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  if (showExpense)
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
}'''

code = re.sub(hist_pattern, hist_replace, code)


# Update _ComparisonLineChart
line_pattern = r'''class _ComparisonLineChart extends StatelessWidget \{
  const _ComparisonLineChart\(\{required this\.buckets, required this\.period\}\);

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;

  @override
  Widget build\(BuildContext context\) \{
    final chartMax = _trendChartMax\(buckets\);
    final interval = chartMax / 4;

    return LayoutBuilder\(
      builder: \(context, constraints\) \{
        final step = _axisLabelStep\(buckets\.length, constraints\.maxWidth\);
        return LineChart\(
          LineChartData\(
            minX: 0,
            maxX: math\.max\(1, buckets\.length - 1\)\.toDouble\(\),
            minY: 0,
            maxY: chartMax,
            gridData: FlGridData\(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: \(_\) =>
                  const FlLine\(color: AppColors\.border, strokeWidth: 1\),
            \),
            borderData: FlBorderData\(show: false\),
            titlesData: _trendTitles\(buckets, period, interval, step\),
            lineTouchData: const LineTouchData\(enabled: true\),
            lineBarsData: \[
              _trendLine\(buckets, \(bucket\) => bucket\.income, AppColors\.primary\),
              _trendLine\(buckets, \(bucket\) => bucket\.expense, AppColors\.coral\),
            \],
          \),
        \);
      \},
    \);
  \}
\}'''

line_replace = '''class _ComparisonLineChart extends StatelessWidget {
  const _ComparisonLineChart({required this.buckets, required this.period, this.showIncome = true, this.showExpense = true});

  final List<_TrendBucket> buckets;
  final _ComparisonPeriod period;
  final bool showIncome;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    double maxVal = 0;
    for (final b in buckets) {
      if (showIncome && b.income > maxVal) maxVal = b.income;
      if (showExpense && b.expense > maxVal) maxVal = b.expense;
    }
    final chartMax = maxVal == 0 ? 100.0 : maxVal * 1.2;
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
              if (showIncome) _trendLine(buckets, (bucket) => bucket.income, AppColors.primary),
              if (showExpense) _trendLine(buckets, (bucket) => bucket.expense, AppColors.coral),
            ],
          ),
        );
      },
    );
  }
}'''

code = re.sub(line_pattern, line_replace, code)

# Update layout usage
layout_pattern = r'''                    final charts = \[
                      _ComparisonChartCard\(
                        title: 'Histogram',
                        icon: Icons\.bar_chart_rounded,
                        child: _ComparisonHistogram\(
                          buckets: buckets,
                          period: _period,
                        \),
                      \),
                      _ComparisonChartCard\(
                        title: 'Trend line',
                        icon: Icons\.show_chart_rounded,
                        child: _ComparisonLineChart\(
                          buckets: buckets,
                          period: _period,
                        \),
                      \),
                    \];'''

layout_replace = '''                    final charts = [
                      _ComparisonChartCard(
                        title: 'Income',
                        icon: Icons.trending_up,
                        child: _ComparisonHistogram(
                          buckets: buckets,
                          period: _period,
                          showIncome: true,
                          showExpense: false,
                        ),
                      ),
                      _ComparisonChartCard(
                        title: 'Expenses',
                        icon: Icons.trending_down,
                        child: _ComparisonHistogram(
                          buckets: buckets,
                          period: _period,
                          showIncome: false,
                          showExpense: true,
                        ),
                      ),
                    ];'''

code = re.sub(layout_pattern, layout_replace, code)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Done refactoring Comparison Histogram and LineChart")
