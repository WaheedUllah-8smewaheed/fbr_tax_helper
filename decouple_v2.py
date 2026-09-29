import os
import re

# 1. Update dashboard_screen.dart
dashboard_file = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'
with open(dashboard_file, 'r', encoding='utf-8') as f:
    dashboard_code = f.read()

# Replace _formatDashboardMoney with formatMoney
dashboard_code = dashboard_code.replace('_formatDashboardMoney', 'formatMoney')
dashboard_code = dashboard_code.replace('_formatNetBalance', 'formatNetBalance')

# Remove _formatNumber, _formatDashboardMoney, _formatNetBalance implementations
# and _ComparisonScope
dashboard_code = re.sub(r'String formatMoney\(num value\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'String _formatNumber\(num value\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'String formatNetBalance\(double netBalance\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'enum _ComparisonScope \{ overall, category \}\n', '', dashboard_code)

# Remove part directives
dashboard_code = re.sub(r"^part '.*?';\n", "", dashboard_code, flags=re.MULTILINE)

# Add import for currency_formatter and the pages
new_imports = """
import 'package:fbr_tax_helper/core/utils/currency_formatter.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/all_transactions_page.dart';
import 'package:fbr_tax_helper/features/khata/presentation/pages/khata_page.dart';
import 'package:fbr_tax_helper/features/assets/presentation/pages/assets_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/more_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/profile_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/comparison_dashboard_page.dart';
"""
dashboard_code = re.sub(r"(import 'package:flutter_bloc/flutter_bloc.dart';)", r"\1" + new_imports, dashboard_code)

with open(dashboard_file, 'w', encoding='utf-8') as f:
    f.write(dashboard_code)


# 2. Update comparison_dashboard_page.dart
comp_file = 'lib/features/transactions/presentation/pages/comparison_dashboard_page.dart'
with open(comp_file, 'r', encoding='utf-8') as f:
    comp_code = f.read()

# Extract dashboard imports
imports = "\n".join(re.findall(r"^import '.*?';$", dashboard_code, flags=re.MULTILINE))

# Add missing imports for comparison
imports += "\nimport 'dart:math' as math;"
imports += "\nimport 'package:fbr_tax_helper/core/utils/currency_formatter.dart';"
imports += "\nimport 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';"

# Remove part of
comp_code = re.sub(r"^part of '.*?';\s*", imports + "\n\nenum _ComparisonScope { overall, category }\n\n", comp_code)
comp_code = comp_code.replace('_formatDashboardMoney', 'formatMoney')
comp_code = comp_code.replace('_formatNumber', 'formatMoney')

with open(comp_file, 'w', encoding='utf-8') as f:
    f.write(comp_code)


# 3. Update all other parts
parts = [
    'lib/features/transactions/presentation/pages/all_transactions_page.dart',
    'lib/features/khata/presentation/pages/khata_page.dart',
    'lib/features/assets/presentation/pages/assets_page.dart',
    'lib/features/dashboard/presentation/pages/more_page.dart',
    'lib/features/dashboard/presentation/pages/profile_page.dart',
]

for p in parts:
    with open(p, 'r', encoding='utf-8') as f:
        c = f.read()
    
    extra_imports = imports + "\nimport 'package:fbr_tax_helper/core/utils/currency_formatter.dart';"
    if p == 'lib/features/khata/presentation/pages/khata_page.dart' or p == 'lib/features/assets/presentation/pages/assets_page.dart':
        # They don't need Transaction unprefixed usually, but let's just use extra_imports
        pass
    
    c = re.sub(r"^part of '.*?';\s*", extra_imports + "\n\n", c)
    c = c.replace('_formatDashboardMoney', 'formatMoney')
    c = c.replace('_formatNumber', 'formatMoney')
    
    with open(p, 'w', encoding='utf-8') as f:
        f.write(c)

print("Decoupling and format methods extracted successfully.")
