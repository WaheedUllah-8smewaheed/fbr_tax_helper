import os
import re

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# TransactionsPage starts at class TransactionsPage
idx = content.find('class TransactionsPage extends StatefulWidget')
# Ends after _AnimatedTransactionCategoryCardState
end_idx = content.find('class _HomeDashboard extends StatefulWidget', idx)

extracted = content[idx:end_idx]

# Remove it from dashboard_screen.dart
new_content = content[:idx] + content[end_idx:]

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

header = '''import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/tax_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/domain/entities/transaction_category.dart';
import '../../../categories/presentation/bloc/category_preferences_service.dart';
import '../../../categories/presentation/pages/category_settings_page.dart';
import '../../domain/entities/transaction.dart' as entity;
import '../bloc/transaction_bloc.dart';
import 'add_transaction_page.dart';
import 'all_transactions_page.dart';

enum TransactionTypeFilter { income, expense }

'''

# Actually, the enum TransactionTypeFilter is in dashboard_screen.dart. Let's see if we need to extract it.
enum_idx = new_content.find('enum TransactionTypeFilter')
if enum_idx != -1:
    enum_end = new_content.find('}', enum_idx) + 1
    enum_str = new_content[enum_idx:enum_end]
    # Remove enum from dashboard_screen
    new_content = new_content[:enum_idx] + new_content[enum_end:]
    with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
else:
    enum_str = 'enum TransactionTypeFilter { income, expense }'

with open('lib/features/transactions/presentation/pages/transactions_page.dart', 'w', encoding='utf-8') as f:
    f.write(header + enum_str + '\\n\\n' + extracted)

print("Extracted TransactionsPage")
