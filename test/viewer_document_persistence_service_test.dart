import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/features/viewer/data/services/viewer_document_persistence_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_image_frame_defaults.dart';

Future<String> _writeTestJpg(String path) async {
  final image = img.Image(width: 60, height: 40);
  img.fill(image, color: img.ColorRgb8(210, 60, 60));
  final bytes = img.encodeJpg(image, quality: 90);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

void main() {
  group('ViewerDocumentPersistenceService', () {
    late Directory tempDir;
    late ViewerDocumentPersistenceService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qavision_doc_');
      service = ViewerDocumentPersistenceService(
        fileSystemService: FileSystemService(),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'prepara un frame editable separado para una sola imagen exportada',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}capture.jpg',
        );
        const baseComponent = ImageFrameComponent(
          id: 'root-image',
          position: Offset(120, 80),
          zIndex: 0,
          path: '',
          contentSize: Size(300, 200),
          style: ImageFrameStyle(
            backgroundColor: 0xFFFFFFFF,
            backgroundOpacity: 1,
            borderColor: 0x00000000,
            borderWidth: 0,
            padding: 0,
          ),
          transform: ImageFrameTransform(
            position: Offset(120, 80),
            size: Size(300, 200),
          ),
        );

        final frame = const FrameState(
          elements: [
            baseComponent,
          ],
        ).copyWith(
          elements: [
            baseComponent.copyWith(path: imagePath),
          ],
        );

        final plan = await service.prepareSavePlan(
          activeImagePath: imagePath,
          frame: frame,
        );

        final root = plan.editableFrame.elements
            .whereType<ImageFrameComponent>()
            .first;
        expect(plan.saveAsComposite, isFalse);
        expect(root.path, isNot(imagePath));
        expect(root.path.contains('.qavision'), isTrue);
        expect(File(root.path).existsSync(), isTrue);
      },
    );

    test('persiste sidecar versionado del documento editable', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}document.jpg',
      );

      const defaults = ViewerImageFrameDefaults(
        backgroundColor: 0xFFFFFFFF,
        backgroundOpacity: 1,
        borderColor: 0x00000000,
        borderWidth: 0,
        padding: 0,
      );
      final frame = await service.loadFrameForImage(
        imagePath: imagePath,
        defaults: defaults,
      );

      await service.saveEditableFrame(
        imagePath: imagePath,
        frame: frame,
      );

      final sidecarFile = File(service.sidecarPathForImage(imagePath));
      expect(sidecarFile.existsSync(), isTrue);
      final raw = await sidecarFile.readAsString();
      expect(raw.contains('"version":3'), isTrue);
      expect(raw.contains('"documentKind":"viewer_editable_document"'), isTrue);
    });
  });
}
