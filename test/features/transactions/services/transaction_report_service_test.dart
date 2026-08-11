import 'dart:convert';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';
import 'package:fbr_tax_helper/features/transactions/services/transaction_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a printable PDF from filtered transaction data', () async {
    final transactions = [
      Transaction(
        id: 7,
        userId: 'user-1',
        title: 'Grocery receipt',
        beneficiary: 'Fresh Mart',
        purpose: 'Weekly groceries',
        amount: 2450,
        isExpense: true,
        date: DateTime(2026, 7, 12),
        category: 'Groceries',
      ),
      Transaction(
        id: 8,
        userId: 'user-1',
        title: 'Monthly salary',
        beneficiary: 'Employer',
        purpose: 'Salary payment',
        amount: 150000,
        isExpense: false,
        date: DateTime(2026, 7, 1),
        category: 'Basic Pay',
      ),
    ];

    final bytes = await const TransactionReportService().buildReport(
      transactions: transactions,
      filterLabel: 'July 2026',
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('builds a comparison PDF for two selected periods', () async {
    Transaction transaction(DateTime date, double amount, bool isExpense) {
      return Transaction(
        userId: 'user-1',
        title: isExpense ? 'Expense' : 'Income',
        beneficiary: '',
        purpose: '',
        amount: amount,
        isExpense: isExpense,
        date: date,
        category: 'General',
      );
    }

    final bytes = await const TransactionReportService().buildComparisonReport(
      firstTransactions: [
        transaction(DateTime(2026, 6, 1), 100000, false),
        transaction(DateTime(2026, 6, 4), 30000, true),
      ],
      secondTransactions: [
        transaction(DateTime(2026, 7, 1), 120000, false),
        transaction(DateTime(2026, 7, 4), 45000, true),
      ],
      firstLabel: 'Jun 2026',
      secondLabel: 'Jul 2026',
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
