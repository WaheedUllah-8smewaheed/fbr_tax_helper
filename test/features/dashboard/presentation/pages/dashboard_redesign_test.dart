import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart' as entity;

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

  testWidgets('IncomeExpensePiePanel renders Donut chart, Balance in center, and Expenses vs Income highlight',
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
    expect(find.text('Balance'), findsWidgets);
    expect(find.text('-PKR 10,000'), findsOneWidget);
    expect(find.text('Expenses vs Income'), findsOneWidget);
    expect(find.text('103%'), findsOneWidget);
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
}
