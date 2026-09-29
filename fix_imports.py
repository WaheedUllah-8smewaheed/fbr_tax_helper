import os
import re

# We need to find all the files that need 'as entity' and 'as math'
parts = [
    'lib/features/transactions/presentation/pages/comparison_dashboard_page.dart',
    'lib/features/transactions/presentation/pages/all_transactions_page.dart',
    'lib/features/khata/presentation/pages/khata_page.dart',
    'lib/features/assets/presentation/pages/assets_page.dart',
    'lib/features/dashboard/presentation/pages/more_page.dart',
    'lib/features/dashboard/presentation/pages/profile_page.dart',
]

missing_imports = """
import 'dart:math' as math;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;
"""

for p in parts:
    with open(p, 'r', encoding='utf-8') as f:
        c = f.read()
    
    # insert missing imports at the top
    c = missing_imports + c
    
    with open(p, 'w', encoding='utf-8') as f:
        f.write(c)

print("Imports added.")
