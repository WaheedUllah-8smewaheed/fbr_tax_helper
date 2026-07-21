import 'package:fbr_tax_helper/services/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a stable account-specific backup filename', () {
    expect(
      DriveService.backupNameForUser('firebase-user-123'),
      'filerflow_backup_firebase-user-123.zip',
    );
    expect(
      DriveService.backupNameForUser('firebase/user@example.com'),
      'filerflow_backup_firebase_user_example_com.zip',
    );
  });

  test('rejects an empty backup owner id', () {
    expect(() => DriveService.backupNameForUser(''), throwsArgumentError);
  });
}
