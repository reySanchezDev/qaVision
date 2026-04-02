import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:qavision/features/viewer/data/services/viewer_document_persistence_service.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas.dart';

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

class _FakeSettingsRepository implements ISettingsRepository {
  @override
  Future<SettingsEntity> loadSettings() async {
    return const SettingsEntity(jpgQuality: JpgQuality.max);
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {}
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

Future<void> _drain() async {
  await Future<void>.delayed(const Duration(milliseconds: 420));
}

Future<void> _waitForViewerIdle(ViewerBloc bloc) async {
  for (var i = 0; i < 30; i++) {
    if (!bloc.state.isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  group('ViewerCanvas numerador interaction', () {
    late Directory tempDir;
    late ViewerBloc bloc;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'qavision_viewer_canvas_',
      );
      bloc = ViewerBloc(
        fileSystemService: FileSystemService(),
        clipboardService: _FakeClipboardService(),
        shareService: _FakeShareService(),
        documentPersistenceService: ViewerDocumentPersistenceService(
          fileSystemService: FileSystemService(),
        ),
        settingsRepository: _FakeSettingsRepository(),
      );
    });

    tearDown(() async {
      await bloc.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'permite arrastrar un numerador existente sin salir de la herramienta',
      (tester) async {
        final imagePath = await _writeTestJpg(
          '${tempDir.path}${Platform.pathSeparator}step_marker_canvas.jpg',
        );

        bloc.add(ViewerStarted(imagePath: imagePath));
        await tester.runAsync(() async {
          await _drain();
          await _waitForViewerIdle(bloc);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlocProvider<ViewerBloc>.value(
                value: bloc,
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: ViewerCanvas(contentZoom: 1),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        bloc.add(const ViewerToolChanged(AnnotationType.stepMarker));
        await tester.pump();

        final canvasTopLeft = tester.getTopLeft(find.byType(ViewerCanvas));
        final initialTap = canvasTopLeft + const Offset(220, 180);
        await tester.tapAt(initialTap);
        await tester.runAsync(_drain);
        await tester.pumpAndSettle();

        final beforeMarker = bloc.state.frame.elements
            .whereType<AnnotationElement>()
            .firstWhere((element) => element.type == AnnotationType.stepMarker);
        final beforeProjected = ViewerCompositionHelper.projectAnnotation(
          bloc.state.frame.elements,
          beforeMarker,
          imageZoom: 1,
        );

        await tester.dragFrom(
          canvasTopLeft + beforeProjected.position,
          const Offset(90, 40),
        );
        await tester.runAsync(_drain);
        await tester.pumpAndSettle();

        final markers = bloc.state.frame.elements
            .whereType<AnnotationElement>()
            .where((element) => element.type == AnnotationType.stepMarker)
            .toList(growable: false);
        final afterMarker = markers.firstWhere(
          (element) => element.id == beforeMarker.id,
        );
        final afterProjected = ViewerCompositionHelper.projectAnnotation(
          bloc.state.frame.elements,
          afterMarker,
          imageZoom: 1,
        );

        expect(markers.length, 1);
        expect(
          afterProjected.position.dx,
          greaterThan(beforeProjected.position.dx + 40),
        );
        expect(
          afterProjected.position.dy,
          greaterThan(beforeProjected.position.dy + 10),
        );
      },
    );
  });
}
