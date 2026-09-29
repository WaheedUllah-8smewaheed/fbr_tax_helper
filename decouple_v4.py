import os
import re
import glob

# Replace specific private definitions with public ones in dashboard_screen.dart
dashboard_file = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'
with open(dashboard_file, 'r', encoding='utf-8') as f:
    dashboard_code = f.read()

# Make methods and classes public
replacements = {
    r'\b_buildMonthOptions\b': 'buildMonthOptions',
    r'\b_monthLabel\b': 'monthLabel',
    r'\b_PrintTransactionsButton\b': 'PrintTransactionsButton',
    r'\b_PrintTransactionsButtonState\b': 'PrintTransactionsButtonState',
    r'\b_TransactionList\b': 'TransactionList',
    r'\b_ComparisonScope\b': 'ComparisonScope',
    r'\b_KhataPage\b': 'KhataPage',
    r'\b_KhataPageState\b': 'KhataPageState',
    r'\b_AssetsPage\b': 'AssetsPage',
    r'\b_AssetsPageState\b': 'AssetsPageState',
    r'\b_MorePage\b': 'MorePage',
    r'\b_MorePageState\b': 'MorePageState',
    r'\b_ProfilePage\b': 'ProfilePage',
    r'\b_ProfilePageState\b': 'ProfilePageState',
    r'\b_AllTransactionsPage\b': 'AllTransactionsPage',
    r'\b_AllTransactionsPageState\b': 'AllTransactionsPageState',
    r'\b_ComparisonDashboardPage\b': 'ComparisonDashboardPage',
    r'\b_ComparisonDashboardPageState\b': 'ComparisonDashboardPageState',
    r'\b_formatDashboardMoney\b': 'formatMoney',
    r'\b_formatNumber\b': 'formatMoney',
    r'\b_formatNetBalance\b': 'formatNetBalance',
    r'\b_formatPieBalance\b': 'formatPieBalance',
    r'\b_CategorySettingsPage\b': 'CategorySettingsPage',
    r'\b_getIconForCategory\b': 'getIconForCategory',
    r'\b_DriveSyncButton\b': 'DriveSyncButton',
    r'\b_DriveAction\b': 'DriveAction'
}

for old, new in replacements.items():
    dashboard_code = re.sub(old, new, dashboard_code)

# Remove part directives
dashboard_code = re.sub(r"^part '.*?';\n", "", dashboard_code, flags=re.MULTILINE)

# Extract imports
imports = "\n".join(re.findall(r"^import .*?;$", dashboard_code, flags=re.MULTILINE))

# Add part imports as regular imports to dashboard_screen.dart
new_dashboard_imports = """
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


# Process parts
part_files = [
    'lib/features/transactions/presentation/pages/all_transactions_page.dart',
    'lib/features/transactions/presentation/pages/comparison_dashboard_page.dart',
    'lib/features/khata/presentation/pages/khata_page.dart',
    'lib/features/assets/presentation/pages/assets_page.dart',
    'lib/features/dashboard/presentation/pages/more_page.dart',
    'lib/features/dashboard/presentation/pages/profile_page.dart',
]

for part_path in part_files:
    with open(part_path, 'r', encoding='utf-8') as f:
        c = f.read()
    
    for old, new in replacements.items():
        c = re.sub(old, new, c)
    
    extra_imports = imports + "\nimport 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\n"
    
    c = re.sub(r"^part of '.*?';\s*", extra_imports + "\n\n", c)
    
    with open(part_path, 'w', encoding='utf-8') as f:
        f.write(c)

print("Decoupling applied.")
