import os
import re

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# TransactionList starts at class TransactionList
idx1 = content.find('class TransactionList extends StatelessWidget')
if idx1 != -1:
    end_idx1 = content.find('class DashboardScreen extends StatefulWidget', idx1)
    if end_idx1 == -1:
        end_idx1 = len(content)
    
    extracted1 = content[idx1:end_idx1]
    content = content[:idx1] + content[end_idx1:]
else:
    extracted1 = ""

idx2 = content.find('class PrintTransactionsButton extends StatefulWidget')
if idx2 != -1:
    end_idx2 = content.find('class IncomeExpensePiePanel', idx2)
    extracted2 = content[idx2:end_idx2]
    content = content[:idx2] + content[end_idx2:]
else:
    extracted2 = ""

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

header = '''import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/tax_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/domain/entities/transaction_category.dart';
import '../../../categories/presentation/bloc/category_preferences_service.dart';
import '../../../khata/domain/entities/asset.dart';
import '../../../khata/domain/entities/khata_entry.dart';
import '../../domain/entities/transaction.dart' as entity;
import '../bloc/transaction_bloc.dart';
import 'add_transaction_page.dart';
import 'all_transactions_page.dart';
import 'transaction_report_service.dart';

'''

with open('lib/features/transactions/presentation/pages/transaction_widgets.dart', 'w', encoding='utf-8') as f:
    f.write(header + extracted2 + '\\n\\n' + extracted1)

print("Extracted Transaction Widgets")
