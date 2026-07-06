import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum ExpenseSyncState { pending, approved, rejected }

class TaxExpense {
  const TaxExpense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.notes,
    this.receiptPath,
    this.syncState = ExpenseSyncState.pending,
    this.remoteId,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String title;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? notes;
  final String? receiptPath;
  final ExpenseSyncState syncState;
  final String? remoteId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaxExpense copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    DateTime? expenseDate,
    String? notes,
    String? receiptPath,
    ExpenseSyncState? syncState,
    String? remoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaxExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
      syncState: syncState ?? this.syncState,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      TaxDbFields.id: id,
      TaxDbFields.title: title,
      TaxDbFields.amount: amount,
      TaxDbFields.category: category,
      TaxDbFields.expenseDate: expenseDate.toIso8601String(),
      TaxDbFields.notes: notes,
      TaxDbFields.receiptPath: receiptPath,
      TaxDbFields.syncState: syncState.name,
      TaxDbFields.remoteId: remoteId,
      TaxDbFields.createdAt: createdAt?.toIso8601String(),
      TaxDbFields.updatedAt: updatedAt?.toIso8601String(),
    };
  }

  factory TaxExpense.fromMap(Map<String, Object?> map) {
    return TaxExpense(
      id: map[TaxDbFields.id] as int?,
      title: map[TaxDbFields.title]?.toString() ?? '',
      amount: _readDouble(map[TaxDbFields.amount]),
      category: map[TaxDbFields.category]?.toString() ?? '',
      expenseDate:
          DateTime.tryParse(map[TaxDbFields.expenseDate]?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notes: map[TaxDbFields.notes]?.toString(),
      receiptPath: map[TaxDbFields.receiptPath]?.toString(),
      syncState: ExpenseSyncState.values.firstWhere(
        (state) => state.name == map[TaxDbFields.syncState]?.toString(),
        orElse: () => ExpenseSyncState.pending,
      ),
      remoteId: map[TaxDbFields.remoteId]?.toString(),
      createdAt: DateTime.tryParse(
        map[TaxDbFields.createdAt]?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        map[TaxDbFields.updatedAt]?.toString() ?? '',
      ),
    );
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class TaxDbFields {
  const TaxDbFields._();

  static const id = 'id';
  static const title = 'title';
  static const amount = 'amount';
  static const category = 'category';
  static const expenseDate = 'expense_date';
  static const notes = 'notes';
  static const receiptPath = 'receipt_path';
  static const syncState = 'sync_state';
  static const remoteId = 'remote_id';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
}

class TaxDb {
  TaxDb._();

  static final TaxDb instance = TaxDb._();

  static const databaseName = 'fbr_tax_helper.db';
  static const databaseVersion = 1;
  static const expensesTable = 'expenses';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<TaxExpense> insertExpense(TaxExpense expense) async {
    final db = await database;
    final now = DateTime.now();
    final payload =
        expense
            .copyWith(
              syncState: expense.syncState,
              createdAt: expense.createdAt ?? now,
              updatedAt: now,
            )
            .toMap()
          ..remove(TaxDbFields.id);

    final id = await db.insert(
      expensesTable,
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return expense.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  Future<TaxExpense?> getExpense(int id) async {
    final db = await database;
    final rows = await db.query(
      expensesTable,
      where: '${TaxDbFields.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaxExpense.fromMap(rows.single);
  }

  Future<List<TaxExpense>> listExpenses({
    ExpenseSyncState? syncState,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final rows = await db.query(
      expensesTable,
      where: syncState == null ? null : '${TaxDbFields.syncState} = ?',
      whereArgs: syncState == null ? null : [syncState.name],
      orderBy: '${TaxDbFields.expenseDate} DESC, ${TaxDbFields.id} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(TaxExpense.fromMap).toList(growable: false);
  }

  Future<List<TaxExpense>> listPendingExpenses() {
    return listExpenses(syncState: ExpenseSyncState.pending);
  }

  Future<int> updateExpense(TaxExpense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError('Expense id is required for update.');
    }

    final db = await database;
    final payload =
        expense
            .copyWith(
              syncState: ExpenseSyncState.pending,
              updatedAt: DateTime.now(),
            )
            .toMap()
          ..remove(TaxDbFields.id);

    return db.update(
      expensesTable,
      payload,
      where: '${TaxDbFields.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> markExpenseApproved(int id, {String? remoteId}) {
    return _setExpenseState(id, ExpenseSyncState.approved, remoteId: remoteId);
  }

  Future<int> markExpensePending(int id) {
    return _setExpenseState(id, ExpenseSyncState.pending);
  }

  Future<int> markExpenseRejected(int id) {
    return _setExpenseState(id, ExpenseSyncState.rejected);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete(
      expensesTable,
      where: '${TaxDbFields.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> countExpenses({ExpenseSyncState? syncState}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM $expensesTable
      ${syncState == null ? '' : 'WHERE ${TaxDbFields.syncState} = ?'}
      ''', syncState == null ? null : [syncState.name]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}${Platform.pathSeparator}$databaseName';

    return openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $expensesTable (
            ${TaxDbFields.id} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${TaxDbFields.title} TEXT NOT NULL,
            ${TaxDbFields.amount} REAL NOT NULL,
            ${TaxDbFields.category} TEXT NOT NULL,
            ${TaxDbFields.expenseDate} TEXT NOT NULL,
            ${TaxDbFields.notes} TEXT,
            ${TaxDbFields.receiptPath} TEXT,
            ${TaxDbFields.syncState} TEXT NOT NULL DEFAULT 'pending',
            ${TaxDbFields.remoteId} TEXT,
            ${TaxDbFields.createdAt} TEXT NOT NULL,
            ${TaxDbFields.updatedAt} TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_expenses_sync_state ON $expensesTable (${TaxDbFields.syncState})',
        );
        await db.execute(
          'CREATE INDEX idx_expenses_expense_date ON $expensesTable (${TaxDbFields.expenseDate})',
        );
      },
    );
  }

  Future<int> _setExpenseState(
    int id,
    ExpenseSyncState state, {
    String? remoteId,
  }) async {
    final db = await database;
    return db.update(
      expensesTable,
      {
        TaxDbFields.syncState: state.name,
        TaxDbFields.remoteId: remoteId,
        TaxDbFields.updatedAt: DateTime.now().toIso8601String(),
      },
      where: '${TaxDbFields.id} = ?',
      whereArgs: [id],
    );
  }
}
