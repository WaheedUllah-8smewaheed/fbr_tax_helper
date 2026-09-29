with open('lib/features/transactions/presentation/pages/transactions_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('enum TransactionTypeFilter { income, expense }\\n\\n', '')
content = content.replace('enum TransactionTypeFilter { income, expense }\\n', '')
content = content.replace('enum TransactionTypeFilter { income, expense }\n\n', '')
content = content.replace('enum TransactionTypeFilter { income, expense }\n', '')
content = content.replace('enum TransactionTypeFilter { income, expense }\\\\n\\\\n', '')

content = content.replace('class TransactionsPage extends StatefulWidget', 'enum TransactionTypeFilter { income, expense }\n\nclass TransactionsPage extends StatefulWidget')

with open('lib/features/transactions/presentation/pages/transactions_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/transactions/presentation/pages/transaction_widgets.dart', 'r', encoding='utf-8') as f:
    content2 = f.read()
content2 = content2.replace('\\n\\n', '\n\n')
content2 = content2.replace('\\\\n\\\\n', '\n\n')
with open('lib/features/transactions/presentation/pages/transaction_widgets.dart', 'w', encoding='utf-8') as f:
    f.write(content2)

print("Fixed")
