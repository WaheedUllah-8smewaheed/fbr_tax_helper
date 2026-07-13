import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbr_tax_helper/database/tax_db.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DriveService {
  static const _backupName = 'filerflow_full_backup.zip';
  static const _legacyBackupName = 'fbr_tax_vault.db';
  static const _databaseEntry = 'database/fbr_tax_vault.db';
  static const _manifestEntry = 'manifest.json';
  static const _receiptPrefix = 'receipts/';

  Future<DriveSyncResult> syncDatabaseToCloud() async {
    final client = AuthService.authenticatedDriveClient;
    if (client == null) {
      return _failure('Connect Google Drive before backing up.');
    }

    File? archiveFile;
    try {
      archiveFile = await _createBackupArchive();
      final driveApi = drive.DriveApi(client);
      final backups = await _findFiles(driveApi, _backupName);
      final media = drive.Media(
        archiveFile.openRead(),
        await archiveFile.length(),
      );

      if (backups.isEmpty) {
        final metadata = drive.File()
          ..name = _backupName
          ..mimeType = 'application/zip'
          ..parents = const ['appDataFolder'];
        await driveApi.files.create(metadata, uploadMedia: media);
      } else {
        final stableId = backups.first.id;
        if (stableId == null) {
          throw StateError('The existing Drive backup has no file id.');
        }
        await driveApi.files.update(
          drive.File()..mimeType = 'application/zip',
          stableId,
          uploadMedia: media,
        );
        await _deleteDuplicates(driveApi, backups.skip(1));
      }

      // The ZIP supersedes the older database-only backup.
      await _deleteDuplicates(
        driveApi,
        await _findFiles(driveApi, _legacyBackupName),
      );
      return const DriveSyncResult.success(
        'Database and receipt images backed up to Google Drive.',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Google Drive backup failed',
        name: 'DriveService',
        error: error,
        stackTrace: stackTrace,
      );
      return _failure('Google Drive backup failed: $error');
    } finally {
      if (archiveFile != null && await archiveFile.exists()) {
        await archiveFile.delete();
      }
    }
  }

  Future<DriveSyncResult> restoreBackupFromCloud() async {
    final client = AuthService.authenticatedDriveClient;
    if (client == null) {
      return _failure('Connect Google Drive before restoring.');
    }

    Directory? stagingDirectory;
    try {
      final driveApi = drive.DriveApi(client);
      final backups = await _findFiles(driveApi, _backupName);
      if (backups.isEmpty) {
        return const DriveSyncResult.failure(
          'No full FilerFlow backup was found in this Google account.',
        );
      }
      final backupId = backups.first.id;
      if (backupId == null) {
        throw StateError('The Drive backup has no file id.');
      }

      final temporary = await getTemporaryDirectory();
      stagingDirectory = await Directory(
        path.join(
          temporary.path,
          'filerflow_restore_${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final downloaded = File(path.join(stagingDirectory.path, _backupName));
      await _downloadFile(driveApi, backupId, downloaded);

      final extracted = await _extractAndValidate(downloaded, stagingDirectory);
      await TaxDatabase.instance.restoreFromBackup(
        stagedDatabase: extracted.database,
        stagedReceipts: extracted.receipts,
      );
      return const DriveSyncResult.success(
        'Database and receipt images restored successfully.',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Google Drive restore failed',
        name: 'DriveService',
        error: error,
        stackTrace: stackTrace,
      );
      return _failure('Google Drive restore failed: $error');
    } finally {
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<File> _createBackupArchive() async {
    await TaxDatabase.instance.prepareForBackup();
    final database = await TaxDatabase.instance.getDatabaseFile();
    if (!await database.exists()) {
      throw StateError('Local database file was not found.');
    }

    final receipts = await TaxDatabase.instance.getReceiptDirectory();
    final archive = Archive();
    final databaseBytes = await database.readAsBytes();
    archive.addFile(
      ArchiveFile(_databaseEntry, databaseBytes.length, databaseBytes),
    );

    var receiptCount = 0;
    if (await receipts.exists()) {
      await for (final entry in receipts.list(followLinks: false)) {
        if (entry is! File) continue;
        final bytes = await entry.readAsBytes();
        archive.addFile(
          ArchiveFile(
            '$_receiptPrefix${path.basename(entry.path)}',
            bytes.length,
            bytes,
          ),
        );
        receiptCount++;
      }
    }

    final manifestBytes = utf8.encode(
      jsonEncode({
        'formatVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'database': _databaseEntry,
        'receiptCount': receiptCount,
      }),
    );
    archive.addFile(
      ArchiveFile(_manifestEntry, manifestBytes.length, manifestBytes),
    );

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Could not create the backup archive.');
    }
    final temporary = await getTemporaryDirectory();
    final output = File(
      path.join(
        temporary.path,
        'filerflow_backup_${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  Future<_ExtractedBackup> _extractAndValidate(
    File downloaded,
    Directory stagingRoot,
  ) async {
    final archive = ZipDecoder().decodeBytes(
      await downloaded.readAsBytes(),
      verify: true,
    );
    final manifestFile = archive.findFile(_manifestEntry);
    final databaseFile = archive.findFile(_databaseEntry);
    if (manifestFile == null || databaseFile == null) {
      throw const FormatException('The Drive backup is incomplete.');
    }

    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest is! Map<String, dynamic> || manifest['formatVersion'] != 1) {
      throw const FormatException('Unsupported FilerFlow backup format.');
    }

    final database = File(path.join(stagingRoot.path, 'restored.db'));
    await database.writeAsBytes(databaseFile.content as List<int>, flush: true);
    final receipts = await Directory(
      path.join(stagingRoot.path, 'receipts'),
    ).create(recursive: true);
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith(_receiptPrefix)) continue;
      final safeName = path.basename(entry.name);
      if (safeName.isEmpty) continue;
      await File(
        path.join(receipts.path, safeName),
      ).writeAsBytes(entry.content as List<int>, flush: true);
    }
    return _ExtractedBackup(database: database, receipts: receipts);
  }

  Future<List<drive.File>> _findFiles(
    drive.DriveApi driveApi,
    String fileName,
  ) async {
    final result = await driveApi.files.list(
      q: "name = '$fileName' and trashed = false",
      spaces: 'appDataFolder',
      orderBy: 'createdTime',
      pageSize: 100,
      $fields: 'files(id,name,createdTime,modifiedTime,size)',
    );
    return result.files ?? const <drive.File>[];
  }

  Future<void> _deleteDuplicates(
    drive.DriveApi driveApi,
    Iterable<drive.File> files,
  ) async {
    for (final file in files) {
      final id = file.id;
      if (id != null) await driveApi.files.delete(id);
    }
  }

  Future<void> _downloadFile(
    drive.DriveApi driveApi,
    String fileId,
    File destination,
  ) async {
    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (response is! drive.Media) {
      throw const FormatException('Drive did not return backup content.');
    }
    final sink = destination.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  DriveSyncResult _failure(String message) {
    developer.log(message, name: 'DriveService');
    return DriveSyncResult.failure(message);
  }
}

class DriveSyncResult {
  const DriveSyncResult._({required this.success, required this.message});

  const DriveSyncResult.success(String message)
    : this._(success: true, message: message);

  const DriveSyncResult.failure(String message)
    : this._(success: false, message: message);

  final bool success;
  final String message;
}

class _ExtractedBackup {
  const _ExtractedBackup({required this.database, required this.receipts});

  final File database;
  final Directory receipts;
}
