import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:uuid/uuid.dart';

/// BLoC encargado de orquestar el flujo de captura de pantalla (§4.0).
class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  /// Crea una instancia del [CaptureBloc].
  CaptureBloc({
    required CaptureService captureService,
    required ISettingsRepository settingsRepository,
    required ICaptureRepository captureRepository,
  }) : _captureService = captureService,
       _settingsRepo = settingsRepository,
       _captureRepo = captureRepository,
       super(const CaptureIdle()) {
    on<CaptureRequested>(_onCaptureRequested);
    on<CaptureResetRequested>(_onResetRequested);
  }

  final CaptureService _captureService;
  final ISettingsRepository _settingsRepo;
  final ICaptureRepository _captureRepo;
  final _uuid = const Uuid();

  Future<void> _onCaptureRequested(
    CaptureRequested event,
    Emitter<CaptureState> emit,
  ) async {
    emit(const CaptureInProgress());

    try {
      final settings = await _settingsRepo.loadSettings();

      final savedPath = await _captureService.captureAndSave(
        project: event.project,
        settings: settings,
        captureRegion: event.captureRegion,
      );

      if (savedPath != null) {
        final capture = CaptureEntity(
          id: _uuid.v4(),
          path: savedPath,
          timestamp: DateTime.now(),
          projectName: event.project.name,
        );

        await _captureRepo.saveCapture(capture);
        emit(CaptureSuccess(capture));
      } else {
        emit(const CaptureIdle()); // El usuario canceló o falló silenciosamente
      }
    } on Exception catch (e) {
      emit(CaptureError('Error al realizar la captura: $e'));
    }
  }

  void _onResetRequested(
    CaptureResetRequested event,
    Emitter<CaptureState> emit,
  ) {
    emit(const CaptureIdle());
  }
}
