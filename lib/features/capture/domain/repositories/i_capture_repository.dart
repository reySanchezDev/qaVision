import 'package:qavision/features/capture/domain/entities/capture_entity.dart';

/// Interfaz para la gestión del historial de capturas (§4.0).
abstract class ICaptureRepository {
  /// Guarda una nueva captura en el historial local.
  Future<void> saveCapture(CaptureEntity capture);

  /// Obtiene la lista de capturas recientes.
  Future<List<CaptureEntity>> getRecentCaptures({int limit = 10});

  /// Obtiene todo el historial de capturas.
  Future<List<CaptureEntity>> getHistory();

  /// Elimina una captura por su [id].
  Future<void> deleteCapture(String id);
}
