import os
import re

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    dashboard_content = f.read()

# Extract all imports from dashboard_screen.dart
import_lines = []
for line in dashboard_content.splitlines():
    if line.startswith('import '):
        # ignore the imports we just added for transaction pages to avoid circular imports
        if 'transactions_page.dart' in line or 'transaction_widgets.dart' in line:
            continue
        import_lines.append(line)
        
imports_str = '\n'.join(import_lines)

def replace_imports(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove old imports
    new_lines = []
    in_imports = True
    for line in content.splitlines():
        if line.startswith('import '):
            continue
        if line.strip() == '' and in_imports:
            continue
        if line.strip() != '' and not line.startswith('import '):
            in_imports = False
        new_lines.append(line)
        
    final_content = imports_str + '\n\n' + '\n'.join(new_lines)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(final_content)

replace_imports('lib/features/transactions/presentation/pages/transactions_page.dart')
replace_imports('lib/features/transactions/presentation/pages/transaction_widgets.dart')
print("Imports replaced in both files")
