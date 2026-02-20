import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_state.dart';

/// BLoC para la gestión de configuración del sistema.
///
/// Maneja la carga, actualización y persistencia de los
/// ajustes de la pantalla de Configuración General (§4).
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// Crea una instancia de [SettingsBloc].
  SettingsBloc({required ISettingsRepository repository})
    : _repository = repository,
      super(const SettingsInitial()) {
    on<SettingsLoaded>(_onLoaded);
    on<SettingsUpdated>(_onUpdated);
    on<SettingsRootFolderSelected>(_onRootFolderSelected);
  }

  final ISettingsRepository _repository;

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    try {
      final settings = await _repository.loadSettings();
      emit(SettingsLoadSuccess(settings));
    } on Exception catch (e) {
      emit(SettingsError('Error al cargar configuración: $e', exception: e));
    }
  }

  Future<void> _onUpdated(
    SettingsUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repository.saveSettings(event.settings);
      emit(SettingsLoadSuccess(event.settings));
    } on Exception catch (e) {
      emit(SettingsError('Error al guardar configuración: $e', exception: e));
    }
  }

  Future<void> _onRootFolderSelected(
    SettingsRootFolderSelected event,
    Emitter<SettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      final updated = currentState.settings.copyWith(rootFolder: event.path);
      try {
        await _repository.saveSettings(updated);
        emit(SettingsLoadSuccess(updated));
      } on Exception catch (e) {
        emit(
          SettingsError('Error al guardar carpeta raíz: $e', exception: e),
        );
      }
    }
  }
}
