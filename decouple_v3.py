import os
import re

# 1. Dashboard screen
dashboard_file = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'
with open(dashboard_file, 'r', encoding='utf-8') as f:
    dashboard_code = f.read()

# Replace currency formatting usages in dashboard
dashboard_code = dashboard_code.replace('_formatDashboardMoney', 'formatMoney')
dashboard_code = dashboard_code.replace('_formatNetBalance', 'formatNetBalance')

# Remove currency formatting implementations and enum _ComparisonScope
dashboard_code = re.sub(r'String formatMoney\(num value\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'String _formatNumber\(num value\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'String formatNetBalance\(double netBalance\) \{.*?\n\}\n', '', dashboard_code, flags=re.DOTALL)
dashboard_code = re.sub(r'enum _ComparisonScope \{ overall, category \}\n', '', dashboard_code)

# Extract existing imports (fixing the regex to include 'as entity' etc.)
# We just match any line starting with import and ending with ;
imports = "\n".join(re.findall(r"^import .*?;$", dashboard_code, flags=re.MULTILINE))

# Remove part directives from dashboard
dashboard_code = re.sub(r"^part '.*?';\n", "", dashboard_code, flags=re.MULTILINE)

# Add our new imports to dashboard
new_dashboard_imports = """
import 'package:fbr_tax_helper/core/utils/currency_formatter.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/all_transactions_page.dart';
import 'package:fbr_tax_helper/features/khata/presentation/pages/khata_page.dart';
import 'package:fbr_tax_helper/features/assets/presentation/pages/assets_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/more_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/profile_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/comparison_dashboard_page.dart';
"""
dashboard_code = re.sub(r"(import 'package:flutter_bloc/flutter_bloc.dart';)", r"\1" + new_dashboard_imports, dashboard_code)

with open(dashboard_file, 'w', encoding='utf-8') as f:
    f.write(dashboard_code)

# 2. Process all parts
parts = {
    'lib/features/transactions/presentation/pages/all_transactions_page.dart': 'AllTransactionsPage',
    'lib/features/transactions/presentation/pages/comparison_dashboard_page.dart': 'ComparisonDashboardPage',
    'lib/features/khata/presentation/pages/khata_page.dart': '_KhataPage', # keep private or rename? user didn't ask but let's rename to KhataPage
    'lib/features/assets/presentation/pages/assets_page.dart': '_AssetsPage',
    'lib/features/dashboard/presentation/pages/more_page.dart': 'MorePage',
    'lib/features/dashboard/presentation/pages/profile_page.dart': 'ProfilePage',
}

for part_path, class_name in parts.items():
    with open(part_path, 'r', encoding='utf-8') as f:
        c = f.read()
    
    # Add imports
    extra_imports = imports + "\nimport 'package:fbr_tax_helper/core/utils/currency_formatter.dart';\n"
    if 'comparison_dashboard' in part_path:
        extra_imports += "\nimport 'dart:math' as math;\n"
        extra_imports += "\nenum _ComparisonScope { overall, category }\n"
        c = c.replace('_ComparisonDashboardPage', 'ComparisonDashboardPage')

    if 'more_page' in part_path:
        c = c.replace('_MorePage', 'MorePage')
        c = c.replace('_ComparisonDashboardPage', 'ComparisonDashboardPage')
    
    if 'profile_page' in part_path:
        c = c.replace('_ProfilePage', 'ProfilePage')
        c = c.replace('_DriveSyncButton', 'DriveSyncButton') # if any
        c = c.replace('_DriveAction', 'DriveAction')

    if 'khata_page' in part_path:
        extra_imports += "\nimport 'package:fbr_tax_helper/features/transactions/presentation/pages/all_transactions_page.dart';\n"
    
    c = re.sub(r"^part of '.*?';\s*", extra_imports + "\n\n", c)
    c = c.replace('_formatDashboardMoney', 'formatMoney')
    c = c.replace('_formatNetBalance', 'formatNetBalance')
    c = c.replace('_formatNumber', 'formatMoney')
    
    with open(part_path, 'w', encoding='utf-8') as f:
        f.write(c)

print("Decouple v3 complete.")
