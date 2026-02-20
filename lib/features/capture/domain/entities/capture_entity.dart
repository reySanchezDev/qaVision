import 'package:equatable/equatable.dart';

/// Representa una captura de pantalla guardada en el sistema (§4.0).
class CaptureEntity extends Equatable {
  /// Crea una instancia de [CaptureEntity].
  const CaptureEntity({
    required this.id,
    required this.path,
    required this.timestamp,
    required this.projectName,
  });

  /// Identificador único de la captura.
  final String id;

  /// Ruta completa del archivo en disco.
  final String path;

  /// Fecha y hora en la que se realizó la captura.
  final DateTime timestamp;

  /// Nombre del proyecto al que pertenece la captura.
  final String projectName;

  @override
  List<Object?> get props => [id, path, timestamp, projectName];
}
