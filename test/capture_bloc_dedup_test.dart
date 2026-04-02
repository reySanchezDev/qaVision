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
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

class _InMemoryCaptureRepository implements ICaptureRepository {
  final List<CaptureEntity> _captures = <CaptureEntity>[];

  int get savedCount => _captures.length;

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
}
