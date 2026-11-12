import 'dart:io';

/// Applies owner-only permissions to Omoji's private data on Unix platforms.
class PrivateFilePermissions {
  static Future<void> secureDirectory(Directory directory) async {
    await directory.create(recursive: true);
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['700', directory.path]);
    }
  }

  static Future<void> secureFile(File file) async {
    if ((Platform.isLinux || Platform.isMacOS) && await file.exists()) {
      await Process.run('chmod', ['600', file.path]);
    }
  }
}
