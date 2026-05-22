import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/video_recording_service.dart';
import 'package:qavision/features/video/domain/entities/video_recording_target.dart';

void main() {
  group('VideoRecordingService', () {
    test('construye args de ffmpeg para una región', () {
      final service = VideoRecordingService(
        fileSystemService: FileSystemService(),
      );

      final args = service.buildFfmpegArgs(
        target: const VideoRecordingTarget(
          kind: VideoRecordingSourceKind.region,
          label: 'Área',
          desktopRect: Rect.fromLTWH(100, 200, 640, 480),
        ),
        outputPath: r'C:\tmp\video.mp4',
      );

      expect(
        args,
        containsAllInOrder(<String>[
          '-f',
          'gdigrab',
          '-offset_x',
          '100',
          '-offset_y',
          '200',
          '-video_size',
          '640x480',
          '-i',
          'desktop',
          r'C:\tmp\video.mp4',
        ]),
      );
    });

    test('construye args de ffmpeg para una pantalla completa', () {
      final service = VideoRecordingService(
        fileSystemService: FileSystemService(),
      );

      final args = service.buildFfmpegArgs(
        target: const VideoRecordingTarget(
          kind: VideoRecordingSourceKind.display,
          label: 'Pantalla 2',
          desktopRect: Rect.fromLTWH(-1920, 0, 1920, 1080),
        ),
        outputPath: r'C:\tmp\display.mp4',
      );

      expect(
        args,
        containsAllInOrder(<String>[
          '-offset_x',
          '-1920',
          '-offset_y',
          '0',
          '-video_size',
          '1920x1080',
          '-i',
          'desktop',
          r'C:\tmp\display.mp4',
        ]),
      );
    });
  });
}
