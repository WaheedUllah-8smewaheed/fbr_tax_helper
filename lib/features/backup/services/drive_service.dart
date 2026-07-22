import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/core/platform/app_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;

class DriveService {
  DriveService({required this.ownerId, required this.ownerEmail});

  final String ownerId;
  final String? ownerEmail;

  static const _genericBackupName = 'filerflow_full_backup.zip';
  static const _legacyBackupName = 'fbr_tax_vault.db';
  static const _databaseEntry = 'database/fbr_tax_vault.db';
  static const _manifestEntry = 'manifest.json';
  static const _receiptPrefix = 'receipts/';

  static String backupNameForUser(String userId) {
    final safeId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safeId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID cannot be empty.');
    }
    return 'filerflow_backup_$safeId.zip';
  }

  String get _accountBackupName => backupNameForUser(ownerId);

  String get _accountLabel {
    final email = ownerEmail?.trim();
    return email == null || email.isEmpty ? 'this account' : email;
  }

  Map<String, String> get _ownerProperties {
    final properties = <String, String>{'filerflowOwnerId': ownerId};
    final email = ownerEmail;
    if (email != null) properties['filerflowOwnerEmail'] = email;
    return properties;
  }

  Future<DriveSyncResult> syncDatabaseToCloud() async {
    final client = AuthService.authenticatedDriveClient;
    if (client == null) {
      return _failure('Connect Google Drive before backing up.');
    }

    File? archiveFile;
    try {
      archiveFile = await _createBackupArchive();
      final driveApi = drive.DriveApi(client);
      final backups = await _findFiles(driveApi, _accountBackupName);
      final media = drive.Media(
        archiveFile.openRead(),
        await archiveFile.length(),
      );

      if (backups.isEmpty) {
        final metadata = drive.File()
          ..name = _accountBackupName
          ..mimeType = 'application/zip'
          ..appProperties = _ownerProperties
          ..parents = const ['appDataFolder'];
        await driveApi.files.create(metadata, uploadMedia: media);
      } else {
        final stableId = backups.first.id;
        if (stableId == null) {
          throw StateError('The existing Drive backup has no file id.');
        }
        await driveApi.files.update(
          drive.File()
            ..mimeType = 'application/zip'
            ..appProperties = _ownerProperties,
          stableId,
          uploadMedia: media,
        );
        await _deleteDuplicates(driveApi, backups.skip(1));
      }

      return DriveSyncResult.success(
        'Database and receipt images for $_accountLabel were backed up to Google Drive.',
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
      var backups = await _findFiles(driveApi, _accountBackupName);
      var backupName = _accountBackupName;
      if (backups.isEmpty) {
        backups = await _findFiles(driveApi, _genericBackupName);
        backupName = _genericBackupName;
      }

      final legacyFiles = backups.isEmpty
          ? await _findFiles(driveApi, _legacyBackupName)
          : const <drive.File>[];
      if (backups.isEmpty && legacyFiles.isEmpty) {
        return DriveSyncResult.failure(
          'No backup for $_accountLabel was found in the selected Google Drive account. Select the same Google account that was used on the previous device.',
        );
      }

      final selectedFile = backups.isNotEmpty
          ? backups.first
          : legacyFiles.first;
      final backupId = selectedFile.id;
      if (backupId == null) {
        throw StateError('The Drive backup has no file id.');
      }

      final temporary = await AppStorage.getTemporaryDirectory();
      if (temporary == null) {
        throw UnsupportedError(
          'Temporary directory storage is unavailable on web.',
        );
      }
      stagingDirectory = await Directory(
        path.join(
          temporary.path,
          'filerflow_restore_${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final isLegacyDatabase = backups.isEmpty;
      final downloaded = File(
        path.join(
          stagingDirectory.path,
          isLegacyDatabase ? _legacyBackupName : backupName,
        ),
      );
      await _downloadFile(driveApi, backupId, downloaded);

      final extracted = isLegacyDatabase
          ? await _stageLegacyDatabase(downloaded, stagingDirectory)
          : await _extractAndValidate(downloaded, stagingDirectory);
      await TaxDatabase.instance.restoreFromBackup(
        stagedDatabase: extracted.database,
        stagedReceipts: extracted.receipts,
        expectedUserId: ownerId,
      );
      return DriveSyncResult.success(
        isLegacyDatabase
            ? 'Transactions for $_accountLabel were restored from the legacy backup. Older receipt images were not part of that backup format.'
            : 'Database and receipt images for $_accountLabel were restored successfully.',
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
    final temporary = await AppStorage.getTemporaryDirectory();
    if (temporary == null) {
      throw UnsupportedError(
        'Temporary directory storage is unavailable on web.',
      );
    }
    final database = await TaxDatabase.instance.createBackupSnapshot(
      userId: ownerId,
      destinationPath: path.join(
        temporary.path,
        'filerflow_snapshot_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    final archive = Archive();
    final databaseBytes = await database.readAsBytes();
    archive.addFile(
      ArchiveFile(_databaseEntry, databaseBytes.length, databaseBytes),
    );

    var receiptCount = 0;
    final receiptPaths = await TaxDatabase.instance.getReceiptPathsForUser(
      ownerId,
    );
    for (final receiptPath in receiptPaths) {
      final entry = File(receiptPath);
      if (await entry.exists()) {
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
        'formatVersion': 2,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'ownerId': ownerId,
        'ownerEmail': ownerEmail,
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
    final output = File(
      path.join(
        temporary.path,
        'filerflow_backup_${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    await output.writeAsBytes(encoded, flush: true);
    if (await database.exists()) await database.delete();
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
    if (manifest is! Map<String, dynamic>) {
      throw const FormatException('Invalid Filer Flow backup manifest.');
    }
    final formatVersion = manifest['formatVersion'];
    if (formatVersion != 1 && formatVersion != 2) {
      throw const FormatException('Unsupported Filer Flow backup format.');
    }
    if (formatVersion == 2 && manifest['ownerId'] != ownerId) {
      final backupEmail = manifest['ownerEmail'] as String?;
      throw FormatException(
        'This backup belongs to ${backupEmail ?? 'a different Filer Flow account'}, not $_accountLabel.',
      );
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

  Future<_ExtractedBackup> _stageLegacyDatabase(
    File downloaded,
    Directory stagingRoot,
  ) async {
    final database = File(path.join(stagingRoot.path, 'legacy_restored.db'));
    await downloaded.copy(database.path);
    final receipts = await Directory(
      path.join(stagingRoot.path, 'receipts'),
    ).create(recursive: true);
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
    await response.stream.pipe(destination.openWrite());
    if (!await destination.exists() || await destination.length() == 0) {
      throw const FormatException('The downloaded Drive backup is empty.');
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
