import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;
import 'package:fbr_tax_helper/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';

class FakeAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

class FakeTransactionRepository implements TransactionRepository {
  final List<entity.Transaction> _transactions = [];

  @override
  Future<List<entity.Transaction>> getTransactions(String userId) async =>
      _transactions;

  @override
  Future<void> addTransaction(entity.Transaction transaction) async {
    _transactions.add(transaction);
  }

  @override
  Future<void> updateTransaction(entity.Transaction transaction) async {}

  @override
  Future<void> deleteTransaction({
    required int id,
    required String userId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final sampleTransactions = <entity.Transaction>[
    entity.Transaction(
      id: 1,
      userId: 'user-1',
      title: 'Monthly Salary',
      amount: 300000,
      date: DateTime(now.year, now.month, 5),
      category: 'Salary',
      beneficiary: 'Employer',
      purpose: 'Income',
      isExpense: false,
    ),
    entity.Transaction(
      id: 2,
      userId: 'user-1',
      title: 'Office Rent',
      amount: 250000,
      date: DateTime(now.year, now.month, 10),
      category: 'Rent',
      beneficiary: 'Landlord',
      purpose: 'Monthly rent',
      isExpense: true,
    ),
    entity.Transaction(
      id: 3,
      userId: 'user-1',
      title: 'Electricity Bill',
      amount: 60000,
      date: DateTime(now.year, now.month, 12),
      category: 'Electricity',
      beneficiary: 'Power Company',
      purpose: 'Utility',
      isExpense: true,
    ),
  ];

  testWidgets('SummaryCards renders Income, Expenses, and Net Balance KPI metric cards',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCards(transactions: sampleTransactions),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net Balance'), findsOneWidget);
    expect(find.text('PKR 300,000'), findsOneWidget);
    expect(find.text('PKR 310,000'), findsOneWidget);
    expect(find.text('-PKR 10,000'), findsOneWidget);
    expect(find.text('You spent more than you earned'), findsOneWidget);
  });

  testWidgets('IncomeExpensePiePanel renders Donut chart with Net Balance, Net Deficit/Surplus, and Spent chips',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomeExpensePiePanel(transactions: sampleTransactions),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expenses vs Balance'), findsOneWidget);
    expect(find.text('Net Balance'), findsOneWidget);
    expect(find.text('-PKR 10,000'), findsOneWidget);
    expect(find.text('Net Deficit'), findsOneWidget);
    expect(find.text('-PKR 10,000 (0% remaining)'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('PKR 310,000 (103.33% spent)'), findsOneWidget);
  });

  test('IncomeExpensePiePanel.formatPiePercentage formats up to 2 decimal places', () {
    expect(IncomeExpensePiePanel.formatPiePercentage(24.25), '24.25');
    expect(IncomeExpensePiePanel.formatPiePercentage(24.0), '24');
    expect(IncomeExpensePiePanel.formatPiePercentage(0.0), '0');
    expect(IncomeExpensePiePanel.formatPiePercentage(100.0), '100');
    expect(IncomeExpensePiePanel.formatPiePercentage(103.3333), '103.33');
    expect(IncomeExpensePiePanel.formatPiePercentage(24.256), '24.26');
  });

  testWidgets('NetLossAlertBanner renders over budget loss information',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NetLossAlertBanner(
            totalIncome: 300000,
            totalExpenses: 310000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Net Loss'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('You are over budget by'),
      ),
      findsOneWidget,
    );
    expect(find.text('PKR 10,000'), findsOneWidget);
  });

  testWidgets('IncomeVsExpensesComparisonPanel renders comparison bars without Overview or Tip',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IncomeVsExpensesComparisonPanel(
            totalIncome: 300000,
            totalExpenses: 310000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Income vs Expenses Comparison'), findsOneWidget);
    expect(find.text('Percentage of Income'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Tip'), findsNothing);
  });

  testWidgets('TopCategoryCharts renders 2 distinct graphs for Income and Expense',
      (tester) async {
    String? tappedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TopCategoryCharts(
              transactions: sampleTransactions,
              onCategoryTap: (category) => tappedCategory = category,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 2 distinct sections exist
    expect(find.text('Top Income Categories'), findsOneWidget);
    expect(find.text('Top Expense Categories'), findsOneWidget);

    // Verify income categories are shown under income graph
    expect(find.text('Salary'), findsOneWidget);

    // Verify expense categories are shown under expense graph
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Electricity'), findsOneWidget);

    // Verify tapping category calls callback
    await tester.tap(find.text('Salary'));
    expect(tappedCategory, 'Salary');
  });

  testWidgets('DashboardScreen renders 5 navigation tabs and Transaction FAB',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final authService = FakeAuthService();
    final repo = FakeTransactionRepository();
    final bloc = TransactionBloc(
      transactionRepository: repo,
      authService: authService,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthService>.value(value: authService),
          RepositoryProvider<TransactionRepository>.value(value: repo),
        ],
        child: BlocProvider<TransactionBloc>.value(
          value: bloc,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 5 navigation tabs exist
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Khata'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // Verify profile button in Dashboard header
    final profileButton = find.byTooltip('Profile');
    expect(profileButton, findsOneWidget);
    await tester.tap(profileButton);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify circular + FAB on Dashboard opens Transactions
    final transactionFab = find.byType(FloatingActionButton);
    expect(transactionFab, findsOneWidget);
    await tester.tap(transactionFab);
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('View All Transactions'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Switch to Khata tab: NO floating button
    await tester.tap(find.text('Khata'));
    await tester.pumpAndSettle();
    expect(find.text('Khata Ledger'), findsOneWidget);
    expect(find.text('Add Payable'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Switch to Assets tab: FAB exists for adding assets
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();
    expect(find.text('Assets & Wealth'), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
    final assetFab = find.byType(FloatingActionButton);
    expect(assetFab, findsOneWidget);
    await tester.tap(assetFab);
    await tester.pumpAndSettle();
    expect(find.text('Add Asset'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Switch to More tab: NO profile button, NO FAB
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Tax Calculator'), findsOneWidget);
    expect(find.text('Comparison Dashboard'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('User'), findsNothing);
  });
}

