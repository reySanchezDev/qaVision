import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';

/// Servicio encargado de gestionar los atajos de teclado globales.
class HotkeyService {
  /// Crea una instancia del [HotkeyService].
  HotkeyService({
    required CaptureBloc captureBloc,
    required ProjectBloc projectBloc,
  }) : _captureBloc = captureBloc,
       _projectBloc = projectBloc;

  final CaptureBloc _captureBloc;
  final ProjectBloc _projectBloc;

  /// Inicializa el gestor de hotkeys.
  Future<void> init() async {
    await hotKeyManager.unregisterAll();

    await hotKeyManager.register(
      HotKey(
        key: LogicalKeyboardKey.printScreen,
      ),
      keyDownHandler: (hotKey) => _onCaptureGlobal(),
    );

    await hotKeyManager.register(
      HotKey(
        key: LogicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      ),
      keyDownHandler: (hotKey) => _onCaptureRegion(),
    );
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
