import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/storage/storage_service.dart';

void main() {
  group('StorageService concurrent persistence', () {
    test('preserva claves de otros procesos al guardar', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'qavision_storage_',
      );
      try {
        final configPath =
            '${tempDir.path}${Platform.pathSeparator}config.json';
        final serviceA = StorageService(filePath: configPath);
        final serviceB = StorageService(filePath: configPath);

        await serviceA.init();
        await serviceB.init();

        await serviceA.setMapList('projects', <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'name': 'Proyecto A',
            'alias': 'PA',
            'color': 0xFF1E88E5,
            'isDefault': true,
          },
        ]);

        await serviceB.setMap('settings', <String, dynamic>{
          'showFloatingButton': true,
        });

        final verifier = StorageService(filePath: configPath);
        await verifier.init();

        final settings = verifier.getMap('settings');
        final projects = verifier.getMapList('projects');

        expect(settings, isNotNull);
        expect(projects, isNotEmpty);
        expect(projects.first['name'], 'Proyecto A');

        await serviceA.dispose();
        await serviceB.dispose();
        await verifier.dispose();
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
