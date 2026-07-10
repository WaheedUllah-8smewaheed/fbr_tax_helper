import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';

void main() {
  test('filters transactions by selected month', () {
    final transactions = [
      Transaction(
        userId: '1',
        title: 'Salary',
        beneficiary: 'Employer',
        purpose: 'Pay',
        amount: 50000,
        isExpense: false,
        date: DateTime(2025, 1, 10),
        category: 'Salary',
      ),
      Transaction(
        userId: '1',
        title: 'Rent',
        beneficiary: 'Landlord',
        purpose: 'Housing',
        amount: 15000,
        isExpense: true,
        date: DateTime(2025, 2, 5),
        category: 'Housing & Utils',
      ),
      Transaction(
        userId: '1',
        title: 'Groceries',
        beneficiary: 'Store',
        purpose: 'Food',
        amount: 3000,
        isExpense: true,
        date: DateTime(2025, 2, 12),
        category: 'Food & Drinks',
      ),
    ];

    final filtered = filterTransactionsByMonth(
      transactions,
      DateTime(2025, 2),
    );

    expect(filtered.length, 2);
    expect(filtered.every((transaction) => transaction.date.month == 2), isTrue);
  });
}
