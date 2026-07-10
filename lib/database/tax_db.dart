import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class TaxDatabase {
  static final TaxDatabase instance = TaxDatabase._init();
  static Database? _database;

  TaxDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fbr_tax_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Stores the database file within the app's private app directory on the system
    Directory docDirectory = await getApplicationDocumentsDirectory();
    String path = join(docDirectory.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          title TEXT NOT NULL,
          beneficiary TEXT NOT NULL,
          purpose TEXT NOT NULL,
          amount REAL NOT NULL,
          isExpense INTEGER NOT NULL,
          date TEXT NOT NULL,
          category TEXT NOT NULL)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'userId',
        definition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'beneficiary',
        definition: "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'purpose',
        definition: "TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<List<Map<String, dynamic>>> fetchAllTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<int> updateTransactionStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Gets the exact path of the database file on disk to pass to Google Drive API
  Future<File> getDatabaseFile() async {
    Directory docDirectory = await getApplicationDocumentsDirectory();
    return File(join(docDirectory.path, 'fbr_tax_vault.db'));
  }
}
