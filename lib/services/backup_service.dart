import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../database/local_database.dart';

class BackupService {
  const BackupService(this._database);

  final LocalDatabase _database;

  String exportJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_database.exportBackup());
  }

  Future<File> saveBackupToDevice() async {
    final json = exportJson();
    final timestamp = _timestamp();
    final directory = await _backupDirectory();
    final file = File('${directory.path}/smart_shop_$timestamp.json');
    await file.writeAsString(json);
    return file;
  }

  Future<String> saveBackupLocally() async {
    final json = exportJson();
    final fileName = 'smart_shop_${_timestamp()}.json';
    if (kIsWeb) {
      final blob = html.Blob([json], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = fileName
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded $fileName';
    }
    final file = await saveBackupToDevice();
    return file.path;
  }

  Future<String> shareBackup() async {
    if (kIsWeb) {
      final json = exportJson();
      await SharePlus.instance.share(
        ShareParams(
          title: 'Smart Shop backup',
          subject: 'Smart Shop backup',
          text: json,
        ),
      );
      return 'Shared backup text';
    }
    final file = await saveBackupToDevice();
    await SharePlus.instance.share(
      ShareParams(
        title: 'Smart Shop backup',
        subject: 'Smart Shop backup',
        text: 'Smart Shop full history backup',
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [file.uri.pathSegments.last],
      ),
    );
    return file.path;
  }

  Future<void> importJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup must be a JSON object');
    }
    await _database.importBackup(decoded);
  }

  Future<Directory> _backupDirectory() async {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final directory = Directory('$home/SmartShopBackups');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _timestamp() {
    return DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
  }
}
