filepath = 'lib/features/transactions/presentation/pages/all_transactions_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    \"import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\",
    \"import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';\\nimport 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';\"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
