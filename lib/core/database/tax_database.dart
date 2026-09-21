import 'dart:io';
import 'package:fbr_tax_helper/core/platform/app_storage.dart';
import 'package:sqflite/sqflite.dart';
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
    final path = await AppStorage.resolveDatabasePath(filePath);

    return await openDatabase(
      path,
      version: 6,
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
          receiptImagePath TEXT,
          khataEntryId INTEGER,
          assetId INTEGER,
          linkedCounterpartyOrAsset TEXT)
    ''');
    await db.execute('''
      CREATE TABLE khata_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          title TEXT NOT NULL,
          party TEXT NOT NULL,
          amount REAL NOT NULL,
          isPayable INTEGER NOT NULL,
          date TEXT NOT NULL,
          dueDate TEXT,
          description TEXT NOT NULL DEFAULT '',
          isPaid INTEGER NOT NULL DEFAULT 0,
          settledAmount REAL NOT NULL DEFAULT 0.0,
          isWrittenOff INTEGER NOT NULL DEFAULT 0)
    ''');
    await db.execute('''
      CREATE TABLE assets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          value REAL NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL)
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
    if (oldVersion < 4) {
      await db.update(
        'transactions',
        {'isExpense': 1},
        where: 'category = ?',
        whereArgs: ['Tax'],
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS khata_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            party TEXT NOT NULL,
            amount REAL NOT NULL,
            isPayable INTEGER NOT NULL,
            date TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            isPaid INTEGER NOT NULL DEFAULT 0)
      ''');
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'khataEntryId',
        definition: 'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'assetId',
        definition: 'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'linkedCounterpartyOrAsset',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        db,
        table: 'khata_entries',
        column: 'dueDate',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        db,
        table: 'khata_entries',
        column: 'settledAmount',
        definition: 'REAL NOT NULL DEFAULT 0.0',
      );
      await _addColumnIfMissing(
        db,
        table: 'khata_entries',
        column: 'isWrittenOff',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS assets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            value REAL NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL)
      ''');
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

  Future<int> insertKhataEntry(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('khata_entries', row);
  }

  Future<List<Map<String, dynamic>>> fetchKhataEntries({String? userId}) async {
    final db = await instance.database;
    if (userId != null && userId.isNotEmpty) {
      return await db.query(
        'khata_entries',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );
    }
    return await db.query('khata_entries', orderBy: 'date DESC');
  }

  Future<int> updateKhataEntry(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'] as int?;
    if (id == null) return 0;
    return await db.update(
      'khata_entries',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteKhataEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'khata_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Gets the exact path of the database file on disk to pass to Google Drive API
  Future<File> getDatabaseFile() async {
    final documents = await AppStorage.getDocumentsDirectory();
    if (documents == null) {
      throw UnsupportedError('Local database storage is unavailable on web.');
    }
    return File(join(documents.path, 'fbr_tax_vault.db'));
  }

  Future<Directory> getReceiptDirectory() async {
    final documents = await AppStorage.getDocumentsDirectory();
    if (documents == null) {
      throw UnsupportedError('Receipt storage is unavailable on web.');
    }
    return Directory(join(documents.path, 'transaction_receipts'));
  }

  Future<void> prepareForBackup() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<File> createBackupSnapshot({
    required String userId,
    required String destinationPath,
  }) async {
    await prepareForBackup();
    final source = await getDatabaseFile();
    if (!await source.exists()) {
      throw StateError('Local database file was not found.');
    }
    final snapshot = await source.copy(destinationPath);
    final snapshotDatabase = await openDatabase(
      snapshot.path,
      singleInstance: false,
    );
    try {
      await snapshotDatabase.delete(
        'transactions',
        where: 'userId != ?',
        whereArgs: [userId],
      );
    } finally {
      await snapshotDatabase.close();
    }
    return snapshot;
  }

  Future<List<String>> getReceiptPathsForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      distinct: true,
      columns: ['receiptImagePath'],
      where:
          'userId = ? AND receiptImagePath IS NOT NULL AND receiptImagePath != ?',
      whereArgs: [userId, ''],
    );
    return rows
        .map((row) => row['receiptImagePath'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<int> insertAsset(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('assets', row);
  }

  Future<List<Map<String, dynamic>>> fetchAssets({String? userId}) async {
    final db = await instance.database;
    if (userId != null && userId.isNotEmpty) {
      return await db.query(
        'assets',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'updatedAt DESC',
      );
    }
    return await db.query('assets', orderBy: 'updatedAt DESC');
  }

  Future<int> updateAsset(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'] as int?;
    if (id == null) return 0;
    return await db.update(
      'assets',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAsset(int id) async {
    final db = await instance.database;
    return await db.delete(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> handleTransactionDeletionReversal(
    Map<String, dynamic> transactionRow,
  ) async {
    final db = await instance.database;
    final khataEntryId = transactionRow['khataEntryId'] as int?;
    final assetId = transactionRow['assetId'] as int?;
    final amount = (transactionRow['amount'] as num?)?.toDouble() ?? 0.0;
    final category = transactionRow['category'] as String? ?? '';

    if (khataEntryId != null) {
      final rows = await db.query(
        'khata_entries',
        where: 'id = ?',
        whereArgs: [khataEntryId],
      );
      if (rows.isNotEmpty) {
        final khata = rows.first;
        final totalAmount = (khata['amount'] as num?)?.toDouble() ?? 0.0;
        final currentSettled =
            (khata['settledAmount'] as num?)?.toDouble() ?? 0.0;
        final newSettled = (currentSettled - amount).clamp(0.0, totalAmount);
        final isPaid = newSettled >= totalAmount ? 1 : 0;
        await db.update(
          'khata_entries',
          {'settledAmount': newSettled, 'isPaid': isPaid},
          where: 'id = ?',
          whereArgs: [khataEntryId],
        );
      }
    }

    if (assetId != null) {
      final rows = await db.query(
        'assets',
        where: 'id = ?',
        whereArgs: [assetId],
      );
      if (rows.isNotEmpty) {
        final asset = rows.first;
        final currentValue = (asset['value'] as num?)?.toDouble() ?? 0.0;
        final double newValue;
        if (category == 'Asset Purchase') {
          newValue = (currentValue - amount).clamp(0.0, double.infinity);
        } else if (category == 'Asset Sale') {
          newValue = currentValue + amount;
        } else {
          final isExpense = (transactionRow['isExpense'] as int? ?? 1) == 1;
          newValue = isExpense
              ? (currentValue - amount).clamp(0.0, double.infinity)
              : currentValue + amount;
        }
        await db.update(
          'assets',
          {
            'value': newValue,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [assetId],
        );
      }
    }
  }

  Future<void> handleTransactionUpdateReversal({
    required Map<String, dynamic> oldTransactionRow,
    required Map<String, dynamic> newTransactionRow,
  }) async {
    final db = await instance.database;
    final khataEntryId = newTransactionRow['khataEntryId'] as int? ??
        oldTransactionRow['khataEntryId'] as int?;
    final assetId = newTransactionRow['assetId'] as int? ??
        oldTransactionRow['assetId'] as int?;
    final oldAmount = (oldTransactionRow['amount'] as num?)?.toDouble() ?? 0.0;
    final newAmount = (newTransactionRow['amount'] as num?)?.toDouble() ?? 0.0;
    final amountDiff = newAmount - oldAmount;
    final category = newTransactionRow['category'] as String? ??
        oldTransactionRow['category'] as String? ??
        '';

    if (khataEntryId != null && amountDiff != 0.0) {
      final rows = await db.query(
        'khata_entries',
        where: 'id = ?',
        whereArgs: [khataEntryId],
      );
      if (rows.isNotEmpty) {
        final khata = rows.first;
        final totalAmount = (khata['amount'] as num?)?.toDouble() ?? 0.0;
        final currentSettled =
            (khata['settledAmount'] as num?)?.toDouble() ?? 0.0;
        final newSettled =
            (currentSettled + amountDiff).clamp(0.0, totalAmount);
        final isPaid = newSettled >= totalAmount ? 1 : 0;
        await db.update(
          'khata_entries',
          {'settledAmount': newSettled, 'isPaid': isPaid},
          where: 'id = ?',
          whereArgs: [khataEntryId],
        );
      }
    }

    if (assetId != null && amountDiff != 0.0) {
      final rows = await db.query(
        'assets',
        where: 'id = ?',
        whereArgs: [assetId],
      );
      if (rows.isNotEmpty) {
        final asset = rows.first;
        final currentValue = (asset['value'] as num?)?.toDouble() ?? 0.0;
        final double newValue;
        if (category == 'Asset Purchase') {
          newValue = (currentValue + amountDiff).clamp(0.0, double.infinity);
        } else if (category == 'Asset Sale') {
          newValue = (currentValue - amountDiff).clamp(0.0, double.infinity);
        } else {
          final isExpense = (newTransactionRow['isExpense'] as int? ?? 1) == 1;
          newValue = isExpense
              ? (currentValue + amountDiff).clamp(0.0, double.infinity)
              : (currentValue - amountDiff).clamp(0.0, double.infinity);
        }
        await db.update(
          'assets',
          {
            'value': newValue,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [assetId],
        );
      }
    }
  }

  Future<void> deleteDataForUser(String userId) async {
    final receiptPaths = await getReceiptPathsForUser(userId);
    final db = await database;
    await db.delete('transactions', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('khata_entries', where: 'userId = ?', whereArgs: [userId]);
    await db.delete('assets', where: 'userId = ?', whereArgs: [userId]);

    for (final receiptPath in receiptPaths) {
      final receipt = File(receiptPath);
      if (await receipt.exists()) {
        await receipt.delete();
      }
    }
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }

  Future<void> restoreFromBackup({
    required File stagedDatabase,
    required Directory stagedReceipts,
    required String expectedUserId,
  }) async {
    await _validateBackupDatabase(stagedDatabase.path, expectedUserId);

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
      await _normalizeRestoredOwnership(expectedUserId);
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

  Future<void> _validateBackupDatabase(
    String databasePath,
    String expectedUserId,
  ) async {
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
      final columns = await candidate.rawQuery(
        'PRAGMA table_info(transactions)',
      );
      final hasUserId = columns.any((row) => row['name'] == 'userId');
      if (hasUserId) {
        final owners = await candidate.rawQuery(
          "SELECT DISTINCT userId FROM transactions WHERE userId IS NOT NULL AND userId != ''",
        );
        final ownerIds = owners
            .map((row) => row['userId'] as String?)
            .whereType<String>()
            .toSet();
        if (ownerIds.isNotEmpty && !ownerIds.contains(expectedUserId)) {
          throw const FormatException(
            'The backup belongs to a different Filer Flow account.',
          );
        }
      }
    } finally {
      await candidate.close();
    }
  }

  Future<void> _normalizeRestoredOwnership(String expectedUserId) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.update('transactions', {
        'userId': expectedUserId,
      }, where: "userId IS NULL OR userId = ''");
      await transaction.delete(
        'transactions',
        where: 'userId != ?',
        whereArgs: [expectedUserId],
      );
    });
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
