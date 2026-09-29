import os
import glob

# Fix transactions_page.dart
t_page = 'lib/features/transactions/presentation/pages/transactions_page.dart'
with open(t_page, 'r', encoding='utf-8') as f:
    t_content = f.read()

# Fix semicolon on line 8
t_content = t_content.replace(
    \"import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'\\n\",
    \"import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;\\n\"
)
if \"import 'transaction_widgets.dart';\" not in t_content:
    last_import = t_content.rfind('import ')
    end_of_last_import = t_content.find('\\n', last_import)
    t_content = t_content[:end_of_last_import] + '\\nimport \\'transaction_widgets.dart\\';\\nimport \\'all_transactions_page.dart\\';' + t_content[end_of_last_import:]

with open(t_page, 'w', encoding='utf-8') as f:
    f.write(t_content)

# Fix transaction_widgets.dart
w_page = 'lib/features/transactions/presentation/pages/transaction_widgets.dart'
with open(w_page, 'r', encoding='utf-8') as f:
    w_content = f.read()

w_content = w_content.replace(
    \"import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'\\n\",
    \"import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;\\n\"
)
with open(w_page, 'w', encoding='utf-8') as f:
    f.write(w_content)

# Fix tests
test_files = glob.glob('test/**/*.dart', recursive=True)
for filepath in test_files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    changed = False
    if \"import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\" in content:
        if \"import 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';\" not in content:
            content = content.replace(
                \"import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\",
                \"import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\\nimport 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';\"
            )
            changed = True
            
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

print(\"All fixed\")
