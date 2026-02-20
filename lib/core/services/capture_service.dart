import 'package:flutter/foundation.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:screen_capturer/screen_capturer.dart';

/// Servicio encargado de realizar capturas de pantalla (§2.0).
///
/// Coordina la captura nativa, el procesamiento de la imagen
/// y el guardado con las reglas de nomenclatura configuradas.
class CaptureService {
  /// Crea una instancia de [CaptureService].
  CaptureService({
    required FileSystemService fileSystemService,
  }) : _fileSystem = fileSystemService;

  final FileSystemService _fileSystem;

  /// Realiza una captura de pantalla y la guarda (§2.1).
  ///
  /// El [project] determina la carpeta de destino.
  /// Los [settings] determinan la calidad JPG y la máscara de nombre.
  Future<String?> captureAndSave({
    required ProjectEntity project,
    required SettingsEntity settings,
    bool captureRegion = false,
  }) async {
    try {
      // 1. Capturar pantalla o región (§2.0)
      final capturedData = await screenCapturer.capture(
        mode: captureRegion ? CaptureMode.region : CaptureMode.screen,
      );

      if (capturedData == null) return null;

      // 2. Leer bytes de la captura
      if (capturedData.imagePath == null) return null;

      final imageBytes = await _fileSystem.readFileAsBytes(
        capturedData.imagePath!,
      );

      // 3. Generar nombre de archivo basado en máscara (§2.1)
      final fileName = settings.fileNameMask.isEmpty
          ? _fileSystem.generateDefaultFileName()
          : _fileSystem.generateFileName(
              mask: settings.fileNameMask,
              projectName: project.name,
              projectDir: '${settings.rootFolder}/${project.name}',
            );

      final outputPath = '${settings.rootFolder}/${project.name}/$fileName';

      // 4. Guardar como JPG en isolate (§12.2)
      final savedPath = await _fileSystem.saveAsJpg(
        imageBytes: imageBytes,
        outputPath: outputPath,
        quality: settings.jpgQualityValue,
      );

      // Limpiar archivo temporal si existe
      await _fileSystem.deleteFile(capturedData.imagePath!);

      return savedPath;
    } on Exception catch (e) {
      debugPrint('Error en CaptureService: $e');
      return null;
    }
  }
}
