import glob

for f_name in glob.glob('lib/features/transactions/presentation/pages/*.dart'):
    with open(f_name, 'r', encoding='utf-8') as f:
        c = f.read()
    if 'domain/entities/transaction.dart' not in c:
        c = "import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;\n" + c
        with open(f_name, 'w', encoding='utf-8') as f:
            f.write(c)
