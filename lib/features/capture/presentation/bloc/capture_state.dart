import 'package:equatable/equatable.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';

/// Estados del BLoC de Captura (§4.0).
sealed class CaptureState extends Equatable {
  /// Crea una instancia de [CaptureState].
  const CaptureState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial, esperando acción.
final class CaptureIdle extends CaptureState {
  /// Crea una instancia de [CaptureIdle].
  const CaptureIdle();
}

/// Proceso de captura en curso.
final class CaptureInProgress extends CaptureState {
  /// Crea una instancia de [CaptureInProgress].
  const CaptureInProgress();
}

/// Captura finalizada con éxito.
sealed class CaptureSuccess extends CaptureState {
  /// Crea una instancia de [CaptureSuccess].
  const CaptureSuccess(this.capture);

  /// La entidad de la captura realizada.
  final CaptureEntity capture;

  @override
  List<Object?> get props => [capture];
}

/// Éxito de captura que abre el visor.
final class CaptureSuccessViewer extends CaptureSuccess {
  /// Crea una instancia de [CaptureSuccessViewer].
  const CaptureSuccessViewer(super.capture);
}

/// Éxito de captura que muestra miniatura.
final class CaptureSuccessThumbnail extends CaptureSuccess {
  /// Crea una instancia de [CaptureSuccessThumbnail].
  const CaptureSuccessThumbnail(super.capture);
}

/// Éxito de captura silencioso.
final class CaptureSuccessSilent extends CaptureSuccess {
  /// Crea una instancia de [CaptureSuccessSilent].
  const CaptureSuccessSilent(super.capture);
}

/// Error en el proceso de captura.
final class CaptureError extends CaptureState {
  /// Crea una instancia de [CaptureError].
  const CaptureError(this.message);

  /// Mensaje del error.
  final String message;

  @override
  List<Object?> get props => [message];
}
