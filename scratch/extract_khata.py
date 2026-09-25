import os

DASHBOARD_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
KHATA_PAGE_FILE = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\presentation\pages\khata_page.dart'

with open(DASHBOARD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

khata_start = -1
khata_end = -1

for i, line in enumerate(lines):
    if line.startswith('enum KhataSegmentFilter { payable, receivable }'):
        khata_start = i
        break

if khata_start == -1:
    print("Could not find KhataSegmentFilter")
    exit(1)

# Now find where _KhataPageState ends. 
# We know _AssetsPage starts right after it.
for i in range(khata_start, len(lines)):
    if line.startswith('class _AssetsPage'):
        khata_end = i
        break
    line = lines[i]

if khata_end == -1:
    print("Could not find class _AssetsPage")
    exit(1)

# Backtrack from _AssetsPage to the end of _KhataPageState
khata_end -= 1
while khata_end > 0 and lines[khata_end].strip() == '':
    khata_end -= 1

khata_code = "".join(lines[khata_start:khata_end+1])

# Remove Khata code from dashboard
new_dashboard_lines = lines[:khata_start] + lines[khata_end+1:]

# Replace _KhataPage with KhataPage globally
new_dashboard_code = "".join(new_dashboard_lines).replace('_KhataPage', 'KhataPage')
khata_code = khata_code.replace('_KhataPage', 'KhataPage')

imports = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fbr_tax_helper/core/theme/colors.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

"""

os.makedirs(os.path.dirname(KHATA_PAGE_FILE), exist_ok=True)
with open(KHATA_PAGE_FILE, 'w', encoding='utf-8') as f:
    f.write(imports + khata_code)

# Add import to dashboard_screen.dart
import_statement = "import 'package:fbr_tax_helper/features/khata/presentation/pages/khata_page.dart';\n"
dash_lines = new_dashboard_code.splitlines(True)
for i, l in enumerate(dash_lines):
    if l.startswith("import 'package:fbr_tax_helper/"):
        dash_lines.insert(i, import_statement)
        break

with open(DASHBOARD_FILE, 'w', encoding='utf-8') as f:
    f.writelines(dash_lines)

print("Successfully extracted KhataPage!")
