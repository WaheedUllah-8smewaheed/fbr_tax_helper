import re

DASHBOARD_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'

with open(DASHBOARD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

khata_start = -1
assets_start = -1
transactions_start = -1

for i, line in enumerate(lines):
    if line.startswith('enum KhataSegmentFilter { payable, receivable }'): khata_start = i
    if line.startswith('class _AssetsPage extends StatefulWidget {'): assets_start = i
    if line.startswith('class _AllTransactionsPage extends StatefulWidget {'): transactions_start = i

khata_lines = lines[khata_start:assets_start]
assets_lines = lines[assets_start:transactions_start]

new_dash_lines = lines[:khata_start] + lines[transactions_start:]

part_statements = """
part '../../../../khata/presentation/pages/khata_page.dart';
part '../../../../assets/presentation/pages/assets_page.dart';
"""

# Find class DashboardScreen to insert part statements before it
insert_idx = 0
for i, line in enumerate(new_dash_lines):
    if 'class DashboardScreen extends StatefulWidget {' in line:
        insert_idx = i
        break

new_dash_lines.insert(insert_idx, part_statements)

with open(DASHBOARD_FILE, 'w', encoding='utf-8') as f:
    f.write("".join(new_dash_lines))

print("Fixed dashboard_screen.dart!")
