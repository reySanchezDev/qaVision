import 'dart:async';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';

/// Servicio encargado de gestionar los atajos de teclado globales.
class CaptureHotkeyService {
  /// Crea una instancia del [CaptureHotkeyService].
  CaptureHotkeyService({
    required CaptureBloc captureBloc,
    required ProjectBloc projectBloc,
  }) : _captureBloc = captureBloc,
       _projectBloc = projectBloc;

  final CaptureBloc _captureBloc;
  final ProjectBloc _projectBloc;

  /// Limpia cualquier registro previo de hotkeys.
  /// El registro activo se realiza a través de [enableHotkeys]
  /// después del arranque de la aplicación.
  Future<void> init() async {
    try {
      await hotKeyManager.unregisterAll();
    } on Exception {
      // Ignorar fallos en limpieza inicial
    }
  }

  /// Registra los atajos de teclado globales.
  /// Debe llamarse una vez que la ventana principal esté estable.
  /// Implementa un retraso extendido (§12.1) para evitar crash
  /// nativo 0xc0000409.
  /// Se ha eliminado F12 por riesgo de reserva de sistema.
  Future<void> enableHotkeys() async {
    // Retraso extendido para asegurar estabilidad completa del motor nativo.
    await Future<void>.delayed(const Duration(milliseconds: 2000));

    try {
      // Asegurar limpieza antes de registrar bajo nueva política.
      await hotKeyManager.unregisterAll();

      // Hotkey para captura de pantalla completa (Ctrl + Alt + C)
      try {
        await hotKeyManager.register(
          HotKey(
            key: LogicalKeyboardKey.keyC,
            modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
          ),
          keyDownHandler: (hotKey) => _onCaptureGlobal(),
        );
      } on Exception {
        // Fallo silencioso en registro individual
      }

      // Hotkey para captura de región (Ctrl + Alt + R)
      try {
        await hotKeyManager.register(
          HotKey(
            key: LogicalKeyboardKey.keyR,
            modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
          ),
          keyDownHandler: (hotKey) => _onCaptureRegion(),
        );
      } on Exception {
        // Fallo silencioso en registro individual
      }
    } on Exception {
      // Ignorar fallos de bloque de registro
    }
  }

  /// Desregistra todos los atajos.
  Future<void> disableHotkeys() async {
    await hotKeyManager.unregisterAll();
  }

  void _onCaptureGlobal() {
    final project = _projectBloc.state.activeProject;
    if (project != null) {
      _captureBloc.add(CaptureRequested(project: project));
    }
  }

  void _onCaptureRegion() {
    final project = _projectBloc.state.activeProject;
    if (project != null) {
      _captureBloc.add(CaptureRequested(project: project));
    }
  }
}
