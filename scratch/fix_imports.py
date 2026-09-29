import os

def add_imports(filepath, imports):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    last_import_idx = content.rfind('import ')
    if last_import_idx != -1:
        end_of_last_import = content.find('\n', last_import_idx)
        content = content[:end_of_last_import] + '\n' + imports + content[end_of_last_import:]
    else:
        content = imports + '\n' + content
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

add_imports('lib/features/dashboard/presentation/pages/dashboard_screen.dart', "import '../../../../features/transactions/presentation/pages/transactions_page.dart';\nimport '../../../../features/transactions/presentation/pages/transaction_widgets.dart';\n")
add_imports('lib/features/khata/presentation/pages/khata_page.dart', "import '../../../../features/transactions/presentation/pages/transactions_page.dart';\n")

print("Imports fixed")
