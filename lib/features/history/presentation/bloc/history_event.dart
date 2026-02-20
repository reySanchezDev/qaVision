import 'package:equatable/equatable.dart';

/// Eventos del BLoC de Historial.
sealed class HistoryEvent extends Equatable {
  /// Constructor base.
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Solicita la carga inicial del historial.
final class HistoryStarted extends HistoryEvent {
  /// Crea una instancia de [HistoryStarted].
  const HistoryStarted();
}

/// Cambia el filtro de proyecto activo.
final class HistoryFilterChanged extends HistoryEvent {
  /// Crea una instancia de [HistoryFilterChanged].
  const HistoryFilterChanged({this.projectPath});

  /// Ruta del proyecto (o nombre) por el cual filtrar.
  final String? projectPath;

  @override
  List<Object?> get props => [projectPath];
}

/// Elimina una captura del historial.
final class HistoryItemDeleted extends HistoryEvent {
  /// Crea una instancia de [HistoryItemDeleted].
  const HistoryItemDeleted({required this.capturePath});

  /// Ruta de la captura a eliminar.
  final String capturePath;

  @override
  List<Object?> get props => [capturePath];
}
