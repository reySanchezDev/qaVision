import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Servicio encargado de realizar capturas de pantalla (§2.0).
class CaptureService {
  /// Crea una instancia de [CaptureService].
  CaptureService({
    required FileSystemService fileSystemService,
    required NativeScreenCaptureService nativeCaptureService,
  }) : _fileSystem = fileSystemService,
       _nativeCapture = nativeCaptureService;

  final FileSystemService _fileSystem;
  final NativeScreenCaptureService _nativeCapture;

  /// Realiza una captura y la guarda como JPG en la carpeta del proyecto.
  Future<String?> captureAndSave({
    required ProjectEntity project,
    Rect? captureRect,
  }) async {
    try {
      // 1) Captura nativa directa a JPG (sin PNG intermedio)
      // para mantener la maxima calidad.
      final imageBytes = await _nativeCapture.capturePngBytes(
        region: captureRect,
        quality: kAppDefaults.jpgQualityValue,
      );

      // 2) Generar nombre de archivo
      final projectDir = project.folderPath.trim();
      if (projectDir.isEmpty) {
        throw Exception('Proyecto sin carpeta valida para guardar');
      }
      final fileName = kAppDefaults.fileNameMask.isEmpty
          ? _fileSystem.generateDefaultFileName()
          : _fileSystem.generateFileName(
              mask: kAppDefaults.fileNameMask,
              projectName: project.name,
              projectDir: projectDir,
            );

      final outputPath = '$projectDir/$fileName';
      await _fileSystem.createDirectory(projectDir);

      // 3) Guardar los bytes JPG directamente (sin re-codificación)
      final savedPath = await _fileSystem.saveRawJpgBytes(
        imageBytes: imageBytes,
        outputPath: outputPath,
      );

      final savedFile = io.File(savedPath);
      if (!savedFile.existsSync() || savedFile.lengthSync() == 0) {
        throw Exception('No se guardo la captura en disco');
      }

      return savedPath;
    } on Exception catch (e) {
      debugPrint('Error en CaptureService: $e');
      return null;
    }
  }
}
