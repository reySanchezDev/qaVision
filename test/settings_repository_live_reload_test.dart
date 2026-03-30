import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/settings/data/repositories/settings_repository.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';

void main() {
  test(
    'SettingsRepository recarga desde disco y aplica postCaptureAction externo',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'qavision_settings_reload_',
      );
      final configPath = '${tempDir.path}${Platform.pathSeparator}config.json';
      final storage = StorageService(filePath: configPath);
      final externalStorage = StorageService(filePath: configPath);
      final repository = SettingsRepository(storageService: storage);

      addTearDown(() async {
        await externalStorage.dispose();
        await storage.dispose();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await storage.init();
      await externalStorage.init();
      await repository.saveSettings(
        const SettingsEntity(
          rootFolder: 'C:/tmp/qavision',
          postCaptureAction: PostCaptureAction.saveSilent,
        ),
      );

      await externalStorage.setMap('settings', <String, dynamic>{
        'rootFolder': 'C:/tmp/qavision',
        'postCaptureAction': 'saveAndShowThumbnail',
      });

      final loaded = await repository.loadSettings();
      expect(
        loaded.postCaptureAction,
        PostCaptureAction.saveAndShowThumbnail,
      );
    },
  );
}
