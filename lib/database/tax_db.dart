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
      version: 3,
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
          category TEXT NOT NULL,
          receiptImagePath TEXT)
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
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'receiptImagePath',
        definition: 'TEXT',
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

  Future<Directory> getReceiptDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(join(documents.path, 'transaction_receipts'));
  }

  Future<void> prepareForBackup() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }

  Future<void> restoreFromBackup({
    required File stagedDatabase,
    required Directory stagedReceipts,
  }) async {
    await _validateBackupDatabase(stagedDatabase.path);

    final liveDatabase = await getDatabaseFile();
    final liveReceipts = await getReceiptDirectory();
    final databaseRollback = File('${liveDatabase.path}.restore_previous');
    final receiptsRollback = Directory('${liveReceipts.path}_restore_previous');

    await close();
    await _deleteDatabaseSidecars(liveDatabase.path);
    if (await databaseRollback.exists()) await databaseRollback.delete();
    if (await receiptsRollback.exists()) {
      await receiptsRollback.delete(recursive: true);
    }

    if (await liveDatabase.exists()) {
      await liveDatabase.rename(databaseRollback.path);
    }
    if (await liveReceipts.exists()) {
      await liveReceipts.rename(receiptsRollback.path);
    }

    try {
      await stagedDatabase.copy(liveDatabase.path);
      await _copyDirectory(stagedReceipts, liveReceipts);
      await _rewriteReceiptPaths(liveReceipts);

      if (await databaseRollback.exists()) await databaseRollback.delete();
      if (await receiptsRollback.exists()) {
        await receiptsRollback.delete(recursive: true);
      }
    } catch (_) {
      await close();
      await _deleteDatabaseSidecars(liveDatabase.path);
      if (await liveDatabase.exists()) await liveDatabase.delete();
      if (await liveReceipts.exists()) {
        await liveReceipts.delete(recursive: true);
      }
      if (await databaseRollback.exists()) {
        await databaseRollback.rename(liveDatabase.path);
      }
      if (await receiptsRollback.exists()) {
        await receiptsRollback.rename(liveReceipts.path);
      }
      await database;
      rethrow;
    }
  }

  Future<void> _validateBackupDatabase(String databasePath) async {
    final candidate = await openDatabase(
      databasePath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const FormatException('The backup database is corrupted.');
      }
      final tables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'transactions'",
      );
      if (tables.isEmpty) {
        throw const FormatException(
          'The backup does not contain a transactions table.',
        );
      }
    } finally {
      await candidate.close();
    }
  }

  Future<void> _rewriteReceiptPaths(Directory receiptDirectory) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      columns: ['id', 'receiptImagePath'],
      where: 'receiptImagePath IS NOT NULL AND receiptImagePath != ?',
      whereArgs: [''],
    );
    await db.transaction((transaction) async {
      for (final row in rows) {
        final id = row['id'] as int?;
        final oldPath = row['receiptImagePath'] as String?;
        if (id == null || oldPath == null) continue;
        final restoredPath = join(receiptDirectory.path, basename(oldPath));
        await transaction.update(
          'transactions',
          {
            'receiptImagePath': await File(restoredPath).exists()
                ? restoredPath
                : null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    if (!await source.exists()) return;
    await for (final entity in source.list(followLinks: false)) {
      if (entity is File) {
        await entity.copy(join(target.path, basename(entity.path)));
      }
    }
  }

  Future<void> _deleteDatabaseSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }
}
