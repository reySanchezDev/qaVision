import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

class _InMemoryCaptureRepository implements ICaptureRepository {
  final List<CaptureEntity> _captures = <CaptureEntity>[];

  int get savedCount => _captures.length;
  List<CaptureEntity> get captures => List<CaptureEntity>.from(_captures);

  @override
  Future<void> deleteCapture(String id) async {
    _captures.removeWhere((capture) => capture.id == id);
  }

  @override
  Future<List<CaptureEntity>> getHistory() async =>
      List<CaptureEntity>.from(_captures);

  @override
  Future<List<CaptureEntity>> getRecentCaptures({int limit = 10}) async {
    return _captures.take(limit).toList(growable: false);
  }

  @override
  Future<void> saveCapture(CaptureEntity capture) async {
    _captures.add(capture);
  }

  @override
  Future<void> updateCapture(CaptureEntity capture) async {
    final index = _captures.indexWhere((item) => item.id == capture.id);
    if (index < 0) {
      _captures.add(capture);
      return;
    }
    _captures[index] = capture;
  }
}

class _DelayedCaptureService extends CaptureService {
  _DelayedCaptureService()
    : super(
        fileSystemService: FileSystemService(),
        nativeCaptureService: NativeScreenCaptureService(),
      );

  int callCount = 0;

  @override
  Future<String?> captureAndSave({
    required ProjectEntity project,
    Rect? captureRect,
    String? fileNameOverride,
  }) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return 'C:/tmp/qavision/test_${DateTime.now().microsecondsSinceEpoch}.jpg';
  }
}

class _RecordingClipboardService extends ClipboardService {
  int imagePathCopyCount = 0;

  @override
  Future<void> copyImageFileToClipboard(String imagePath) async {
    imagePathCopyCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowManagerChannel = MethodChannel('window_manager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, (call) async {
          switch (call.method) {
            case 'isVisible':
              return true;
            case 'isMinimized':
            case 'isMaximized':
            case 'isFocused':
            case 'isAlwaysOnTop':
            case 'isPreventClose':
              return false;
            case 'hide':
            case 'show':
              return null;
            default:
              if (call.method.startsWith('is')) {
                return false;
              }
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowManagerChannel, null);
  });

  test(
    'CaptureBloc ignora solicitudes superpuestas y evita doble guardado',
    () async {
      final captureService = _DelayedCaptureService();
      final captureRepository = _InMemoryCaptureRepository();
      final clipboardService = _RecordingClipboardService();
      final bloc = CaptureBloc(
        captureService: captureService,
        captureRepository: captureRepository,
        clipboardService: clipboardService,
        fileSystemService: FileSystemService(),
      );

      const project = ProjectEntity(
        id: 'p1',
        name: 'General',
        folderPath: 'C:/tmp/qavision/General',
        alias: 'GEN',
        color: 0xFF1E88E5,
        isDefault: true,
      );

      bloc
        ..add(const CaptureRequested(project: project))
        ..add(const CaptureRequested(project: project));

      await Future<void>.delayed(const Duration(milliseconds: 320));

      expect(captureService.callCount, 1);
      expect(captureRepository.savedCount, 1);
      expect(clipboardService.imagePathCopyCount, 1);

      await bloc.close();
    },
  );

  test('CaptureBloc renombra la captura y actualiza el historial', () async {
    final tempDir = await Directory.systemTemp.createTemp('qavision_capture_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final originalFile = File('${tempDir.path}/original.png');
    await originalFile.writeAsBytes(const <int>[1, 2, 3, 4]);

    final captureRepository = _InMemoryCaptureRepository();
    final originalCapture = CaptureEntity(
      id: 'capture-1',
      path: 'ORIGINAL_PATH_PLACEHOLDER',
      timestamp: DateTime(2026, 4, 9),
      projectName: 'General',
    );
    await captureRepository.saveCapture(
      CaptureEntity(
        id: originalCapture.id,
        path: 'ORIGINAL_PATH_PLACEHOLDER',
        timestamp: originalCapture.timestamp,
        projectName: originalCapture.projectName,
      ),
    );

    final bloc = CaptureBloc(
      captureService: _DelayedCaptureService(),
      captureRepository: captureRepository,
      clipboardService: _RecordingClipboardService(),
      fileSystemService: FileSystemService(),
    );

    final capture = CaptureEntity(
      id: originalCapture.id,
      path: originalFile.path,
      timestamp: originalCapture.timestamp,
      projectName: originalCapture.projectName,
    );

    bloc.add(
      CaptureRenameRequested(
        capture: capture,
        fileNameOverride: 'Pantalla-A1',
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    final renamed = File('${tempDir.path}/Pantalla-A1.png');
    expect(renamed.existsSync(), isTrue);
    expect(originalFile.existsSync(), isFalse);
    expect(bloc.state, isA<CaptureSuccessSilent>());
    expect(captureRepository.captures.single.path, renamed.path);

    await bloc.close();
  });
}
