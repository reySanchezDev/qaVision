import 'package:equatable/equatable.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Eventos del BLoC de Captura (§4.0).
sealed class CaptureEvent extends Equatable {
  /// Crea una instancia de [CaptureEvent].
  const CaptureEvent();

  @override
  List<Object?> get props => [];
}

/// Solicita realizar una captura de pantalla.
final class CaptureRequested extends CaptureEvent {
  /// Crea una instancia de [CaptureRequested].
  const CaptureRequested({
    required this.project,
    this.captureRegion = false,
  });

  /// Proyecto al que se asignará la captura.
  final ProjectEntity project;

  /// Si se debe capturar una región específica (§2.0).
  final bool captureRegion;

  @override
  List<Object?> get props => [project, captureRegion];
}

/// Notifica que la captura se completó con éxito.
final class CaptureCompleted extends CaptureEvent {
  /// Crea una instancia de [CaptureCompleted].
  const CaptureCompleted(this.capture);

  /// La entidad de la captura realizada.
  final CaptureEntity capture;

  @override
  List<Object?> get props => [capture];
}

/// Notifica un error durante el proceso de captura.
final class CaptureFailed extends CaptureEvent {
  /// Crea una instancia de [CaptureFailed].
  const CaptureFailed(this.message);

  /// Mensaje descriptivo del error.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Resetea el estado del BLoC a Idle.
final class CaptureResetRequested extends CaptureEvent {
  /// Crea una instancia de [CaptureResetRequested].
  const CaptureResetRequested();
}
