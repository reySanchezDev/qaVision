import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

class _FakeNativeScreenCaptureService extends NativeScreenCaptureService {
  _FakeNativeScreenCaptureService(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> capturePngBytes({Rect? region, int quality = 95}) async {
    return bytes;
  }
}

void main() {
  test('CaptureService guarda las capturas nuevas como PNG', () async {
    final tempDir = await Directory.systemTemp.createTemp('qavision_capture_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = CaptureService(
      fileSystemService: FileSystemService(),
      nativeCaptureService: _FakeNativeScreenCaptureService(
        Uint8List.fromList(<int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
        ]),
      ),
    );

    final path = await service.captureAndSave(
      project: ProjectEntity(
        id: 'p1',
        name: 'General',
        folderPath: tempDir.path,
        alias: 'GEN',
        color: 0xFF1E88E5,
        isDefault: true,
      ),
    );

    expect(path, isNotNull);
    expect(path, endsWith('.png'));

    final saved = File(path!);
    expect(saved.existsSync(), isTrue);
    final bytes = await saved.readAsBytes();
    expect(bytes.take(8).toList(), equals(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]));
  });
}
