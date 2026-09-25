import os

DASHBOARD_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
TRANSACTIONS_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\transactions\presentation\pages\all_transactions_page.dart'
KHATA_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\presentation\pages\khata_page.dart'
ASSETS_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\assets\presentation\pages\assets_page.dart'
MORE_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\more_page.dart'
PROFILE_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\profile_page.dart'
COMPARISON_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\transactions\presentation\pages\comparison_dashboard_page.dart'

with open(DASHBOARD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def get_line_index(starts_with):
    for i, line in enumerate(lines):
        if line.startswith(starts_with):
            return i
    return -1

transactions_start = get_line_index('enum _TransactionDateFilter { all, month, range }')
khata_start = get_line_index('enum KhataSegmentFilter { payable, receivable }')
assets_start = get_line_index('class _AssetsPage extends StatefulWidget {')
more_start = get_line_index('class _MorePage extends StatefulWidget {')
profile_start = get_line_index('class _ProfilePage extends StatefulWidget {')
home_start = get_line_index('class _HomeDashboard extends StatefulWidget {')
comparison_start = get_line_index('class _ComparisonDashboardPage extends StatefulWidget {')
income_expense_trend_start = get_line_index('class _IncomeExpenseTrendDashboard extends StatefulWidget {')
pie_panel_start = get_line_index('class IncomeExpensePiePanel extends StatelessWidget {')

# The order should be:
# 1. Transactions
# 2. Khata
# 3. Assets
# 4. More
# 5. Profile
# 6. Home (We leave Home in dashboard_screen)

if -1 in [transactions_start, khata_start, assets_start, more_start, profile_start, home_start, comparison_start, pie_panel_start]:
    print("Could not find one of the boundaries")
    exit(1)

transactions_lines = lines[transactions_start:khata_start]
khata_lines = lines[khata_start:assets_start]
assets_lines = lines[assets_start:more_start]
more_lines = lines[more_start:profile_start]
profile_lines = lines[profile_start:home_start]
comparison_lines = lines[comparison_start:pie_panel_start]

def write_part(filepath, content, part_str):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(part_str + "\n\n" + "".join(content))

write_part(TRANSACTIONS_FILE, transactions_lines, "part of '../../../dashboard/presentation/pages/dashboard_screen.dart';")
write_part(KHATA_FILE, khata_lines, "part of '../../../dashboard/presentation/pages/dashboard_screen.dart';")
write_part(ASSETS_FILE, assets_lines, "part of '../../../dashboard/presentation/pages/dashboard_screen.dart';")
write_part(MORE_FILE, more_lines, "part of 'dashboard_screen.dart';")
write_part(PROFILE_FILE, profile_lines, "part of 'dashboard_screen.dart';")
write_part(COMPARISON_FILE, comparison_lines, "part of '../../../dashboard/presentation/pages/dashboard_screen.dart';")


new_dash_lines = lines[:transactions_start] + lines[home_start:comparison_start] + lines[pie_panel_start:]

part_statements = """
part '../../../../transactions/presentation/pages/all_transactions_page.dart';
part '../../../../khata/presentation/pages/khata_page.dart';
part '../../../../assets/presentation/pages/assets_page.dart';
part 'more_page.dart';
part 'profile_page.dart';
part '../../../../transactions/presentation/pages/comparison_dashboard_page.dart';
"""

# Find where imports end to put part statements
import_end = 0
for i, line in enumerate(new_dash_lines):
    if line.startswith('class DashboardScreen '):
        import_end = i
        break

new_dash_lines.insert(import_end, part_statements)

with open(DASHBOARD_FILE, 'w', encoding='utf-8') as f:
    f.write("".join(new_dash_lines))

print("Successfully extracted all features to part files!")
