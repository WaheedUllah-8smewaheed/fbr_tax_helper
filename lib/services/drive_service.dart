import 'dart:io';
import 'dart:developer' as developer;

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:fbr_tax_helper/database/tax_db.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';

class DriveService {
  Future<void> syncDatabaseToCloud() async {
    // Safely verify if we hold an active authenticated pipeline from our AuthService
    if (AuthService.authenticatedDriveClient == null) {
      developer.log(
        'Sync skipped: no authenticated Google storage client found.',
        name: 'DriveService',
      );
      return;
    }

    var driveApi = drive.DriveApi(AuthService.authenticatedDriveClient!);
    File localFile = await TaxDatabase.instance.getDatabaseFile();

    if (!await localFile.exists()) return;

    try {
      // 1. Scan the hidden appDataFolder to find if an older backup exists
      drive.FileList existingFiles = await driveApi.files.list(
        q: "name = 'fbr_tax_vault.db'",
        spaces: 'appDataFolder',
      );

      var media = drive.Media(localFile.openRead(), localFile.lengthSync());

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        // 2. File exists: Let's update/overwrite it to save space
        String fileId = existingFiles.files!.first.id!;
        drive.File updateMeta = drive.File();

        await driveApi.files.update(updateMeta, fileId, uploadMedia: media);
        developer.log(
          'Backup file updated successfully in Google Drive Vault.',
          name: 'DriveService',
        );
      } else {
        // 3. New File: Create the initial record inside the container
        drive.File newFileMeta = drive.File()
          ..name = "fbr_tax_vault.db"
          ..parents = [
            "appDataFolder",
          ]; // Pins the file strictly inside the invisible zone

        await driveApi.files.create(newFileMeta, uploadMedia: media);
        developer.log(
          'Initial database vault created successfully in Google Drive.',
          name: 'DriveService',
        );
      }
    } catch (e) {
      developer.log(
        'Google Drive synchronization failed.',
        name: 'DriveService',
        error: e,
      );
    }
  }
}
