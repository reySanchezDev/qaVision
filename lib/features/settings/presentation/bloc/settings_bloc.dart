import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_state.dart';

/// BLoC para la gestion de configuracion del sistema.
///
/// Maneja carga, actualizacion y persistencia de ajustes.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// Crea una instancia de [SettingsBloc].
  SettingsBloc({
    required ISettingsRepository repository,
    Stream<void>? externalChanges,
  }) : _repository = repository,
       super(const SettingsInitial()) {
    on<SettingsLoaded>(_onLoaded);
    on<SettingsStorageSynced>(_onStorageSynced);
    on<SettingsUpdated>(_onUpdated);
    on<SettingsRootFolderSelected>(_onRootFolderSelected);
    on<SettingsPositionUpdated>(_onPositionUpdated);

    if (externalChanges != null) {
      _externalChangesSubscription = externalChanges.listen((_) {
        add(const SettingsStorageSynced());
      });
    }
  }

  final ISettingsRepository _repository;
  StreamSubscription<void>? _externalChangesSubscription;

  @override
  Future<void> close() async {
    await _externalChangesSubscription?.cancel();
    return super.close();
  }

  Future<void> _onPositionUpdated(
    SettingsPositionUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoadSuccess) {
      return;
    }

    try {
      // Leer siempre el estado mas reciente en disco para no sobreescribir
      // otros cambios (ej. post-captura) desde otra ventana/proceso.
      final latest = await _repository.loadSettings();
      final dxDiff = (latest.lastX - event.position.dx).abs();
      final dyDiff = (latest.lastY - event.position.dy).abs();
      if (dxDiff < 0.5 && dyDiff < 0.5) {
        return;
      }

      final updated = latest.copyWith(
        lastX: event.position.dx,
        lastY: event.position.dy,
      );
      await _repository.saveSettings(updated);
      emit(SettingsLoadSuccess(updated));
    } on Exception catch (e) {
      // Silent fail to avoid interrupting drag UX.
      debugPrint('QAVision: Error guardando posicion: $e');
    }
  }

  Future<void> _onStorageSynced(
    SettingsStorageSynced event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      final settings = await _repository.loadSettings();
      final currentState = state;
      if (currentState is SettingsLoadSuccess &&
          currentState.settings == settings) {
        return;
      }
      emit(SettingsLoadSuccess(settings));
    } on Exception catch (e) {
      if (state is! SettingsLoadSuccess) {
        emit(SettingsError('Error al sincronizar configuracion: $e'));
      }
    }
  }

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    try {
      final settings = await _repository.loadSettings();
      emit(SettingsLoadSuccess(settings));
    } on Exception catch (e) {
      emit(SettingsError('Error al cargar configuracion: $e', exception: e));
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
      emit(SettingsError('Error al guardar configuracion: $e', exception: e));
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
        emit(SettingsError('Error al guardar carpeta raiz: $e', exception: e));
      }
    }
  }
}
