import os
import glob

test_files = glob.glob('test/**/*.dart', recursive=True)

for filepath in test_files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    changed = False
    
    if 'import \'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart\';' in content:
        if 'TransactionTypeFilter' in content and 'import \'package:fbr_tax_helper/features/transactions/presentation/pages/transactions_page.dart\';' not in content:
            content = content.replace('import \'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart\';', 
                                      'import \'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart\';\nimport \'package:fbr_tax_helper/features/transactions/presentation/pages/transactions_page.dart\';')
            changed = True
            
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

print("Test imports fixed")
