import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

trend_line_pattern = r'''LineChartBarData _trendLine\([\s\S]*?\}\s*\}'''
code = re.sub(trend_line_pattern, '', code)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Cleaned up _trendLine")
