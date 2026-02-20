import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/history/presentation/bloc/history_event.dart';
import 'package:qavision/features/history/presentation/bloc/history_state.dart';

/// BLoC para gestionar el historial global de capturas (§12.0).
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  /// Crea una instancia de [HistoryBloc].
  HistoryBloc({required ICaptureRepository repository})
    : _repository = repository,
      super(const HistoryInitial()) {
    on<HistoryStarted>(_onStarted);
    on<HistoryFilterChanged>(_onFilterChanged);
    on<HistoryItemDeleted>(_onItemDeleted);
  }

  final ICaptureRepository _repository;

  Future<void> _onStarted(
    HistoryStarted event,
    Emitter<HistoryState> emit,
  ) async {
    emit(const HistoryLoading());
    try {
      final history = await _repository.getHistory();
      emit(HistoryLoadSuccess(captures: history));
    } on Exception catch (e) {
      emit(HistoryError('Error al cargar historial: $e'));
    }
  }

  Future<void> _onFilterChanged(
    HistoryFilterChanged event,
    Emitter<HistoryState> emit,
  ) async {
    final currentState = state;
    if (currentState is HistoryLoadSuccess) {
      emit(const HistoryLoading());
      try {
        final history = await _repository.getHistory();
        var filteredHistory = history;

        if (event.projectPath != null) {
          // Filtrar por nombre de proyecto o ruta
          // El path suele contener el nombre del proyecto en este flujo (§12.0)
          filteredHistory = history
              .where(
                (p) =>
                    p.projectName == event.projectPath ||
                    p.path.contains(event.projectPath!),
              )
              .toList();
        }

        emit(
          HistoryLoadSuccess(
            captures: filteredHistory,
            projectFilter: event.projectPath,
          ),
        );
      } on Exception catch (e) {
        emit(HistoryError('Error al filtrar historial: $e'));
      }
    }
  }

  Future<void> _onItemDeleted(
    HistoryItemDeleted event,
    Emitter<HistoryState> emit,
  ) async {
    final currentState = state;
    if (currentState is HistoryLoadSuccess) {
      try {
        // Encontrar el ID de la captura por su path para el repositorio
        final item = currentState.captures.firstWhere(
          (e) => e.path == event.capturePath,
        );
        await _repository.deleteCapture(item.id);

        final updatedCaptures = List<CaptureEntity>.from(currentState.captures)
          ..removeWhere((e) => e.path == event.capturePath);

        emit(
          HistoryLoadSuccess(
            captures: updatedCaptures,
            projectFilter: currentState.projectFilter,
          ),
        );
      } on Exception catch (e) {
        emit(HistoryError('Error al eliminar captura: $e'));
      }
    }
  }
}
