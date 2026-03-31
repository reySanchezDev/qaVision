import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/features/viewer/data/services/viewer_document_persistence_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';

class _FakeClipboardService extends ClipboardService {
  @override
  Future<void> copyImageToClipboard(Uint8List imageBytes) async {}
}

class _FakeShareService extends ShareService {
  @override
  Future<void> shareImageBytes(
    List<int> bytes,
    String fileName, {
    String? text,
    String? subject,
  }) async {}
}

Future<void> _drainQueue() async {
  await Future<void>.delayed(const Duration(milliseconds: 280));
}

Future<void> _waitForAutoSave(ViewerBloc bloc) async {
  for (var i = 0; i < 30; i++) {
    if (bloc.state.autoSavePath != null || bloc.state.errorMessage != null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}

Future<void> _waitForFile(String path) async {
  for (var i = 0; i < 30; i++) {
    if (File(path).existsSync()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}

Future<void> _waitForViewerIdle(ViewerBloc bloc) async {
  for (var i = 0; i < 30; i++) {
    if (!bloc.state.isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<String> _writeTestJpg(String path) async {
  final image = img.Image(width: 60, height: 40);
  img.fill(image, color: img.ColorRgb8(210, 60, 60));
  final bytes = img.encodeJpg(image, quality: 90);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

img.Image _decodeJpg(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeJpg(bytes);
  expect(decoded, isNotNull);
  return decoded!;
}

String _stripExtension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return path;
  return path.substring(0, dot);
}

void main() {
  group('ViewerBloc regressions', () {
    late Directory tempDir;
    late ViewerBloc bloc;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qavision_viewer_');
      bloc = ViewerBloc(
        fileSystemService: FileSystemService(),
        clipboardService: _FakeClipboardService(),
        shareService: _FakeShareService(),
        documentPersistenceService: ViewerDocumentPersistenceService(
          fileSystemService: FileSystemService(),
        ),
      );
    });

    tearDown(() async {
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!tempDir.existsSync()) return;

      for (var i = 0; i < 6; i++) {
        try {
          await tempDir.delete(recursive: true);
          return;
        } on PathAccessException {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
    });

    test('guarda sobre la misma imagen y crea sidecar editable', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}base.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      bloc.add(const ViewerExportRequested());
      await _waitForAutoSave(bloc);

      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.autoSavePath, imagePath);

      final files = tempDir
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .toList(growable: false);
      final hasCompositionCopy = files.any(
        (path) => path.toUpperCase().contains('_COMPOSICION_'),
      );
      expect(hasCompositionCopy, isFalse);

      final sidecar = File(
        '${tempDir.path}${Platform.pathSeparator}.qavision'
        '${Platform.pathSeparator}base.jpg.qav.json',
      );
      expect(sidecar.existsSync(), isTrue);
      final sidecarRaw = await sidecar.readAsString();
      expect(sidecarRaw.contains('"elements"'), isTrue);
    });

    test(
      'autosave crea borrador y la siguiente apertura recupera la sesion',
      () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}recover_session.jpg',
      );
      final persistence = ViewerDocumentPersistenceService(
        fileSystemService: FileSystemService(),
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      final image = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(const ViewerInteractionStarted());
      bloc.add(
        ViewerElementMoved(
          elementId: image.id,
          position: const Offset(180, 150),
        ),
      );
      await _drainQueue();
      bloc.add(const ViewerInteractionFinished());
      await _waitForAutoSave(bloc);

      final draftFile = File(
        persistence.recoveryDraftPathForImage(imagePath),
      );
      await _waitForFile(draftFile.path);
      expect(draftFile.existsSync(), isTrue);

      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      bloc = ViewerBloc(
        fileSystemService: FileSystemService(),
        clipboardService: _FakeClipboardService(),
        shareService: _FakeShareService(),
        documentPersistenceService: persistence,
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      final reopened = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      expect(reopened.position, const Offset(180, 150));
      expect(bloc.state.recoveredSession, isTrue);
      },
    );

    test(
      'al guardar una sola imagen no agrega borde extra en derecha ni abajo',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}no_border.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final base = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        final saved = _decodeJpg(imagePath);
        expect(saved.width, (base.size.width * 2).round());
        expect(saved.height, (base.size.height * 2).round());
      },
    );

    test(
      'al reabrir una imagen guardada no duplica anotaciones del sidecar',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}reopen_annotations.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final base = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        final start = base.position + const Offset(10, 10);
        final end = base.position + const Offset(40, 18);

        bloc.add(const ViewerToolChanged(AnnotationType.arrow));
        await _drainQueue();
        bloc
          ..add(ViewerAnnotationStarted(start))
          ..add(ViewerAnnotationUpdated(end))
          ..add(const ViewerAnnotationFinished());
        await _drainQueue();

        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final annotations = bloc.state.frame.elements
            .whereType<AnnotationElement>()
            .toList(growable: false);
        final reopenedBase = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;

        expect(annotations.length, 1);
        expect(reopenedBase.path, isNot(imagePath));
        expect(File(reopenedBase.path).existsSync(), isTrue);
      },
    );

    test('al abrir imagen selecciona automaticamente el frame base', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}auto_select.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      final base = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      expect(bloc.state.selectedElementId, base.id);
    });

    test(
      'reabrir una imagen guardada no cambia su frame por el zoom previo',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}zoom_reopen.jpg',
        );

        final persistence = ViewerDocumentPersistenceService(
          fileSystemService: FileSystemService(),
        );
        const baseComponent = ImageFrameComponent(
          id: 'root',
          position: Offset(120, 90),
          zIndex: 0,
          path: '',
          contentSize: Size(900, 700),
          style: ImageFrameStyle(
            backgroundColor: 0xFFFFFFFF,
            backgroundOpacity: 1,
            borderColor: 0x00000000,
            borderWidth: 0,
            padding: 0,
          ),
          transform: ImageFrameTransform(
            position: Offset(120, 90),
            size: Size(900, 700),
          ),
          isLockedBase: true,
        );
        final frame =
            FrameState(
              canvasSize: const Size(1500, 900),
              elements: [baseComponent.copyWith(path: imagePath)],
            ).copyWith(
              elements: [baseComponent.copyWith(path: imagePath)],
            );

        await persistence.saveEditableFrame(imagePath: imagePath, frame: frame);

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);
        bloc.add(const ViewerZoomChanged(2.4));
        await _drainQueue();

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final reopened = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        expect(reopened.size.width, closeTo(900, 0.001));
        expect(reopened.size.height, closeTo(700, 0.001));
      },
    );

    test('permite redimensionar imagen por debajo de 48px', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}small.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();

      final image = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(
        ViewerElementResized(
          elementId: image.id,
          size: const Size(12, 9),
        ),
      );
      await _drainQueue();

      final resized = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);
      expect(resized.size.width, 12);
      expect(resized.size.height, 9);
    });

    test('seleccion puede centrar o mantener posicion de imagen', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}select_center.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      final image = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(
        ViewerElementMoved(
          elementId: image.id,
          position: const Offset(40, 50),
        ),
      );
      await _drainQueue();

      final moved = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);
      expect(moved.position, const Offset(40, 50));

      bloc.add(
        ViewerElementSelected(
          elementId: moved.id,
          centerImage: false,
        ),
      );
      await _drainQueue();

      final kept = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);
      expect(kept.position, const Offset(40, 50));

      bloc.add(
        ViewerElementSelected(
          elementId: kept.id,
        ),
      );
      await _drainQueue();

      final centered = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);
      final workspaceRect = ViewerWorkspaceLayout.resolve(
        bloc.state.frame.canvasSize,
      );
      final expectedCenter = Offset(
        workspaceRect.left + (workspaceRect.width - centered.size.width) / 2,
        workspaceRect.top + (workspaceRect.height - centered.size.height) / 2,
      );
      expect(centered.position.dx, closeTo(expectedCenter.dx, 0.001));
      expect(centered.position.dy, closeTo(expectedCenter.dy, 0.001));
    });

    test(
      'con zoom reducido la imagen raiz puede recorrer todo el workspace',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}zoom_reduced_move.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        bloc.add(const ViewerZoomChanged(0.5));
        await _drainQueue();

        final image = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        final workspace = ViewerWorkspaceLayout.resolve(
          bloc.state.frame.canvasSize,
        );

        bloc.add(
          ViewerElementMoved(
            elementId: image.id,
            position: const Offset(99999, 99999),
          ),
        );
        await _drainQueue();

        final moved = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((element) => element.id == image.id);
        expect(
          moved.position.dx,
          closeTo(workspace.right - (moved.size.width * 0.5), 0.001),
        );
        expect(
          moved.position.dy,
          closeTo(workspace.bottom - (moved.size.height * 0.5), 0.001),
        );
      },
    );

    test(
      'mantiene la imagen completamente dentro del workspace del visor',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}clamp_inside_canvas.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final image = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;

        bloc.add(
          ViewerElementMoved(
            elementId: image.id,
            position: const Offset(-500, -300),
          ),
        );
        await _drainQueue();

        final movedToOrigin = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((element) => element.id == image.id);
        final workspaceRectAtOrigin = ViewerWorkspaceLayout.resolve(
          bloc.state.frame.canvasSize,
        );
        expect(
          movedToOrigin.position.dx,
          greaterThanOrEqualTo(workspaceRectAtOrigin.left),
        );
        expect(
          movedToOrigin.position.dy,
          greaterThanOrEqualTo(workspaceRectAtOrigin.top),
        );

        final workspaceRect = ViewerWorkspaceLayout.resolve(
          bloc.state.frame.canvasSize,
        );
        bloc.add(
          ViewerElementMoved(
            elementId: image.id,
            position: const Offset(99999, 99999),
          ),
        );
        await _drainQueue();

        final movedToEdge = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((element) => element.id == image.id);
        expect(
          movedToEdge.position.dx,
          lessThanOrEqualTo(workspaceRect.right - movedToEdge.size.width),
        );
        expect(
          movedToEdge.position.dy,
          lessThanOrEqualTo(workspaceRect.bottom - movedToEdge.size.height),
        );
      },
    );

    test('redimensiona hacia arriba/izquierda sin escalar contenido', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}resize_top_left.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      final image = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(
        ViewerElementMoved(
          elementId: image.id,
          position: const Offset(220, 180),
        ),
      );
      await _drainQueue();

      final moved = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);
      final originalContentSize = moved.contentSize;

      final newPosition = Offset(
        moved.position.dx - 70,
        moved.position.dy - 55,
      );
      final newSize = Size(
        moved.size.width + 70,
        moved.size.height + 55,
      );

      bloc.add(
        ViewerElementResized(
          elementId: moved.id,
          size: newSize,
          position: newPosition,
        ),
      );
      await _drainQueue();

      final resized = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((element) => element.id == image.id);

      expect(resized.position.dx, closeTo(newPosition.dx, 0.001));
      expect(resized.position.dy, closeTo(newPosition.dy, 0.001));
      expect(resized.size.width, closeTo(newSize.width, 0.001));
      expect(resized.size.height, closeTo(newSize.height, 0.001));
      expect(
        resized.contentSize.width,
        closeTo(originalContentSize.width, 0.001),
      );
      expect(
        resized.contentSize.height,
        closeTo(originalContentSize.height, 0.001),
      );
    });

    test(
      'redimensionar frame no escala automaticamente el contenido',
      () async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}no_scale.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final image = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        final originalContentSize = image.contentSize;
        bloc.add(
          ViewerElementResized(
            elementId: image.id,
            size: Size(image.size.width * 0.6, image.size.height * 0.6),
          ),
        );
        await _drainQueue();

        final resized = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((element) => element.id == image.id);
        expect(
          resized.contentSize.width,
          closeTo(originalContentSize.width, 0.001),
        );
        expect(
          resized.contentSize.height,
          closeTo(originalContentSize.height, 0.001),
        );
      },
    );

    test('permite mover imagen dentro del frame con clipping', () async {
      final imagePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}encuadre.jpg',
      );

      bloc.add(ViewerStarted(imagePath: imagePath));
      await _drainQueue();
      await _waitForViewerIdle(bloc);

      var image = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(
        ViewerElementResized(
          elementId: image.id,
          size: Size(image.size.width * 0.5, image.size.height * 0.5),
        ),
      );
      await _drainQueue();

      image = bloc.state.frame.elements.whereType<ImageFrameComponent>().first;
      bloc.add(
        ViewerImageContentMoved(
          elementId: image.id,
          contentOffset: const Offset(-200, -160),
        ),
      );
      await _drainQueue();

      final moved = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      expect(moved.contentOffset.dx, lessThanOrEqualTo(0));
      expect(moved.contentOffset.dy, lessThanOrEqualTo(0));

      bloc.add(
        ViewerImageContentMoved(
          elementId: moved.id,
          contentOffset: const Offset(9999, 9999),
        ),
      );
      await _drainQueue();

      final clamped = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      expect(clamped.contentOffset.dx, greaterThanOrEqualTo(0));
      expect(clamped.contentOffset.dy, greaterThanOrEqualTo(0));
    });

    test('actualiza carpeta de miniaturas al cambiar proyecto', () async {
      final projectA = Directory(
        '${tempDir.path}${Platform.pathSeparator}A',
      );
      final projectB = Directory(
        '${tempDir.path}${Platform.pathSeparator}B',
      );
      await projectA.create(recursive: true);
      await projectB.create(recursive: true);
      final imageA = await _writeTestJpg('${projectA.path}/a.jpg');
      await _writeTestJpg('${projectB.path}/b1.jpg');
      await _writeTestJpg('${projectB.path}/b2.jpg');

      bloc.add(ViewerStarted(imagePath: imageA));
      await _drainQueue();
      bloc.add(ViewerRecentCapturesRequested(projectPath: projectB.path));
      await _drainQueue();

      expect(bloc.state.recentProjectPath, projectB.path);
      expect(bloc.state.recentCaptures.length, 2);
      for (final capturePath in bloc.state.recentCaptures) {
        expect(
          capturePath.contains(
            '${Platform.pathSeparator}B${Platform.pathSeparator}',
          ),
          isTrue,
        );
      }
    });

    test(
      'agrega imagenes, redimensiona, respeta frame y mueve anotaciones '
      'adjuntas',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}base_layout.jpg',
        );
        final extraPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}extra_layout.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        bloc.add(
          ViewerImageAdded(
            imagePath: extraPath,
            projectPath: tempDir.path,
            position: const Offset(300, 220),
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final beforeMove = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => !image.isLockedBase);

        bloc.add(const ViewerToolChanged(AnnotationType.arrow));
        await _drainQueue();
        final startPoint = beforeMove.position + const Offset(20, 20);
        final endPoint = beforeMove.position + const Offset(80, 60);
        bloc
          ..add(ViewerAnnotationStarted(startPoint))
          ..add(ViewerAnnotationUpdated(endPoint))
          ..add(const ViewerAnnotationFinished());
        await _drainQueue();

        final annotation = bloc.state.frame.elements
            .whereType<AnnotationElement>()
            .last;
        expect(annotation.attachedImageId, beforeMove.id);

        bloc.add(
          ViewerElementMoved(
            elementId: beforeMove.id,
            position: const Offset(20000, 20000),
          ),
        );
        await _drainQueue();

        final movedImage = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.id == beforeMove.id);
        final movedAnnotation = bloc.state.frame.elements
            .whereType<AnnotationElement>()
            .firstWhere((element) => element.id == annotation.id);

        final workspaceRect = ViewerWorkspaceLayout.resolve(
          bloc.state.frame.canvasSize,
        );
        expect(
          movedImage.position.dx + movedImage.size.width <= workspaceRect.right,
          isTrue,
        );
        expect(
          movedImage.position.dy + movedImage.size.height <=
              workspaceRect.bottom,
          isTrue,
        );
        expect(
          movedImage.position.dx >= workspaceRect.left,
          isTrue,
        );
        expect(
          movedImage.position.dy >= workspaceRect.top,
          isTrue,
        );

        final projectedBefore = ViewerCompositionHelper.projectAnnotation(
          [beforeMove, annotation],
          annotation,
        );
        final projectedAfter = ViewerCompositionHelper.projectAnnotation(
          [movedImage, movedAnnotation],
          movedAnnotation,
        );
        final delta = movedImage.position - beforeMove.position;
        expect(
          (projectedAfter.position.dx - projectedBefore.position.dx - delta.dx)
                  .abs() <
              0.001,
          isTrue,
        );
        expect(
          (projectedAfter.position.dy - projectedBefore.position.dy - delta.dy)
                  .abs() <
              0.001,
          isTrue,
        );

        bloc.add(
          ViewerElementResized(
            elementId: movedImage.id,
            size: const Size(60000, 60000),
          ),
        );
        await _drainQueue();

        final resizedImage = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.id == movedImage.id);
        expect(resizedImage.size.width <= workspaceRect.width, isTrue);
        expect(resizedImage.size.height <= workspaceRect.height, isTrue);
      },
    );

    test('permite cambiar fondo de frame y deshacer/rehacer', () async {
      final basePath = await _writeTestJpg(
        '${tempDir.path}${Platform.pathSeparator}base_frame_style.jpg',
      );

      bloc.add(ViewerStarted(imagePath: basePath));
      await _drainQueue();

      final baseImage = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .first;
      bloc.add(ViewerElementSelected(elementId: baseImage.id));
      await _drainQueue();

      bloc.add(
        const ViewerSelectedFrameStyleChanged(
          frameBackgroundColor: 0xFFE3F2FD,
          frameBackgroundOpacity: 0.4,
          frameBorderWidth: 2.5,
          framePadding: 8,
        ),
      );
      await _drainQueue();

      final changed = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((image) => image.id == baseImage.id);
      expect(changed.style.backgroundColor, 0xFFE3F2FD);
      expect(changed.style.backgroundOpacity, closeTo(0.4, 0.001));
      expect(changed.style.borderWidth, closeTo(2.5, 0.001));
      expect(changed.style.padding, closeTo(8, 0.001));

      bloc.add(const ViewerUndoRequested());
      await _drainQueue();
      final undone = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((image) => image.id == baseImage.id);
      expect(undone.style.backgroundColor, isNot(0xFFE3F2FD));

      bloc.add(const ViewerRedoRequested());
      await _drainQueue();
      final redone = bloc.state.frame.elements
          .whereType<ImageFrameComponent>()
          .firstWhere((image) => image.id == baseImage.id);
      expect(redone.style.backgroundColor, 0xFFE3F2FD);
    });

    test(
      'inserta imagenes dentro del frame seleccionado '
      'y guarda como una sola salida',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}base_nested.jpg',
        );
        final extraPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}extra_nested.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final baseImage = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerElementResized(
            elementId: baseImage.id,
            size: const Size(420, 320),
          ),
        );
        await _drainQueue();

        bloc.add(
          ViewerImageAdded(
            imagePath: extraPath,
            projectPath: tempDir.path,
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final images = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .toList(growable: false);
        expect(images.length, 2);

        final root = images.firstWhere(
          (image) => image.parentImageId == null,
        );
        final child = images.firstWhere(
          (image) => image.parentImageId == root.id,
        );
        expect(
          root.contentViewportRect.contains(child.frameRect.topLeft),
          isTrue,
        );
        expect(
          root.contentViewportRect.contains(child.frameRect.bottomRight),
          isTrue,
        );

        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        expect(bloc.state.autoSavePath, basePath);
        expect(
          File('${_stripExtension(basePath)}_compuesto.jpg').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'con multiples imagenes genera compuesto adicional y conserva original',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}base_comp.jpg',
        );
        final extraPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}extra_comp.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        bloc.add(const ViewerElementSelected());
        await _drainQueue();

        bloc.add(
          ViewerImageAdded(
            imagePath: extraPath,
            projectPath: tempDir.path,
            position: const Offset(90, 90),
          ),
        );
        await _drainQueue();

        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        final output = bloc.state.autoSavePath;
        expect(output, isNotNull);
        final expectedCompositePath =
            '${_stripExtension(basePath)}_compuesto.jpg';
        expect(output, expectedCompositePath);
        expect(File(basePath).existsSync(), isTrue);
        expect(File(expectedCompositePath).existsSync(), isTrue);
        final generatedComposed = tempDir
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  file.path.toLowerCase().contains('_compuesto') &&
                  file.path.toLowerCase().endsWith('.jpg'),
            )
            .toList(growable: false);
        expect(generatedComposed.length, 1);
      },
    );

    test(
      'inserta imagen dentro del frame bajo el punto de drop '
      'aunque no este seleccionado',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}drop_into_frame.jpg',
        );
        final extraPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}drop_child.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final baseImage = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerElementResized(
            elementId: baseImage.id,
            size: const Size(420, 320),
          ),
        );
        await _drainQueue();

        bloc.add(const ViewerElementSelected());
        await _drainQueue();

        final refreshedBase = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerImageAdded(
            imagePath: extraPath,
            projectPath: tempDir.path,
            position: refreshedBase.contentViewportRect.center,
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final images = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .toList(growable: false);
        expect(images.length, 2);

        final root = images.firstWhere((image) => image.parentImageId == null);
        final child = images.firstWhere(
          (image) => image.parentImageId == root.id,
        );
        expect(
          root.contentViewportRect.contains(child.frameRect.topLeft),
          isTrue,
        );
        expect(
          root.contentViewportRect.contains(child.frameRect.bottomRight),
          isTrue,
        );
      },
    );

    test(
      'redimensionar un frame padre conserva la posicion absoluta '
      'de sus subimagenes cuando siguen dentro del viewport',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}resize_parent_base.jpg',
        );
        final childPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}resize_parent_child.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final root = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerElementResized(
            elementId: root.id,
            size: const Size(900, 600),
            position: const Offset(100, 80),
          ),
        );
        await _drainQueue();

        bloc.add(
          ViewerImageAdded(
            imagePath: childPath,
            projectPath: tempDir.path,
            position: const Offset(700, 220),
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final rootBefore = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == null);
        final childBefore = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == rootBefore.id);
        final expectedAbsolutePosition = childBefore.position;

        bloc.add(
          ViewerElementResized(
            elementId: rootBefore.id,
            size: const Size(1050, 680),
            position: const Offset(140, 110),
          ),
        );
        await _drainQueue();

        final rootAfter = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.id == rootBefore.id);
        final childAfter = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.id == childBefore.id);

        expect(
          childAfter.position.dx,
          closeTo(expectedAbsolutePosition.dx, 0.001),
        );
        expect(
          childAfter.position.dy,
          closeTo(expectedAbsolutePosition.dy, 0.001),
        );
        expect(
          rootAfter.contentViewportRect.contains(childAfter.frameRect.topLeft),
          isTrue,
        );
        expect(
          rootAfter.contentViewportRect.contains(
            childAfter.frameRect.bottomRight,
          ),
          isTrue,
        );
      },
    );

    test(
      'si el drop cae fuera del frame seleccionado inserta una nueva raiz',
      () async {
        final basePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}drop_outside_selected.jpg',
        );
        final extraPath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}drop_outside_child.jpg',
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final baseImage = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        final outsideDropPoint = Offset(
          bloc.state.frame.canvasSize.width - 40,
          bloc.state.frame.canvasSize.height - 40,
        );
        bloc.add(
          ViewerElementResized(
            elementId: baseImage.id,
            size: const Size(320, 260),
          ),
        );
        await _drainQueue();

        bloc.add(
          ViewerImageAdded(
            imagePath: extraPath,
            projectPath: tempDir.path,
            position: outsideDropPoint,
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final images = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .toList(growable: false);
        expect(images.length, 2);
        expect(
          images.where((image) => image.parentImageId == null).length,
          2,
        );
      },
    );

    test(
      'guardar una composicion con subimagen conserva su posicion relativa',
      () async {
        final basePath =
            '${tempDir.path}${Platform.pathSeparator}root_green.jpg';
        final childPath =
            '${tempDir.path}${Platform.pathSeparator}child_dark.jpg';

        final green = img.Image(width: 900, height: 600);
        img.fill(green, color: img.ColorRgb8(180, 255, 0));
        await File(basePath).writeAsBytes(
          img.encodeJpg(green, quality: 90),
          flush: true,
        );

        final dark = img.Image(width: 300, height: 220);
        img.fill(dark, color: img.ColorRgb8(24, 28, 36));
        await File(childPath).writeAsBytes(
          img.encodeJpg(dark, quality: 90),
          flush: true,
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final root = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerElementResized(
            elementId: root.id,
            size: const Size(900, 600),
            position: const Offset(100, 80),
          ),
        );
        await _drainQueue();

        bloc.add(
          ViewerImageAdded(
            imagePath: childPath,
            projectPath: tempDir.path,
            position: const Offset(680, 220),
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final updatedRoot = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == null);
        final child = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == updatedRoot.id);
        final expectedRelativeTopLeft =
            child.frameRect.topLeft - updatedRoot.frameRect.topLeft;

        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        final saved = _decodeJpg(basePath);
        var minX = saved.width;
        var minY = saved.height;
        var maxX = -1;
        var maxY = -1;

        for (var y = 0; y < saved.height; y++) {
          for (var x = 0; x < saved.width; x++) {
            final pixel = saved.getPixel(x, y);
            if (pixel.r < 80 && pixel.g < 90 && pixel.b < 100) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
            }
          }
        }

        expect(maxX, greaterThanOrEqualTo(0));
        expect(minX, closeTo(expectedRelativeTopLeft.dx * 2, 30));
        expect(minY, closeTo(expectedRelativeTopLeft.dy * 2, 30));
      },
    );

    test(
      'guardar con zoom activo conserva la posicion relativa de la subimagen',
      () async {
        final basePath =
            '${tempDir.path}${Platform.pathSeparator}root_zoom.jpg';
        final childPath =
            '${tempDir.path}${Platform.pathSeparator}child_zoom.jpg';

        final green = img.Image(width: 900, height: 600);
        img.fill(green, color: img.ColorRgb8(180, 255, 0));
        await File(basePath).writeAsBytes(
          img.encodeJpg(green, quality: 90),
          flush: true,
        );

        final dark = img.Image(width: 300, height: 220);
        img.fill(dark, color: img.ColorRgb8(24, 28, 36));
        await File(childPath).writeAsBytes(
          img.encodeJpg(dark, quality: 90),
          flush: true,
        );

        bloc.add(ViewerStarted(imagePath: basePath));
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final root = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .first;
        bloc.add(
          ViewerElementResized(
            elementId: root.id,
            size: const Size(900, 600),
            position: const Offset(100, 80),
          ),
        );
        await _drainQueue();

        bloc.add(const ViewerZoomChanged(1.09));
        await _drainQueue();

        const visualDropPoint = Offset(680, 220);
        bloc.add(
          ViewerImageAdded(
            imagePath: childPath,
            projectPath: tempDir.path,
            position: visualDropPoint,
          ),
        );
        await _drainQueue();
        await _waitForViewerIdle(bloc);

        final updatedRoot = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == null);
        final child = bloc.state.frame.elements
            .whereType<ImageFrameComponent>()
            .firstWhere((image) => image.parentImageId == updatedRoot.id);
        final expectedRelativeTopLeft =
            child.frameRect.topLeft - updatedRoot.frameRect.topLeft;

        bloc.add(const ViewerExportRequested());
        await _waitForAutoSave(bloc);

        final saved = _decodeJpg(basePath);
        var minX = saved.width;
        var minY = saved.height;
        var maxX = -1;

        for (var y = 0; y < saved.height; y++) {
          for (var x = 0; x < saved.width; x++) {
            final pixel = saved.getPixel(x, y);
            if (pixel.r < 80 && pixel.g < 90 && pixel.b < 100) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
            }
          }
        }

        expect(maxX, greaterThanOrEqualTo(0));
        expect(minX, closeTo(expectedRelativeTopLeft.dx * 2, 30));
        expect(minY, closeTo(expectedRelativeTopLeft.dy * 2, 30));
      },
    );
  });
}
