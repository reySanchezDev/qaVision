import 'package:equatable/equatable.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';

/// Estados del BLoC de Historial.
sealed class HistoryState extends Equatable {
  /// Crea una instancia de [HistoryState].
  const HistoryState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial del historial.
final class HistoryInitial extends HistoryState {
  /// Crea una instancia de [HistoryInitial].
  const HistoryInitial();
}

/// Estado mientras se cargan las capturas.
final class HistoryLoading extends HistoryState {
  /// Crea una instancia de [HistoryLoading].
  const HistoryLoading();
}

/// Estado tras cargar exitosamente las capturas.
final class HistoryLoadSuccess extends HistoryState {
  /// Crea una instancia de [HistoryLoadSuccess].
  const HistoryLoadSuccess({
    required this.captures,
    this.projectFilter,
  });

  /// Lista de entidades de capturas.
  final List<CaptureEntity> captures;

  /// Filtro de proyecto activo (opcional).
  final String? projectFilter;

  @override
  List<Object?> get props => [captures, projectFilter];
}

/// Estado en caso de error en la carga.
final class HistoryError extends HistoryState {
  /// Crea una instancia de [HistoryError].
  const HistoryError(this.message);

  /// Mensaje del error.
  final String message;

  @override
  List<Object?> get props => [message];
}
