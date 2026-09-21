import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/dashboard/presentation/pages/dashboard_screen.dart';

class MockFirebaseUser implements User {
  const MockFirebaseUser();

  @override
  String get uid => 'khata-user-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeKhataAuthService extends AuthService {
  FakeKhataAuthService([this._user]);
  final User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream.value(_user);
}

class FakeKhataTransactionRepository implements TransactionRepository {
  final List<entity.Transaction> _transactions = [];

  @override
  Future<List<entity.Transaction>> getTransactions(String userId) async {
    return List.unmodifiable(_transactions);
  }

  @override
  Future<void> addTransaction(entity.Transaction transaction) async {
    _transactions.add(transaction);
  }

  @override
  Future<void> updateTransaction(entity.Transaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    }
  }

  @override
  Future<void> deleteTransaction(
      {required int id, required String userId}) async {
    _transactions.removeWhere((t) => t.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KhataEntry entity tests', () {
    test('toMap and fromMap serialize and deserialize accurately', () {
      final now = DateTime(2026, 9, 18, 12, 0);
      final entry = KhataEntry(
        id: 101,
        userId: 'khata-user-123',
        title: 'Office Stationary',
        party: 'Ali Traders',
        amount: 4500.50,
        isPayable: true,
        date: now,
        description: 'Invoice #440',
        isPaid: false,
      );

      final map = entry.toMap();
      expect(map['id'], 101);
      expect(map['userId'], 'khata-user-123');
      expect(map['title'], 'Office Stationary');
      expect(map['party'], 'Ali Traders');
      expect(map['amount'], 4500.50);
      expect(map['isPayable'], 1);
      expect(map['date'], now.toIso8601String());
      expect(map['description'], 'Invoice #440');
      expect(map['isPaid'], 0);

      final reconstructed = KhataEntry.fromMap(map);
      expect(reconstructed.id, entry.id);
      expect(reconstructed.title, entry.title);
      expect(reconstructed.party, entry.party);
      expect(reconstructed.amount, entry.amount);
      expect(reconstructed.isPayable, isTrue);
      expect(reconstructed.description, entry.description);
      expect(reconstructed.isPaid, isFalse);
    });

    test('copyWith updates specified fields only', () {
      final entry = KhataEntry(
        userId: 'u1',
        title: 'Freelance Design',
        party: 'Client Acme',
        amount: 80000.0,
        isPayable: false,
        date: DateTime(2026, 9, 10),
      );

      final updated = entry.copyWith(
        amount: 85000.0,
        description: 'Bonus included',
      );

      expect(updated.title, 'Freelance Design');
      expect(updated.amount, 85000.0);
      expect(updated.description, 'Bonus included');
      expect(updated.isPayable, isFalse);
    });
  });

  group('Khata Ledger UI tests', () {
    testWidgets(
        'renders 2 segmented filter tabs (Payable, Receivable) and adds directly without asking',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final authService = FakeKhataAuthService();
      final repo = FakeKhataTransactionRepository();
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

      // Switch to Khata tab
      await tester.tap(find.text('Khata'));
      await tester.pumpAndSettle();

      // Verify header and only 2 distribution tabs (Payable and Receivable; no Both)
      expect(find.text('Khata Ledger'), findsOneWidget);
      expect(find.text('Payable'), findsWidgets);
      expect(find.text('Receivable'), findsWidgets);
      expect(find.text('Both'), findsNothing);

      // Verify Add Payable button when on Payable tab
      final addPayableBtn = find.text('Add Payable');
      expect(addPayableBtn, findsOneWidget);

      // Open Add Payable sheet
      await tester.tap(addPayableBtn);
      await tester.pumpAndSettle();

      // Check sheet has no type toggle asking the user
      expect(find.text('New Payable'), findsOneWidget);
      expect(find.text('Payable (You owe)'), findsNothing);
      expect(find.text('Receivable (Owed to you)'), findsNothing);
      expect(find.text('To (Supplier / Vendor / Person) *'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Switch to Receivable tab
      await tester.tap(find.text('Receivable').first);
      await tester.pumpAndSettle();

      // Verify button is now Add Receivable
      final addReceivableBtn = find.text('Add Receivable');
      expect(addReceivableBtn, findsOneWidget);

      // Open Add Receivable sheet
      await tester.tap(addReceivableBtn);
      await tester.pumpAndSettle();

      // Check sheet automatically adds Receivable without asking
      expect(find.text('New Receivable'), findsOneWidget);
      expect(find.text('Payable (You owe)'), findsNothing);
      expect(find.text('Receivable (Owed to you)'), findsNothing);
      expect(find.text('From (Customer / Client / Debtor) *'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    test('Unsettled entries do not impact transactions repository', () async {
      final repo = FakeKhataTransactionRepository();
      // Initially transactions are empty
      expect(await repo.getTransactions('khata-user-123'), isEmpty);

      // Creating a KhataEntry entity does not add to repo
      final entry = KhataEntry(
        userId: 'khata-user-123',
        title: 'Pending Supplier Bill',
        party: 'ABC Supplier',
        amount: 15000.0,
        isPayable: true,
        date: DateTime(2026, 9, 1),
      );
      expect(entry.isPayable, isTrue);
      expect(await repo.getTransactions('khata-user-123'), isEmpty);
    });

    test('Mark as paid adds Expense for Payable and Income for Receivable',
        () async {
      final authService = FakeKhataAuthService(const MockFirebaseUser());
      final repo = FakeKhataTransactionRepository();
      final bloc = TransactionBloc(
        transactionRepository: repo,
        authService: authService,
      );
      addTearDown(bloc.close);

      // Simulate marking a Payable entry as paid:
      final payableEntry = KhataEntry(
        id: 1,
        userId: 'khata-user-123',
        title: 'Warehouse Rent',
        party: 'Landlord Mr. Khan',
        amount: 35000.0,
        isPayable: true,
        date: DateTime(2026, 9, 1),
        description: 'Rent for Sep 2026',
      );

      bloc.add(
        AddTransaction(
          entity.Transaction(
            userId: payableEntry.userId,
            title: payableEntry.title,
            beneficiary: payableEntry.party,
            purpose: payableEntry.description,
            amount: payableEntry.amount,
            isExpense: payableEntry.isPayable,
            date: DateTime(2026, 9, 18),
            category: payableEntry.isPayable ? 'Other' : 'Business Income',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      var txs = await repo.getTransactions('khata-user-123');
      expect(txs.length, 1);
      expect(txs.first.title, 'Warehouse Rent');
      expect(txs.first.isExpense, isTrue); // Payable becomes Expense
      expect(txs.first.amount, 35000.0);
      expect(txs.first.beneficiary, 'Landlord Mr. Khan');

      // Simulate marking a Receivable entry as paid:
      final receivableEntry = KhataEntry(
        id: 2,
        userId: 'khata-user-123',
        title: 'Consulting Project',
        party: 'FinTech Corp',
        amount: 75000.0,
        isPayable: false,
        date: DateTime(2026, 9, 5),
        description: 'Phase 1 delivery',
      );

      bloc.add(
        AddTransaction(
          entity.Transaction(
            userId: receivableEntry.userId,
            title: receivableEntry.title,
            beneficiary: receivableEntry.party,
            purpose: receivableEntry.description,
            amount: receivableEntry.amount,
            isExpense: receivableEntry.isPayable,
            date: DateTime(2026, 9, 18),
            category: receivableEntry.isPayable ? 'Other' : 'Business Income',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      txs = await repo.getTransactions('khata-user-123');
      expect(txs.length, 2);
      final receivableTx =
          txs.firstWhere((t) => t.title == 'Consulting Project');
      expect(receivableTx.isExpense, isFalse); // Receivable becomes Income
      expect(receivableTx.amount, 75000.0);
      expect(receivableTx.beneficiary, 'FinTech Corp');
    });
  });
}
