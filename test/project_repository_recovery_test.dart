import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/projects/data/repositories/project_repository.dart';

String _normalizePathForAssert(String path) {
  var normalized = path.replaceAll(r'\', '/').trim().toLowerCase();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

void main() {
  group('ProjectRepository folders as source of truth', () {
    test('poda proyectos cuando la carpeta fue eliminada', () async {
      final tempDir = await Directory.systemTemp.createTemp('qavision_prune_');
      StorageService? storage;
      try {
        final projectDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}General2',
        );
        await projectDir.create(recursive: true);

        storage = StorageService(
          filePath: '${tempDir.path}${Platform.pathSeparator}config.json',
        );
        await storage.init();
        await storage.setMapList('projects', <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'name': 'General2',
            'folderPath': projectDir.path,
            'alias': 'GEN',
            'color': 0xFF1E88E5,
            'isDefault': true,
            'usageCount': 3,
            'lastUsedAt': 10,
          },
        ]);

        final repo = ProjectRepository(
          storageService: storage,
          fileSystemService: FileSystemService(),
        );

        final initial = await repo.getProjects();
        expect(initial, hasLength(1));

        await projectDir.delete(recursive: true);

        final pruned = await repo.reconcileWithDisk();
        expect(pruned, isEmpty);
        expect(storage.getMapList('projects'), isEmpty);
      } finally {
        await storage?.dispose();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test(
      'addOrActivateFolder reemplaza la menos usada al insertar cuarta',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'qavision_replace_',
        );
        StorageService? storage;
        try {
          final dirA = await Directory(
            '${tempDir.path}${Platform.pathSeparator}A',
          ).create(recursive: true);
          final dirB = await Directory(
            '${tempDir.path}${Platform.pathSeparator}B',
          ).create(recursive: true);
          final dirC = await Directory(
            '${tempDir.path}${Platform.pathSeparator}C',
          ).create(recursive: true);
          final dirD = await Directory(
            '${tempDir.path}${Platform.pathSeparator}D',
          ).create(recursive: true);

          storage = StorageService(
            filePath: '${tempDir.path}${Platform.pathSeparator}config.json',
          );
          await storage.init();

          final repo = ProjectRepository(
            storageService: storage,
            fileSystemService: FileSystemService(),
          );

          await repo.addOrActivateFolder(dirA.path);
          await repo.addOrActivateFolder(dirB.path);
          await repo.addOrActivateFolder(dirC.path);

          var projects = await repo.getProjects();
          expect(projects, hasLength(3));

          // Subir uso de A y B; C debe quedar como menos usada.
          final a = projects.firstWhere(
            (p) =>
                _normalizePathForAssert(p.folderPath) ==
                _normalizePathForAssert(dirA.path),
          );
          final b = projects.firstWhere(
            (p) =>
                _normalizePathForAssert(p.folderPath) ==
                _normalizePathForAssert(dirB.path),
          );
          await repo.markProjectUsed(a.id);
          await repo.markProjectUsed(a.id);
          await repo.markProjectUsed(b.id);

          await repo.addOrActivateFolder(dirD.path);
          projects = await repo.getProjects();

          expect(projects, hasLength(3));
          final names = projects.map((p) => p.name).toSet();
          expect(names.contains('D'), isTrue);
          expect(names.contains('A'), isTrue);
          expect(names.contains('B'), isTrue);
          expect(names.contains('C'), isFalse);
        } finally {
          await storage?.dispose();
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );

    test('dedupe por ruta normalizada case-insensitive', () async {
      final tempDir = await Directory.systemTemp.createTemp('qavision_dedupe_');
      StorageService? storage;
      try {
        final folder = await Directory(
          '${tempDir.path}${Platform.pathSeparator}General2',
        ).create(recursive: true);
        final lower = folder.path.replaceAll(r'\', '/');
        final upper = lower.toUpperCase();

        storage = StorageService(
          filePath: '${tempDir.path}${Platform.pathSeparator}config.json',
        );
        await storage.init();
        await storage.setMapList('projects', <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'name': 'General2',
            'folderPath': lower,
            'alias': 'GEN',
            'color': 0xFF1E88E5,
            'isDefault': true,
          },
          <String, dynamic>{
            'id': 'p2',
            'name': 'General2',
            'folderPath': upper,
            'alias': 'G2',
            'color': 0xFF43A047,
            'isDefault': false,
          },
        ]);

        final repo = ProjectRepository(
          storageService: storage,
          fileSystemService: FileSystemService(),
        );

        final projects = await repo.reconcileWithDisk();
        expect(projects, hasLength(1));
      } finally {
        await storage?.dispose();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('replaceProjectAt reemplaza exactamente el slot indicado', () async {
      final tempDir = await Directory.systemTemp.createTemp('qavision_slot_');
      StorageService? storage;
      try {
        final dirA = await Directory(
          '${tempDir.path}${Platform.pathSeparator}A',
        ).create(recursive: true);
        final dirB = await Directory(
          '${tempDir.path}${Platform.pathSeparator}B',
        ).create(recursive: true);
        final dirC = await Directory(
          '${tempDir.path}${Platform.pathSeparator}C',
        ).create(recursive: true);
        final dirX = await Directory(
          '${tempDir.path}${Platform.pathSeparator}X',
        ).create(recursive: true);

        storage = StorageService(
          filePath: '${tempDir.path}${Platform.pathSeparator}config.json',
        );
        await storage.init();

        final repo = ProjectRepository(
          storageService: storage,
          fileSystemService: FileSystemService(),
        );

        await repo.addOrActivateFolder(dirA.path);
        await repo.addOrActivateFolder(dirB.path);
        await repo.addOrActivateFolder(dirC.path);

        final before = await repo.getProjects();
        expect(before, hasLength(3));

        await repo.replaceProjectAt(slotIndex: 1, folderPath: dirX.path);
        final after = await repo.getProjects();
        expect(after, hasLength(3));
        expect(
          _normalizePathForAssert(after[1].folderPath),
          _normalizePathForAssert(dirX.path),
        );
        expect(
          after.any(
            (project) =>
                _normalizePathForAssert(project.folderPath) ==
                _normalizePathForAssert(dirB.path),
          ),
          isFalse,
        );
      } finally {
        await storage?.dispose();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
