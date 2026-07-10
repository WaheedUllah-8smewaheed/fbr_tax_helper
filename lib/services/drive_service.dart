import 'dart:io';
import 'dart:developer' as developer;

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:fbr_tax_helper/database/tax_db.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';

class DriveService {
  Future<DriveSyncResult> syncDatabaseToCloud() async {
    // Safely verify if we hold an active authenticated pipeline from our AuthService
    if (AuthService.authenticatedDriveClient == null) {
      const message = 'Connect Google Drive before syncing.';
      developer.log(message, name: 'DriveService');
      return const DriveSyncResult.failure(message);
    }

    var driveApi = drive.DriveApi(AuthService.authenticatedDriveClient!);
    File localFile = await TaxDatabase.instance.getDatabaseFile();

    if (!await localFile.exists()) {
      const message = 'Local database file was not found.';
      developer.log(message, name: 'DriveService');
      return const DriveSyncResult.failure(message);
    }

    try {
      // 1. Scan the hidden appDataFolder to find if an older backup exists
      drive.FileList existingFiles = await driveApi.files.list(
        q: "name = 'fbr_tax_vault.db' and trashed = false",
        spaces: 'appDataFolder',
      );

      var media = drive.Media(localFile.openRead(), localFile.lengthSync());

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        // 2. File exists: Let's update/overwrite it to save space
        String fileId = existingFiles.files!.first.id!;
        drive.File updateMeta = drive.File();

        await driveApi.files.update(updateMeta, fileId, uploadMedia: media);
        const message = 'Backup file updated in Google Drive.';
        developer.log(message, name: 'DriveService');
        return const DriveSyncResult.success(message);
      } else {
        // 3. New File: Create the initial record inside the container
        drive.File newFileMeta = drive.File()
          ..name = "fbr_tax_vault.db"
          ..parents = [
            "appDataFolder",
          ]; // Pins the file strictly inside the invisible zone

        await driveApi.files.create(newFileMeta, uploadMedia: media);
        const message = 'Initial database vault created in Google Drive.';
        developer.log(message, name: 'DriveService');
        return const DriveSyncResult.success(message);
      }
    } catch (e) {
      final message = 'Google Drive synchronization failed: $e';
      developer.log(message, name: 'DriveService', error: e);
      return DriveSyncResult.failure(message);
    }
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
