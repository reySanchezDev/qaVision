import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';

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

      final sidecar = File('$imagePath.qav.json');
      expect(sidecar.existsSync(), isTrue);
      final sidecarRaw = await sidecar.readAsString();
      expect(sidecarRaw.contains('"elements"'), isTrue);
    });

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
      final canvasSize = bloc.state.frame.canvasSize;
      final expectedCenter = Offset(
        (canvasSize.width - centered.size.width) / 2,
        (canvasSize.height - centered.size.height) / 2,
      );
      expect(centered.position.dx, closeTo(expectedCenter.dx, 0.001));
      expect(centered.position.dy, closeTo(expectedCenter.dy, 0.001));
    });

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
        bloc
          ..add(const ViewerAnnotationStarted(Offset(320, 240)))
          ..add(const ViewerAnnotationUpdated(Offset(380, 280)))
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

        final frameSize = bloc.state.frame.canvasSize;
        expect(movedImage.position.dx >= 0, isTrue);
        expect(movedImage.position.dy >= 0, isTrue);
        expect(
          movedImage.position.dx + movedImage.size.width <= frameSize.width,
          isTrue,
        );
        expect(
          movedImage.position.dy + movedImage.size.height <= frameSize.height,
          isTrue,
        );

        final delta = movedImage.position - beforeMove.position;
        expect(
          (movedAnnotation.position.dx - annotation.position.dx - delta.dx)
                  .abs() <
              0.001,
          isTrue,
        );
        expect(
          (movedAnnotation.position.dy - annotation.position.dy - delta.dy)
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
        expect(resizedImage.size.width <= frameSize.width, isTrue);
        expect(resizedImage.size.height <= frameSize.height, isTrue);
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
  });
}
