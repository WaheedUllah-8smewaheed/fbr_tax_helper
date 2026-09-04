import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  test('calculates income and expense totals for the visible transactions', () {
    final totals = calculateTransactionFilterTotals([
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
        title: 'Rent',
        beneficiary: '',
        purpose: '',
        amount: 15000,
        isExpense: true,
        date: DateTime(2025, 2, 2),
        category: 'Housing & Utils',
      ),
    ]);

    expect(totals.income, 50000);
    expect(totals.expenses, 15000);
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

  test('parent category reports include all of its subcategories', () {
    Transaction transaction(String category) => Transaction(
      userId: '1',
      title: category,
      beneficiary: '',
      purpose: '',
      amount: 100,
      isExpense: false,
      date: DateTime(2026, 1, 1),
      category: category,
    );

    expect(
      [transaction('Salary'), transaction('Bonus'), transaction('Groceries')]
          .where(
            (value) => transactionBelongsToCategory(
              value,
              'Salary',
              includeSubcategories: true,
            ),
          )
          .map((value) => value.category),
      ['Salary', 'Bonus'],
    );
    expect(
      transactionBelongsToCategory(
        transaction('Bonus'),
        'Salary',
        includeSubcategories: false,
      ),
      isFalse,
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

  group('resolveCategoryMode', () {
    late CategoryPreferencesService preferences;

    setUp(() {
      preferences = CategoryPreferencesService();
    });

    tearDown(() {
      preferences.dispose();
    });

    test('returns both when category is null (all transactions)', () {
      expect(
        resolveCategoryMode(
          categoryName: null,
          categoryPreferences: preferences,
        ),
        CategoryMode.both,
      );
    });

    test('returns expense for expense parent and subcategories', () {
      expect(
        resolveCategoryMode(
          categoryName: 'Bills',
          categoryPreferences: preferences,
        ),
        CategoryMode.expense,
      );
      expect(
        resolveCategoryMode(
          categoryName: 'Electricity',
          categoryPreferences: preferences,
        ),
        CategoryMode.expense,
      );
      expect(
        resolveCategoryMode(
          categoryName: 'Doctor',
          categoryPreferences: preferences,
        ),
        CategoryMode.expense,
      );
    });

    test('returns income for income parent and subcategories', () {
      expect(
        resolveCategoryMode(
          categoryName: 'Salary',
          categoryPreferences: preferences,
        ),
        CategoryMode.income,
      );
      expect(
        resolveCategoryMode(
          categoryName: 'Bonus',
          categoryPreferences: preferences,
        ),
        CategoryMode.income,
      );
      expect(
        resolveCategoryMode(
          categoryName: 'Business Income',
          categoryPreferences: preferences,
        ),
        CategoryMode.income,
      );
    });

    test('returns both for dual-mode parent and subcategories', () {
      expect(
        resolveCategoryMode(
          categoryName: 'Gifts',
          categoryPreferences: preferences,
        ),
        CategoryMode.both,
      );
      expect(
        resolveCategoryMode(
          categoryName: 'Gift Given',
          categoryPreferences: preferences,
        ),
        CategoryMode.both,
      );
    });

    test('returns mode correctly for custom subcategories', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await preferences.loadForUser('test-user');
      await preferences.addSubcategory(
        parentName: 'Bills',
        categoryName: 'Solar Panel Maintenance',
      );

      expect(
        resolveCategoryMode(
          categoryName: 'Solar Panel Maintenance',
          categoryPreferences: preferences,
        ),
        CategoryMode.expense,
      );
    });
  });

  group('Financial Year and Month Dashboard Filters', () {
    final t1 = Transaction(
      userId: '1',
      title: 'Salary Jul 2024',
      beneficiary: '',
      purpose: '',
      amount: 100000,
      isExpense: false,
      date: DateTime(2024, 7, 15),
      category: 'Salary',
    );
    final t2 = Transaction(
      userId: '1',
      title: 'Salary Feb 2025',
      beneficiary: '',
      purpose: '',
      amount: 100000,
      isExpense: false,
      date: DateTime(2025, 2, 10),
      category: 'Salary',
    );
    final t3 = Transaction(
      userId: '1',
      title: 'Salary Jul 2025',
      beneficiary: '',
      purpose: '',
      amount: 120000,
      isExpense: false,
      date: DateTime(2025, 7, 15),
      category: 'Salary',
    );

    final transactions = [t1, t2, t3];

    test('getFinancialYear determines FY correctly', () {
      expect(getFinancialYear(DateTime(2024, 7, 1)), '2024-25');
      expect(getFinancialYear(DateTime(2024, 12, 31)), '2024-25');
      expect(getFinancialYear(DateTime(2025, 1, 1)), '2024-25');
      expect(getFinancialYear(DateTime(2025, 6, 30)), '2024-25');
      expect(getFinancialYear(DateTime(2025, 7, 1)), '2025-26');
    });

    test('buildFinancialYearOptions collects distinct sorted FYs', () {
      final options = buildFinancialYearOptions(transactions);
      expect(options.contains('2024-25'), isTrue);
      expect(options.contains('2025-26'), isTrue);
    });

    test('filterDashboardTransactions filters by FY only', () {
      final fy202425 = filterDashboardTransactions(
        transactions,
        financialYear: '2024-25',
      );
      expect(fy202425, [t1, t2]);

      final fy202526 = filterDashboardTransactions(
        transactions,
        financialYear: '2025-26',
      );
      expect(fy202526, [t3]);
    });

    test('filterDashboardTransactions filters by Month only', () {
      final julys = filterDashboardTransactions(
        transactions,
        month: 7,
      );
      expect(julys, [t1, t3]);

      final febs = filterDashboardTransactions(
        transactions,
        month: 2,
      );
      expect(febs, [t2]);
    });

    test('filterDashboardTransactions filters by both FY and Month', () {
      final result = filterDashboardTransactions(
        transactions,
        financialYear: '2024-25',
        month: 7,
      );
      expect(result, [t1]);
    });

    test('filterDashboardTransactions returns all when no filters selected', () {
      final result = filterDashboardTransactions(transactions);
      expect(result.length, 3);
    });
  });
}
