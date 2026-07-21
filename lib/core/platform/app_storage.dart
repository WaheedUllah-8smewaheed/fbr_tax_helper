import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

class AppStorage {
  static bool get isWeb => kIsWeb;

  static Future<String> resolveDatabasePath(
    String fileName, {
    bool? isWeb,
  }) async {
    final useWeb = isWeb ?? kIsWeb;
    if (useWeb) return fileName;

    final documents = await path_provider.getApplicationDocumentsDirectory();
    return p.join(documents.path, fileName);
  }

  static Future<Directory?> getDocumentsDirectory({bool? isWeb}) async {
    final useWeb = isWeb ?? kIsWeb;
    if (useWeb) return null;
    return path_provider.getApplicationDocumentsDirectory();
  }

  static Future<Directory?> getSupportDirectory({bool? isWeb}) async {
    final useWeb = isWeb ?? kIsWeb;
    if (useWeb) return null;
    return path_provider.getApplicationSupportDirectory();
  }

  static Future<Directory?> getTemporaryDirectory({bool? isWeb}) async {
    final useWeb = isWeb ?? kIsWeb;
    if (useWeb) return null;
    return path_provider.getTemporaryDirectory();
  }
}
