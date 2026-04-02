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
        canvasZoom: 1.0,
      );

      final sidecarFile = File(service.sidecarPathForImage(imagePath));
      expect(sidecarFile.existsSync(), isTrue);
      final raw = await sidecarFile.readAsString();
      expect(raw.contains('"version":5'), isTrue);
      expect(raw.contains('"documentKind":"viewer_editable_document"'), isTrue);
    });

    test('persiste y recupera bloques de texto enriquecido', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}rich_panel.jpg',
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
      final enriched = frame.copyWith(
        elements: [
          ...frame.elements,
          const AnnotationElement(
            id: 'rich-panel',
            type: AnnotationType.richTextPanel,
            color: 0xFF123456,
            strokeWidth: 2,
            textSize: 22,
            position: Offset(180, 120),
            endPosition: Offset(520, 320),
            text: 'Se valido guardar y editar.',
            richTextDelta:
                '[{\"insert\":\"Se valido \"},{\"insert\":\"guardar\",\"attributes\":{\"bold\":true}},{\"insert\":\" y \"},{\"insert\":\"editar\",\"attributes\":{\"background\":\"#FFF59D\"}},{\"insert\":\".\\n\"}]',
            fontFamily: 'Georgia',
            isBold: true,
            isItalic: false,
            hasShadow: true,
            backgroundColor: 0xF7FFF8E1,
            panelAlignment: ViewerTextPanelAlignment.justify,
            zIndex: 88,
          ),
        ],
      );

      await service.saveEditableFrame(
        imagePath: imagePath,
        frame: enriched,
        canvasZoom: 1.0,
      );

      final loaded = await service.loadFrameForImage(
        imagePath: imagePath,
        defaults: defaults,
      );
      final panel = loaded.elements
          .whereType<AnnotationElement>()
          .firstWhere((element) => element.id == 'rich-panel');
      expect(panel.type, AnnotationType.richTextPanel);
      expect(panel.fontFamily, 'Georgia');
      expect(panel.isBold, isTrue);
      expect(panel.hasShadow, isTrue);
      expect(panel.backgroundColor, 0xF7FFF8E1);
      expect(panel.panelAlignment, ViewerTextPanelAlignment.justify);
      expect(panel.text, contains('editar'));
      expect(panel.richTextDelta, contains('background'));
    });

    test('recupera borrador cuando es mas nuevo que el sidecar', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}recover.jpg',
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
        canvasZoom: 1.0,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final mutated = frame.copyWith(
        elements: [
          ...(frame.elements),
          const AnnotationElement(
            id: 'draft-note',
            type: AnnotationType.text,
            color: 0xFFE53935,
            strokeWidth: 2,
            textSize: 18,
            position: Offset(220, 180),
            text: 'draft',
            zIndex: 99,
          ),
        ],
      );
      await service.saveRecoveryDraft(
        imagePath: imagePath,
        frame: mutated,
        canvasZoom: 1.0,
      );

      final result = await service.loadFrameResultForImage(
        imagePath: imagePath,
        defaults: defaults,
      );

      expect(result.recoveredFromDraft, isTrue);
      expect(
        result.frame.elements.any((element) => element.id == 'draft-note'),
        isTrue,
      );
    });

    test(
      'normaliza panel de texto adjunto reciente al espacio imageFrame al cargar',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}recent_rich_panel.jpg',
        );

        const defaults = ViewerImageFrameDefaults(
          backgroundColor: 0xFFFFFFFF,
          backgroundOpacity: 1,
          borderColor: 0x00000000,
          borderWidth: 0,
          padding: 0,
        );

        final baseFrame = await service.loadFrameForImage(
          imagePath: imagePath,
          defaults: defaults,
        );
        final image = baseFrame.elements.whereType<ImageFrameComponent>().first;
        final brokenFrame = baseFrame.copyWith(
          elements: [
            ...baseFrame.elements,
            AnnotationElement(
              id: 'recent-panel',
              type: AnnotationType.richTextPanel,
              color: 0xFF222222,
              strokeWidth: 1.5,
              textSize: 18,
              position: image.contentViewportRect.topLeft + const Offset(40, 24),
              endPosition:
                  image.contentViewportRect.topLeft + const Offset(260, 144),
              text: 'panel',
              richTextDelta: '[{"insert":"panel\\n"}]',
              attachedImageId: image.id,
              coordinateSpace: AnnotationCoordinateSpace.workspace,
              zIndex: 50,
            ),
          ],
        );

        await service.saveEditableFrame(
          imagePath: imagePath,
          frame: brokenFrame,
          canvasZoom: 1.0,
        );

        final loaded = await service.loadFrameForImage(
          imagePath: imagePath,
          defaults: defaults,
        );
        final panel = loaded.elements
            .whereType<AnnotationElement>()
            .firstWhere((element) => element.id == 'recent-panel');

        expect(panel.coordinateSpace, AnnotationCoordinateSpace.imageFrame);
      },
    );
  });
}
