import 'package:fbr_tax_helper/database/tax_db.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';

abstract class TransactionLocalDataSource {
  Future<List<Transaction>> getTransactions(String userId);

  Future<void> addTransaction(Transaction transaction);

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction({required int id, required String userId});
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  const TransactionLocalDataSourceImpl({required this.databaseHelper});

  final TaxDatabase databaseHelper;

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final db = await databaseHelper.database;
    await db.insert('transactions', {
      'userId': transaction.userId,
      'title': transaction.title,
      'beneficiary': transaction.beneficiary,
      'purpose': transaction.purpose,
      'amount': transaction.amount,
      'isExpense': transaction.isExpense ? 1 : 0,
      'date': transaction.date.toIso8601String(),
      'category': transaction.category,
      'receiptImagePath': transaction.receiptImagePath,
    });
  }

  @override
  Future<List<Transaction>> getTransactions(String userId) async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      return Transaction(
        id: map['id'] as int?,
        userId: map['userId'] as String? ?? '',
        title: map['title'] as String,
        beneficiary: map['beneficiary'] as String? ?? '',
        purpose: map['purpose'] as String? ?? '',
        amount: (map['amount'] as num).toDouble(),
        isExpense: (map['isExpense'] as int) == 1,
        date: DateTime.parse(map['date'] as String),
        category: map['category'] as String,
        receiptImagePath: map['receiptImagePath'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final id = transaction.id;
    if (id == null) {
      throw ArgumentError('Cannot update a transaction without an id.');
    }

    final db = await databaseHelper.database;
    await db.update(
      'transactions',
      {
        'title': transaction.title,
        'beneficiary': transaction.beneficiary,
        'purpose': transaction.purpose,
        'amount': transaction.amount,
        'isExpense': transaction.isExpense ? 1 : 0,
        'date': transaction.date.toIso8601String(),
        'category': transaction.category,
        'receiptImagePath': transaction.receiptImagePath,
      },
      where: 'id = ? AND userId = ?',
      whereArgs: [id, transaction.userId],
    );
  }

  @override
  Future<void> deleteTransaction({
    required int id,
    required String userId,
  }) async {
    final db = await databaseHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }
}
