import re
import os

DASHBOARD_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
KHATA_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\presentation\pages\khata_page.dart'
ASSETS_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\assets\presentation\pages\assets_page.dart'

with open(DASHBOARD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def get_line_index(starts_with):
    for i, line in enumerate(lines):
        if line.startswith(starts_with):
            return i
    return -1

khata_start = get_line_index('enum KhataSegmentFilter { payable, receivable }')
assets_start = get_line_index('class _AssetsPage extends StatefulWidget {')
transactions_start = get_line_index('class _AllTransactionsPage extends StatefulWidget {')

if -1 in [khata_start, assets_start, transactions_start]:
    print("Could not find boundaries")
    exit(1)

khata_lines = lines[khata_start:assets_start]
assets_lines = lines[assets_start:transactions_start]

# We must add part of '...dashboard_screen.dart'; at the top of these files
part_of = "part of '../../../../dashboard/presentation/pages/dashboard_screen.dart';\n\n"

os.makedirs(os.path.dirname(KHATA_FILE), exist_ok=True)
with open(KHATA_FILE, 'w', encoding='utf-8') as f:
    f.write(part_of + "".join(khata_lines))

os.makedirs(os.path.dirname(ASSETS_FILE), exist_ok=True)
with open(ASSETS_FILE, 'w', encoding='utf-8') as f:
    f.write(part_of + "".join(assets_lines))

# Remove them from dashboard_screen and insert part statements
new_dash_lines = lines[:khata_start] + lines[transactions_start:]
part_statements = """
part '../../../../khata/presentation/pages/khata_page.dart';
part '../../../../assets/presentation/pages/assets_page.dart';
"""

# Find where imports end to put part statements
import_end = 0
for i, line in enumerate(new_dash_lines):
    if line.startswith('import ') or line.strip() == '':
        continue
    else:
        import_end = i
        break

new_dash_lines.insert(import_end, part_statements)

with open(DASHBOARD_FILE, 'w', encoding='utf-8') as f:
    f.write("".join(new_dash_lines))

print("Successfully split Khata and Assets into part files!")
