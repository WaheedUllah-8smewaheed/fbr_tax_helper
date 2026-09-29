import os
import re

dashboard_file = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'

# Extract imports from dashboard_screen.dart
with open(dashboard_file, 'r', encoding='utf-8') as f:
    dashboard_code = f.read()

# Find all imports in dashboard
imports = "\n".join(re.findall(r"^import '.*?';$", dashboard_code, flags=re.MULTILINE))
# Also include package:intl/intl.dart if not present (usually it is)
if "import 'package:intl/intl.dart';" not in imports:
    imports += "\nimport 'package:intl/intl.dart';"

# List of parts
parts = [
    'lib/features/transactions/presentation/pages/all_transactions_page.dart',
    'lib/features/khata/presentation/pages/khata_page.dart',
    'lib/features/assets/presentation/pages/assets_page.dart',
    'lib/features/dashboard/presentation/pages/more_page.dart',
    'lib/features/dashboard/presentation/pages/profile_page.dart',
    'lib/features/transactions/presentation/pages/comparison_dashboard_page.dart'
]

# Process each part
for part_path in parts:
    with open(part_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove `part of` directive and prepend imports
    content = re.sub(r"^part of '.*?';\s*", imports + "\n\n", content)
    
    with open(part_path, 'w', encoding='utf-8') as f:
        f.write(content)

# Update dashboard_screen.dart
# Remove `part` directives
new_dashboard_code = re.sub(r"^part '.*?';\n", "", dashboard_code, flags=re.MULTILINE)

# Add imports for the newly independent pages
page_imports = """
import 'package:fbr_tax_helper/features/transactions/presentation/pages/all_transactions_page.dart';
import 'package:fbr_tax_helper/features/khata/presentation/pages/khata_page.dart';
import 'package:fbr_tax_helper/features/assets/presentation/pages/assets_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/more_page.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/profile_page.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/comparison_dashboard_page.dart';
"""

# Insert page imports after the last import
last_import_index = new_dashboard_code.rfind("import '")
if last_import_index != -1:
    end_of_last_import = new_dashboard_code.find(";", last_import_index) + 1
    new_dashboard_code = new_dashboard_code[:end_of_last_import] + "\n" + page_imports + new_dashboard_code[end_of_last_import:]

with open(dashboard_file, 'w', encoding='utf-8') as f:
    f.write(new_dashboard_code)

print("Decoupling complete.")
