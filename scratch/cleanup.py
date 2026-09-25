import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Remove _ComparisonLineChart
line_chart_pattern = r'''class _ComparisonLineChart extends StatelessWidget \{.*?\}\s*\}'''
code = re.sub(line_chart_pattern, '', code, flags=re.DOTALL)

# Remove _trendChartMax
trend_chart_max_pattern = r'''double _trendChartMax\(List<_TrendBucket> buckets\) \{.*?\}'''
code = re.sub(trend_chart_max_pattern, '', code, flags=re.DOTALL)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Cleaned up unused code")
