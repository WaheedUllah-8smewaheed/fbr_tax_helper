import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

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

    final filtered = filterTransactionsByMonth(transactions, DateTime(2025, 2));

    expect(filtered.length, 2);
    expect(
      filtered.every((transaction) => transaction.date.month == 2),
      isTrue,
    );
  });

  test(
    'category percentage uses total activity instead of the largest bar',
    () {
      expect(categoryShareOfActivity(200, 1000), closeTo(0.2, 0.0001));
      expect(categoryShareOfActivity(600, 1000), closeTo(0.6, 0.0001));
      expect(categoryShareOfActivity(0, 1000), 0);
      expect(categoryShareOfActivity(100, 0), 0);
    },
  );

  test('transaction selection filters chart and print data consistently', () {
    final preferences = CategoryPreferencesService();
    addTearDown(preferences.dispose);
    final transactions = [
      Transaction(
        userId: '1',
        title: 'Salary',
        beneficiary: '',
        purpose: '',
        amount: 50000,
        isExpense: false,
        date: DateTime(2025, 2, 1),
        category: 'Salary',
      ),
      Transaction(
        userId: '1',
        title: 'Groceries',
        beneficiary: '',
        purpose: '',
        amount: 5000,
        isExpense: true,
        date: DateTime(2025, 2, 2),
        category: 'Groceries',
      ),
      Transaction(
        userId: '1',
        title: 'Gift Given',
        beneficiary: '',
        purpose: '',
        amount: 1000,
        isExpense: true,
        date: DateTime(2025, 2, 3),
        category: 'Gift Given',
      ),
    ];

    expect(
      filterTransactionsForSelection(
        transactions,
        TransactionTypeFilter.income,
        preferences,
      ).map((transaction) => transaction.title),
      ['Salary'],
    );
    expect(
      filterTransactionsForSelection(
        transactions,
        TransactionTypeFilter.expense,
        preferences,
      ).map((transaction) => transaction.title),
      ['Groceries'],
    );
    expect(
      filterTransactionsForSelection(
        transactions,
        TransactionTypeFilter.both,
        preferences,
      ).map((transaction) => transaction.title),
      ['Gift Given'],
    );
  });

  test('finds a transaction only when it exceeds half the period total', () {
    Transaction transaction(String title, double amount) => Transaction(
      userId: '1',
      title: title,
      beneficiary: '',
      purpose: '',
      amount: amount,
      isExpense: true,
      date: DateTime(2026, 1, 1),
      category: 'General',
    );

    final dominant = transaction('Rent', 600);
    final remaining = transaction('Other', 400);
    expect(findDominantTransaction([dominant, remaining], 1000), dominant);

    final exactlyHalf = transaction('Exactly half', 500);
    expect(findDominantTransaction([exactlyHalf, remaining], 1000), isNull);
    expect(findDominantTransaction(const [], 0), isNull);
  });
}
