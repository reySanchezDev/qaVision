import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/storage/storage_service.dart';

void main() {
  test('migra config legacy JSON a SQLite al inicializar', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'qavision_sqlite_migration_',
    );

    try {
      final legacyPath = '${tempDir.path}${Platform.pathSeparator}config.json';
      final legacyFile = File(legacyPath);
      await legacyFile.writeAsString(
        jsonEncode(<String, dynamic>{
          'settings': <String, dynamic>{
            'rootFolder': 'C:/tmp/qa',
            'postCaptureAction': 'saveSilent',
          },
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'p1',
              'name': 'General',
              'alias': 'GEN',
              'color': 0xFF1E88E5,
              'isDefault': true,
            },
          ],
        }),
      );

      final storage = StorageService(filePath: legacyPath);
      await storage.init();

      expect(storage.getMap('settings'), isNotNull);
      expect(storage.getMapList('projects'), isNotEmpty);

      final dbFile = File('$legacyPath.db');
      expect(dbFile.existsSync(), isTrue);

      await storage.dispose();
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
