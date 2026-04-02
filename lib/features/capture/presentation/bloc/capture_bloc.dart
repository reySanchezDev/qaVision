import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

/// BLoC encargado de orquestar el flujo de captura de pantalla (§4.0).
class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  /// Crea una instancia del [CaptureBloc].
  CaptureBloc({
    required CaptureService captureService,
    required ICaptureRepository captureRepository,
    required ClipboardService clipboardService,
  }) : _captureService = captureService,
       _captureRepo = captureRepository,
       _clipboardService = clipboardService,
       super(const CaptureIdle()) {
    on<CaptureRequested>(_onCaptureRequested);
    on<CaptureResetRequested>(_onResetRequested);
  }

  final CaptureService _captureService;
  final ICaptureRepository _captureRepo;
  final ClipboardService _clipboardService;
  final _uuid = const Uuid();
  bool _captureInProgress = false;

  Future<void> _onCaptureRequested(
    CaptureRequested event,
    Emitter<CaptureState> emit,
  ) async {
    if (_captureInProgress) {
      return;
    }
    _captureInProgress = true;
    emit(const CaptureInProgress());

    var windowWasVisible = false;
    try {
      windowWasVisible = await _safeIsWindowVisible();
      if (windowWasVisible) {
        await _safeHideWindow();
        // Dar margen a que la ventana frameless salga del frame.
        await Future<void>.delayed(const Duration(milliseconds: 140));
      } else if (event.windowAlreadyHidden) {
        // Si ya estaba oculta por el selector de region, esperar
        // estabilizacion.
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      final savedPath = await _captureService.captureAndSave(
        project: event.project,
        captureRect: event.captureRect,
      );

      if (savedPath != null) {
        final capture = CaptureEntity(
          id: _uuid.v4(),
          path: savedPath,
          timestamp: DateTime.now(),
          projectName: event.project.name,
        );

        await _captureRepo.saveCapture(capture);

        // Copiar al portapapeles si está activo (§4.7)
        if (kAppDefaults.copyToClipboard) {
          await _clipboardService.copyImageFileToClipboard(savedPath);
        }

        // Emitir estado específico según PostCaptureAction (§4.6)
        final successState = event.forceSilent
            ? CaptureSuccessSilent(capture)
            : switch (kAppDefaults.postCaptureAction) {
                PostCaptureAction.saveAndOpenViewer => CaptureSuccessViewer(
                  capture,
                ),
                PostCaptureAction.saveAndShowThumbnail =>
                  CaptureSuccessThumbnail(capture),
                PostCaptureAction.saveSilent => CaptureSuccessSilent(capture),
              };

        emit(successState);
      } else {
        emit(const CaptureIdle());
      }
    } on Exception catch (e) {
      emit(CaptureError('Error al realizar la captura: $e'));
    } finally {
      if (event.restoreFloatingWindow &&
          (windowWasVisible || event.windowAlreadyHidden)) {
        await _safeShowWindow();
      }
      _captureInProgress = false;
    }
  }

  void _onResetRequested(
    CaptureResetRequested event,
    Emitter<CaptureState> emit,
  ) {
    emit(const CaptureIdle());
  }

  Future<bool> _safeIsWindowVisible() async {
    try {
      return await windowManager.isVisible();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _safeHideWindow() async {
    try {
      await windowManager.hide();
    } on MissingPluginException {
      // En tests no hay plugin de desktop.
    } on PlatformException {
      // Ignorar errores no críticos de integración nativa.
    }
  }

  Future<void> _safeShowWindow() async {
    try {
      await windowManager.show();
    } on MissingPluginException {
      // En tests no hay plugin de desktop.
    } on PlatformException {
      // Ignorar errores no críticos de integración nativa.
    }
  }
}
