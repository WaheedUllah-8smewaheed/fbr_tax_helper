import os
import re

dashboard_file = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'
all_txn_file = 'lib/features/transactions/presentation/pages/all_transactions_page.dart'

with open(dashboard_file, 'r', encoding='utf-8') as f:
    dashboard_code = f.read()

# 1. Find the split point
split_keyword = "enum TransactionTypeFilter {"
split_index = dashboard_code.find(split_keyword)

if split_index != -1:
    extracted_code = dashboard_code[split_index:]
    dashboard_code = dashboard_code[:split_index]
    
    # 2. Rename private classes in the extracted code so they can be exported
    extracted_code = extracted_code.replace('_PrintTransactionsButton', 'PrintTransactionsButton')
    extracted_code = extracted_code.replace('_TransactionList', 'TransactionList')
    
    # Also update their usage in dashboard_code
    dashboard_code = dashboard_code.replace('_PrintTransactionsButton', 'PrintTransactionsButton')
    dashboard_code = dashboard_code.replace('_TransactionList', 'TransactionList')

    # 3. Rename private pages in their own files and dashboard usages
    # _AllTransactionsPage -> AllTransactionsPage
    dashboard_code = dashboard_code.replace('_AllTransactionsPage', 'AllTransactionsPage')
    dashboard_code = dashboard_code.replace('_ComparisonDashboardPage', 'ComparisonDashboardPage')
    dashboard_code = dashboard_code.replace('_MorePage', 'MorePage')
    dashboard_code = dashboard_code.replace('_ProfilePage', 'ProfilePage')

    with open(dashboard_file, 'w', encoding='utf-8') as f:
        f.write(dashboard_code)

    # 4. Append extracted code to all_transactions_page.dart
    with open(all_txn_file, 'r', encoding='utf-8') as f:
        all_txn_code = f.read()
    
    # Rename the class inside its own file
    all_txn_code = all_txn_code.replace('_AllTransactionsPage', 'AllTransactionsPage')
    all_txn_code = all_txn_code.replace('_TransactionList', 'TransactionList')
    
    all_txn_code += "\n\n" + extracted_code

    with open(all_txn_file, 'w', encoding='utf-8') as f:
        f.write(all_txn_code)

print("Extraction and renaming complete.")
