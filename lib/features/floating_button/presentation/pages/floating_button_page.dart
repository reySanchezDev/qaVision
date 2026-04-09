import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/services/video_recording_service.dart';
import 'package:qavision/core/services/video_recording_runtime_service.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/core/widgets/app_text_field.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/floating_button/presentation/utils/virtual_desktop_overlay_metrics.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/video/domain/entities/video_recording_target.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';

const double _kControlButtonSize = kFloatingControlButtonSize;
const double _kCaptureButtonSize = kFloatingCaptureButtonSize;
const double _kControlGap = kFloatingControlGap;
const double _kControlIconSize = kFloatingControlIconSize;

enum _ClipPointerAction { capture, stop }

class _MouseButtonState {
  const _MouseButtonState({
    required this.isDown,
    required this.wasPressed,
  });

  final bool isDown;
  final bool wasPressed;
}

/// Cuerpo principal de la pantalla flotante.
class FloatingButtonBody extends StatefulWidget {
  /// Crea [FloatingButtonBody].
  const FloatingButtonBody({
    this.onDragStarted,
    super.key,
  });

  /// Callback disparado al comenzar el arrastre nativo de la ventana.
  final VoidCallback? onDragStarted;

  @override
  State<FloatingButtonBody> createState() => _FloatingButtonBodyState();
}

class _FloatingButtonBodyState extends State<FloatingButtonBody> {
  bool _clipLoopRunning = false;
  bool _folderPickerOpen = false;
  bool _isSystemClosing = false;
  bool _showClipNamingTransition = false;
  _ClipNamingSequence? _clipNamingSequence;
  Completer<_RegionSelectionDialogResult?>? _regionSelectionCompleter;
  Completer<_VideoTargetChoice?>? _videoTargetCompleter;
  Rect? _pendingVideoTargetAnchorBounds;
  int? _videoCountdownValue;
  String? _videoCountdownLabel;
  bool _isVideoBusy = false;
  VideoRecordingRuntimeService get _videoRuntime =>
      sl<VideoRecordingRuntimeService>();

  bool get _isVideoRecording => _videoRuntime.isRecording;

  @override
  void dispose() {
    if (!(_regionSelectionCompleter?.isCompleted ?? true)) {
      _regionSelectionCompleter?.complete(null);
    }
    if (!(_videoTargetCompleter?.isCompleted ?? true)) {
      _videoTargetCompleter?.complete(null);
    }
    super.dispose();
  }

  Future<void> _runClipSession() async {
    if (_clipLoopRunning) return;

    final floatingBloc = context.read<FloatingButtonBloc>();
    final captureBloc = context.read<CaptureBloc>();
    if (!Platform.isWindows) {
      return;
    }

    _clipLoopRunning = true;
    _clipNamingSequence = null;
    floatingBloc.add(const FloatingButtonClipSessionStarted());
    var clipWindowHidden = false;
    var shouldShowClipFinishedDialog = false;
    try {
      final initialState = floatingBloc.state;
      final clipSelection = await _requestRegionCaptureRect(initialState);
      if (!mounted || clipSelection == null) {
        return;
      }
      if (clipSelection.cancelledByRightClick ||
          clipSelection.captureRect == null) {
        return;
      }

      clipWindowHidden = clipSelection.windowAlreadyHidden;
      if (!clipWindowHidden) {
        clipWindowHidden = await _hideWindowForClipSession();
      }
      await _waitUntilMouseReleased();

      while (mounted) {
        final currentState = floatingBloc.state;
        if (currentState.captureMode != FloatingCaptureMode.clip) {
          break;
        }
        if (!currentState.isClipSessionActive) {
          break;
        }

        _ClipCaptureNamingDecision? pendingDecision;
        String? requestedName;
        if (_clipNamingSequence != null) {
          requestedName = _clipNamingSequence?.consumeCurrentName();
        } else {
          pendingDecision = await _requestClipCaptureNaming(currentState);
          if (!mounted || pendingDecision == null) {
            floatingBloc.add(const FloatingButtonClipSessionStopped());
            break;
          }
          final explicitName = pendingDecision.fileName.trim();
          if (explicitName.isNotEmpty) {
            requestedName = explicitName;
          }
          await _prepareForClipPointerCapture();
        }

        final action = await _waitForClipPointerAction(floatingBloc);
        if (!mounted || action == null) break;

        if (action == _ClipPointerAction.stop) {
          shouldShowClipFinishedDialog = true;
          await _dismissWindowsContextMenuAfterClipStop();
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }

        captureBloc.add(const CaptureResetRequested());
        floatingBloc.add(
          FloatingButtonCaptureRequested(
            captureRect: clipSelection.captureRect,
            fileNameOverride: requestedName,
            windowAlreadyHidden: true,
            restoreFloatingWindow: false,
          ),
        );

        final captureResult = await _waitForClipCaptureResult(floatingBloc);
        if (!mounted || captureResult == null) {
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }

        if (captureResult is CaptureError) {
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }
        if (captureResult is! CaptureSuccess) {
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }

        if (pendingDecision?.applyToRemaining ?? false) {
          _clipNamingSequence = _ClipNamingSequence.fromBaseAndSeed(
            baseName: pendingDecision!.baseName,
            initialToken: pendingDecision.effectiveSequenceSeed,
          );
        }

        await _waitUntilMouseReleased();
      }
    } finally {
      _clipNamingSequence = null;
      _clipLoopRunning = false;
      if (mounted && floatingBloc.state.isClipSessionActive) {
        floatingBloc.add(const FloatingButtonClipSessionStopped());
      }
      if (clipWindowHidden && mounted) {
        final isVisible = await windowManager.isVisible();
        if (!isVisible) {
          await windowManager.show(inactive: true);
        }
      }
      if (shouldShowClipFinishedDialog && mounted) {
        await _showClipSessionFinishedDialog(floatingBloc.state);
      }
    }
  }

  Future<bool> _hideWindowForClipSession() async {
    final isVisible = await windowManager.isVisible();
    if (!isVisible) return false;

    await windowManager.hide();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return true;
  }

  Future<void> _waitUntilMouseReleased() async {
    if (!Platform.isWindows) return;

    for (var i = 0; i < 200; i++) {
      if (!_isMouseButtonDown(VK_LBUTTON) && !_isMouseButtonDown(VK_RBUTTON)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }

  Future<_ClipPointerAction?> _waitForClipPointerAction(
    FloatingButtonBloc floatingBloc,
  ) async {
    if (!Platform.isWindows) {
      return _ClipPointerAction.stop;
    }

    var previousLeftDown = _isMouseButtonDown(VK_LBUTTON);
    var previousRightDown = _isMouseButtonDown(VK_RBUTTON);
    var leftPressInProgress = false;

    while (mounted) {
      final state = floatingBloc.state;
      if (state.captureMode != FloatingCaptureMode.clip ||
          !state.isClipSessionActive) {
        return _ClipPointerAction.stop;
      }

      final rightState = _mouseButtonState(VK_RBUTTON);
      final leftState = _mouseButtonState(VK_LBUTTON);
      final rightDown = rightState.isDown;
      final leftDown = leftState.isDown;

      if ((rightDown && !previousRightDown) || rightState.wasPressed) {
        return _ClipPointerAction.stop;
      }

      if ((leftDown && !previousLeftDown) || leftState.wasPressed) {
        leftPressInProgress = true;
      }

      if (leftPressInProgress && !leftDown) {
        await Future<void>.delayed(const Duration(milliseconds: 55));
        return _ClipPointerAction.capture;
      }

      previousRightDown = rightDown;
      previousLeftDown = leftDown;
      await Future<void>.delayed(const Duration(milliseconds: 6));
    }

    return null;
  }

  bool _isMouseButtonDown(int virtualKeyCode) {
    return (GetAsyncKeyState(virtualKeyCode) & 0x8000) != 0;
  }

  _MouseButtonState _mouseButtonState(int virtualKeyCode) {
    final state = GetAsyncKeyState(virtualKeyCode);
    return _MouseButtonState(
      isDown: (state & 0x8000) != 0,
      wasPressed: (state & 0x0001) != 0,
    );
  }

  Future<CaptureState?> _waitForClipCaptureResult(
    FloatingButtonBloc floatingBloc,
  ) async {
    if (!Platform.isWindows) {
      return const CaptureIdle();
    }

    final captureBloc = context.read<CaptureBloc>();
    var previousRightDown = _isMouseButtonDown(VK_RBUTTON);
    var sawCaptureStart = false;
    final deadline = DateTime.now().add(const Duration(seconds: 12));

    while (mounted) {
      final state = floatingBloc.state;
      if (state.captureMode != FloatingCaptureMode.clip ||
          !state.isClipSessionActive) {
        return null;
      }

      final rightDown = _isMouseButtonDown(VK_RBUTTON);
      if (rightDown && !previousRightDown) {
        return null;
      }
      previousRightDown = rightDown;

      final captureState = captureBloc.state;
      if (captureState is CaptureInProgress) {
        sawCaptureStart = true;
      } else if (sawCaptureStart &&
          (captureState is CaptureSuccess || captureState is CaptureError)) {
        return captureState;
      }

      if (DateTime.now().isAfter(deadline)) {
        return captureState;
      }

      await Future<void>.delayed(const Duration(milliseconds: 14));
    }

    return null;
  }

  Future<_ClipCaptureNamingDecision?> _requestClipCaptureNaming(
    FloatingButtonState state,
  ) async {
    return _showClipNamingDialog(
      state: state,
    );
  }

  Future<void> _dismissWindowsContextMenuAfterClipStop() async {
    if (!Platform.isWindows) return;

    await _waitUntilMouseReleased();
    for (final delay in <int>[40, 120, 220]) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      EndMenu();
      final foregroundWindow = GetForegroundWindow();
      if (foregroundWindow != 0) {
        PostMessage(foregroundWindow, WM_CANCELMODE, 0, 0);
      }
    }
  }

  Future<void> _prepareForClipPointerCapture() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.blur();
        await windowManager.hide();
        await windowManager.setAlwaysOnTop(true);
      } else {
        await windowManager.blur();
      }
    } on Object {
      // Si la plataforma no responde, continuamos sin bloquear el flujo.
    }

    await Future<void>.delayed(const Duration(milliseconds: 140));
    await _waitUntilMouseReleased();
  }

  Future<void> _showClipSessionFinishedDialog(
    FloatingButtonState state,
  ) async {
    const dialogWindowSize = Size(460, 260);
    const dialogSurface = Color(0xFF11171D);
    var wasSkipTaskbar = true;

    try {
      if (mounted) {
        setState(() {
          _showClipNamingTransition = true;
        });
      }
      wasSkipTaskbar = await windowManager.isSkipTaskbar();
      await windowManager.setSkipTaskbar(false);
      await windowManager.setMinimumSize(dialogWindowSize);
      await windowManager.setMaximumSize(dialogWindowSize);
      await windowManager.setSize(dialogWindowSize);
      await windowManager.setBackgroundColor(dialogSurface);
      await windowManager.setHasShadow(true);
      await windowManager.center();
      await windowManager.show(inactive: true);
      await windowManager.setAlwaysOnTop(true);
    } on Object {
      // Si alguna API nativa falla, el dialogo aun puede abrir.
    }

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Fin captura clip',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return const _ClipSessionFinishedDialog();
        },
        transitionBuilder:
            (dialogContext, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.98,
                    end: 1,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
      );
    } finally {
      try {
        await windowManager.setMinimumSize(state.windowSize);
        await windowManager.setMaximumSize(state.windowSize);
        await windowManager.setSize(state.windowSize);
        await windowManager.setPosition(state.position);
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setHasShadow(false);
        await windowManager.setSkipTaskbar(wasSkipTaskbar);
        await windowManager.show(inactive: true);
        await windowManager.setAlwaysOnTop(true);
      } on Object {
        // Evitamos romper la restauracion de la flotante.
      } finally {
        if (mounted) {
          setState(() {
            _showClipNamingTransition = false;
          });
        }
      }
    }
  }

  Future<void> _handleCaptureTap(FloatingButtonState state) async {
    if (_isVideoBusy) {
      return;
    }

    final floatingBloc = context.read<FloatingButtonBloc>();
    final effectiveState = await _ensureEffectiveCaptureState(state);
    if (!mounted || effectiveState == null) return;

    switch (effectiveState.captureMode) {
      case FloatingCaptureMode.screen:
        floatingBloc.add(const FloatingButtonCaptureRequested());
        return;
      case FloatingCaptureMode.region:
        final selection = await _requestRegionCaptureRect(effectiveState);
        final selectedRect = selection?.captureRect;
        if (!mounted || selectedRect == null) return;
        floatingBloc.add(
          FloatingButtonCaptureRequested(
            captureRect: selectedRect,
            windowAlreadyHidden: selection?.windowAlreadyHidden ?? false,
          ),
        );
        return;
      case FloatingCaptureMode.clip:
        await _runClipSession();
        return;
      case FloatingCaptureMode.video:
        if (_isVideoRecording) {
          await _stopVideoRecording();
          return;
        }
        await _startVideoCaptureFlow(effectiveState);
        return;
    }
  }

  Future<void> _handleSystemCloseTap() async {
    if (_isSystemClosing) {
      return;
    }

    setState(() {
      _isSystemClosing = true;
    });

    try {
      await AppRouter.closeSystem();
    } finally {
      if (mounted) {
        setState(() {
          _isSystemClosing = false;
        });
      }
    }
  }

  Future<FloatingButtonState?> _ensureEffectiveCaptureState(
    FloatingButtonState state,
  ) async {
    var effectiveState = state;

    final hasAnyProject = effectiveState.projects.isNotEmpty;
    if (!hasAnyProject) {
      final selected = await _pickFolderForSlot(0);
      if (!mounted || !selected) return null;
      effectiveState = context.read<FloatingButtonBloc>().state;
      if (effectiveState.projects.isEmpty) return null;
    }

    if (effectiveState.activeProject == null &&
        effectiveState.projects.isNotEmpty) {
      if (!mounted) return null;
      context.read<FloatingButtonBloc>().add(
        FloatingButtonProjectChanged(effectiveState.projects.first),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return null;
      effectiveState = context.read<FloatingButtonBloc>().state;
    }

    if (effectiveState.activeProject == null) {
      return null;
    }
    return effectiveState;
  }

  void _handleQuickSlotPrimaryTap(
    int slotIndex,
    ProjectEntity? currentProject,
  ) {
    if (currentProject == null) return;
    context.read<FloatingButtonBloc>().add(
      FloatingButtonProjectChanged(currentProject),
    );
  }

  Future<void> _handleQuickSlotSecondaryTap(int slotIndex) async {
    await _pickFolderForSlot(slotIndex);
  }

  Future<bool> _pickFolderForSlot(int slotIndex) async {
    if (_folderPickerOpen) {
      return false;
    }

    _folderPickerOpen = true;
    String? selectedPath;
    try {
      selectedPath = await _pickDirectoryPathModal();
    } finally {
      _folderPickerOpen = false;
    }
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return false;
    }

    if (!mounted) return false;
    context.read<FloatingButtonBloc>().add(
      FloatingButtonQuickSlotFolderSelected(
        slotIndex: slotIndex,
        folderPath: selectedPath.trim(),
      ),
    );
    return true;
  }

  Future<String?> _pickDirectoryPathModal() async {
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setIgnoreMouseEvents(true, forward: true);
    } on Object {
      // Si alguna API no responde en cierto equipo, el selector aun puede abrir.
    }

    try {
      return await FilePicker.platform.getDirectoryPath(
        lockParentWindow: true,
      );
    } finally {
      try {
        await windowManager.setIgnoreMouseEvents(false);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.show(inactive: true);
      } on Object {
        // Evitamos romper el flujo si la restauracion visual falla.
      }
    }
  }

  Future<_ClipCaptureNamingDecision?> _showClipNamingDialog({
    required FloatingButtonState state,
  }) async {
    const dialogWindowSize = Size(560, 470);
    const dialogSurface = Color(0xFF11171D);
    var wasSkipTaskbar = true;

    try {
      if (mounted) {
        setState(() {
          _showClipNamingTransition = true;
        });
      }
      wasSkipTaskbar = await windowManager.isSkipTaskbar();
      await windowManager.setSkipTaskbar(false);
      await windowManager.setMinimumSize(dialogWindowSize);
      await windowManager.setMaximumSize(dialogWindowSize);
      await windowManager.setSize(dialogWindowSize);
      await windowManager.setBackgroundColor(dialogSurface);
      await windowManager.setHasShadow(true);
      await windowManager.center();
      await windowManager.show();
      await windowManager.setAlwaysOnTop(true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await windowManager.focus();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await windowManager.setAlwaysOnTop(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    } on Object {
      // Si alguna API nativa falla, el dialogo aun puede abrir.
    }

    try {
      return await showGeneralDialog<_ClipCaptureNamingDecision>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Nombrar captura clip',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return const _ClipCaptureNamingDialog();
        },
        transitionBuilder:
            (dialogContext, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.98,
                    end: 1,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
      );
    } finally {
      try {
        await windowManager.setMinimumSize(state.windowSize);
        await windowManager.setMaximumSize(state.windowSize);
        await windowManager.setSize(state.windowSize);
        await windowManager.setPosition(state.position);
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setHasShadow(false);
        await windowManager.setSkipTaskbar(wasSkipTaskbar);
        await windowManager.hide();
      } on Object {
        // Evitamos romper la sesion clip si la restauracion visual falla.
      } finally {
        if (mounted) {
          setState(() {
            _showClipNamingTransition = false;
          });
        }
      }
    }
  }

  Future<void> _startVideoCaptureFlow(FloatingButtonState state) async {
    if (_isVideoBusy || _isVideoRecording) {
      return;
    }
    _videoRuntime.reset();
    setState(() {
      _isVideoBusy = true;
    });

    VideoRecordingSession? startedSession;
    try {
      final targetChoice = await _requestVideoTargetSelectionOverlay(state);
      if (!mounted || targetChoice == null) {
        return;
      }

      final targetSelection = await _resolveVideoTargetSelection(
        state,
        targetChoice,
      );
      if (!mounted || targetSelection == null) {
        return;
      }

      final countdownCompleted = await _runVideoCountdown(
        state: state,
        overlayOrigin: targetSelection.overlayOrigin,
        overlaySize: targetSelection.overlaySize,
        label: targetSelection.target.label,
      );

      if (!mounted || !countdownCompleted) {
        if (mounted) {
          await _restoreVideoFloatingWindow(state.position);
        }
        return;
      }

      final hudPosition = _resolveVideoHudPosition(targetSelection);
      await _showVideoRecordingHud(
        hudPosition: hudPosition,
        returnPosition: state.position,
      );
      await sl<VideoRecordingService>().excludeFloatingWindowFromCapture();

      final session = await sl<VideoRecordingService>().startRecording(
        project: state.activeProject!,
        target: targetSelection.target,
      );
      startedSession = session;

      if (!mounted) {
        await session.stop();
        return;
      }

      _videoRuntime.begin(
        session: session,
        returnPosition: state.position,
        hudPosition: hudPosition,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      if (startedSession != null) {
        try {
          await startedSession.stop();
        } on Object {
          // Ignorar para priorizar la recuperacion visual.
        }
      }
      _videoRuntime.reset();
      await _restoreVideoFloatingWindow(state.position);

      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Fallo al iniciar captura'),
            content: SingleChildScrollView(
              child: Text(
                'No se pudo iniciar la grabación de video.\n\n'
                'Detalle:\n$e',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar la grabación: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVideoBusy = false;
        });
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isVideoRecording || _isVideoBusy) {
      return;
    }

    setState(() {
      _isVideoBusy = true;
    });

    try {
      final returnPosition =
          _videoRuntime.returnPosition ??
          context.read<FloatingButtonBloc>().state.position;
      final result = await _videoRuntime.stop();
      if (!mounted) return;
      setState(() {});

      await _restoreVideoFloatingWindow(returnPosition);

      final message = (result?.isSuccess ?? false)
          ? 'Video guardado en la carpeta activa'
          : 'La grabación no pudo guardarse correctamente';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('No se pudo detener la grabación: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVideoBusy = false;
        });
      }
    }
  }

  Future<void> _toggleVideoPause() async {
    if (!_isVideoRecording || _isVideoBusy) {
      return;
    }

    try {
      await _videoRuntime.togglePause();
      if (!mounted) return;
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar pausa: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showVideoRecordingHud({
    required Offset hudPosition,
    required Offset returnPosition,
  }) async {
    if (mounted) {
      context.read<FloatingButtonBloc>().add(
        FloatingButtonVideoRecordingStarted(position: hudPosition),
      );
    }

    await windowManager.setResizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);

    await windowManager.setMinimumSize(kFloatingVideoRecordingHudSize);
    await windowManager.setMaximumSize(kFloatingVideoRecordingHudSize);
    await windowManager.setSize(kFloatingVideoRecordingHudSize);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    await windowManager.setPosition(hudPosition);
    await windowManager.show(inactive: true);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> _restoreVideoFloatingWindow(Offset position) async {
    if (!mounted) return;
    final floatingState = context.read<FloatingButtonBloc>().state;
    await windowManager.setResizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setMinimumSize(floatingState.windowSize);
    await windowManager.setMaximumSize(floatingState.windowSize);
    await windowManager.setSize(floatingState.windowSize);
    await windowManager.setPosition(position);
    await windowManager.show(inactive: true);
    await windowManager.setAlwaysOnTop(true);
    if (mounted) {
      context.read<FloatingButtonBloc>().add(
        FloatingButtonVideoRecordingStopped(position: position),
      );
    }
    _videoRuntime.hideHud();
  }

  Offset _resolveVideoHudPosition(_VideoTargetSelection selection) {
    const topMargin = 18.0;
    const sideMargin = 12.0;
    final hudSize = kFloatingVideoRecordingHudSize;
    final overlayRect = Rect.fromLTWH(
      selection.overlayOrigin.dx,
      selection.overlayOrigin.dy,
      selection.overlaySize.width,
      selection.overlaySize.height,
    );
    final centeredLeft =
        overlayRect.left + ((overlayRect.width - hudSize.width) / 2);
    final clampedLeft = centeredLeft.clamp(
      overlayRect.left + sideMargin,
      overlayRect.right - hudSize.width - sideMargin,
    );
    final top = overlayRect.top + topMargin;
    return Offset(clampedLeft.toDouble(), top);
  }

  Future<Rect> _resolveDisplayBoundsForPosition(Offset position) async {
    final displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      final display = await screenRetriever.getPrimaryDisplay();
      return _displayBounds(display);
    }

    final nearest = displays.reduce((best, candidate) {
      final bestDistance = _distanceToRect(position, _displayBounds(best));
      final candidateDistance = _distanceToRect(
        position,
        _displayBounds(candidate),
      );
      return candidateDistance < bestDistance ? candidate : best;
    });

    return _displayBounds(nearest);
  }

  Rect _displayBounds(Display display) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  }

  double _distanceToRect(Offset point, Rect rect) {
    if (rect.contains(point)) {
      return 0;
    }

    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return (dx * dx) + (dy * dy);
  }

  Rect _resolveAnchorRectForSelection({
    required Rect selectedRect,
    required Offset overlayOrigin,
    required List<Display> displays,
  }) {
    if (displays.isEmpty) {
      return Rect.fromLTWH(
        overlayOrigin.dx,
        overlayOrigin.dy,
        selectedRect.width,
        selectedRect.height,
      );
    }

    final selectionCenter = Offset(
      overlayOrigin.dx + selectedRect.center.dx,
      overlayOrigin.dy + selectedRect.center.dy,
    );
    final nearest = displays.reduce((best, candidate) {
      final bestDistance = _distanceToRect(
        selectionCenter,
        _displayBounds(best),
      );
      final candidateDistance = _distanceToRect(
        selectionCenter,
        _displayBounds(candidate),
      );
      return candidateDistance < bestDistance ? candidate : best;
    });
    return _displayBounds(nearest);
  }

  Future<VirtualDesktopOverlayMetrics>
  _resolveVirtualDesktopOverlayMetrics() async {
    final devicePixelRatio = windowManager.getDevicePixelRatio();
    final physicalBounds = Rect.fromLTWH(
      GetSystemMetrics(SM_XVIRTUALSCREEN).toDouble(),
      GetSystemMetrics(SM_YVIRTUALSCREEN).toDouble(),
      GetSystemMetrics(SM_CXVIRTUALSCREEN).toDouble(),
      GetSystemMetrics(SM_CYVIRTUALSCREEN).toDouble(),
    );

    return buildVirtualDesktopOverlayMetrics(
      physicalBounds: physicalBounds,
      devicePixelRatio: devicePixelRatio,
    );
  }

  Future<_VideoTargetChoice?> _requestVideoTargetSelectionOverlay(
    FloatingButtonState state,
  ) async {
    final displays = await screenRetriever.getAllDisplays();
    final availableDisplays = displays.isEmpty
        ? <Display>[await screenRetriever.getPrimaryDisplay()]
        : displays;
    final overlayMetrics = await _resolveVirtualDesktopOverlayMetrics();
    final overlaySize = overlayMetrics.logicalSize;
    final overlayOrigin = overlayMetrics.logicalOrigin;
    final anchorBounds = await _resolveDisplayBoundsForPosition(state.position);
    final completer = Completer<_VideoTargetChoice?>();
    _VideoTargetChoice? selectedChoice;
    var shouldRestoreWindow = true;
    _videoTargetCompleter = completer;
    _pendingVideoDisplays = availableDisplays;
    _pendingVideoTargetAnchorBounds = anchorBounds;
    if (mounted) {
      context.read<FloatingButtonBloc>().add(
        const FloatingButtonVideoOverlayStarted(),
      );
      setState(() {});
    }

    try {
      await windowManager.setPosition(overlayOrigin);
      await windowManager.setMinimumSize(overlaySize);
      await windowManager.setMaximumSize(overlaySize);
      await windowManager.setSize(overlaySize);
      await Future<void>.delayed(const Duration(milliseconds: 16));

      final choice = await completer.future;
      selectedChoice = choice;
      if (!mounted || choice == null) {
        return null;
      }

      if (choice.kind == _VideoTargetChoiceKind.region) {
        shouldRestoreWindow = false;
      }

      return choice;
    } finally {
      _videoTargetCompleter = null;
      _pendingVideoDisplays = const <Display>[];
      _pendingVideoTargetAnchorBounds = null;
      if (mounted) {
        setState(() {});
      }
      if (shouldRestoreWindow) {
        if (mounted) {
          context.read<FloatingButtonBloc>().add(
            const FloatingButtonVideoOverlayEnded(),
          );
        }
        await windowManager.setMinimumSize(state.windowSize);
        await windowManager.setMaximumSize(state.windowSize);
        await windowManager.setSize(state.windowSize);
        await windowManager.setPosition(state.position);
      } else if (mounted && selectedChoice != null) {
        // Mantenemos el overlay a pantalla completa para que el selector
        // de region pueda usar el mismo lienzo sin volver a la flotante.
      }
    }
  }

  Future<_VideoTargetSelection?> _resolveVideoTargetSelection(
    FloatingButtonState state,
    _VideoTargetChoice choice,
  ) async {
    if (choice.kind == _VideoTargetChoiceKind.region) {
      try {
        final selection = await _requestVideoRegionCaptureRect(state);
        if (!mounted || selection?.captureRect == null) {
          await _restoreVideoOverlayWindow(state);
          return null;
        }

        return _VideoTargetSelection(
          target: VideoRecordingTarget(
            kind: VideoRecordingSourceKind.region,
            label: 'Área personalizada',
            desktopRect: selection!.captureRect!,
          ),
          overlayOrigin: selection.anchorOrigin ?? Offset.zero,
          overlaySize: selection.anchorSize ?? const Size(1200, 800),
        );
      } finally {
        if (mounted) {
          context.read<FloatingButtonBloc>().add(
            const FloatingButtonVideoOverlayEnded(),
          );
        }
      }
    }

    final display = choice.display!;
    final scaleFactor = display.scaleFactor?.toDouble() ?? 1.0;
    final logicalOrigin = display.visiblePosition ?? Offset.zero;
    final logicalSize = display.size;

    final physicalRect = Rect.fromLTWH(
      logicalOrigin.dx * scaleFactor,
      logicalOrigin.dy * scaleFactor,
      logicalSize.width * scaleFactor,
      logicalSize.height * scaleFactor,
    );

    return _VideoTargetSelection(
      target: VideoRecordingTarget(
        kind: VideoRecordingSourceKind.display,
        label: choice.label,
        desktopRect: physicalRect,
      ),
      overlayOrigin: logicalOrigin,
      overlaySize: logicalSize,
    );
  }

  Future<_RegionCaptureSelection?> _requestVideoRegionCaptureRect(
    FloatingButtonState state,
  ) async {
    final completer = Completer<_RegionSelectionDialogResult?>();
    _regionSelectionCompleter = completer;

    if (mounted) {
      context.read<FloatingButtonBloc>().add(
        const FloatingButtonRegionSelectionStarted(),
      );
    }

    final overlayMetrics = await _resolveVirtualDesktopOverlayMetrics();
    final overlaySize = overlayMetrics.logicalSize;
    final overlayOrigin = overlayMetrics.logicalOrigin;
    final displays = await screenRetriever.getAllDisplays();

    try {
      await windowManager.setPosition(overlayOrigin);
      await windowManager.setMinimumSize(overlaySize);
      await windowManager.setMaximumSize(overlaySize);
      await windowManager.setSize(overlaySize);

      final selectionResult = await completer.future;
      if (selectionResult == null) {
        return null;
      }

      if (selectionResult.cancelledByRightClick) {
        return const _RegionCaptureSelection(cancelledByRightClick: true);
      }

      final selectedRect = selectionResult.rect;
      if (selectedRect == null ||
          selectedRect.width < 4 ||
          selectedRect.height < 4) {
        return const _RegionCaptureSelection();
      }

      final anchorRect = _resolveAnchorRectForSelection(
        selectedRect: selectedRect,
        overlayOrigin: overlayOrigin,
        displays: displays,
      );

      return _RegionCaptureSelection(
        captureRect: overlayMetrics.selectionToPhysicalRect(selectedRect),
        windowAlreadyHidden: false,
        overlayOrigin: overlayOrigin,
        overlaySize: overlaySize,
        anchorOrigin: anchorRect.topLeft,
        anchorSize: anchorRect.size,
      );
    } finally {
      _regionSelectionCompleter = null;
      if (mounted) {
        context.read<FloatingButtonBloc>().add(
          const FloatingButtonRegionSelectionEnded(),
        );
      }
    }
  }

  Future<bool> _runVideoCountdown({
    required FloatingButtonState state,
    required Offset overlayOrigin,
    required Size overlaySize,
    required String label,
  }) async {
    try {
      if (mounted) {
        context.read<FloatingButtonBloc>().add(
          const FloatingButtonVideoOverlayStarted(),
        );
      }
      await windowManager.setPosition(overlayOrigin);
      await windowManager.setMinimumSize(overlaySize);
      await windowManager.setMaximumSize(overlaySize);
      await windowManager.setSize(overlaySize);

      for (var remaining = 3; remaining >= 1; remaining--) {
        if (!mounted) return false;
        setState(() {
          _videoCountdownValue = remaining;
          _videoCountdownLabel = label;
        });
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      return mounted;
    } finally {
      if (mounted) {
        setState(() {
          _videoCountdownValue = null;
          _videoCountdownLabel = null;
        });
      }
    }
  }

  Future<void> _restoreVideoOverlayWindow(FloatingButtonState state) async {
    if (!mounted) return;
    context.read<FloatingButtonBloc>().add(
      const FloatingButtonVideoOverlayEnded(),
    );
    await windowManager.setMinimumSize(state.windowSize);
    await windowManager.setMaximumSize(state.windowSize);
    await windowManager.setSize(state.windowSize);
    await windowManager.setPosition(state.position);
    await windowManager.show(inactive: true);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<_RegionCaptureSelection?> _requestRegionCaptureRect(
    FloatingButtonState state, {
    bool hideWindowAfterSelection = true,
  }) async {
    final completer = Completer<_RegionSelectionDialogResult?>();
    _regionSelectionCompleter = completer;

    context.read<FloatingButtonBloc>().add(
      const FloatingButtonRegionSelectionStarted(),
    );

    final overlayMetrics = await _resolveVirtualDesktopOverlayMetrics();
    final overlaySize = overlayMetrics.logicalSize;
    final overlayOrigin = overlayMetrics.logicalOrigin;

    try {
      await windowManager.setPosition(overlayOrigin);
      await windowManager.setMinimumSize(overlaySize);
      await windowManager.setMaximumSize(overlaySize);
      await windowManager.setSize(overlaySize);

      final selectionResult = await completer.future;

      if (selectionResult == null) {
        return null;
      }

      if (selectionResult.cancelledByRightClick) {
        return const _RegionCaptureSelection(cancelledByRightClick: true);
      }

      final selectedRect = selectionResult.rect;
      if (selectedRect == null ||
          selectedRect.width < 4 ||
          selectedRect.height < 4) {
        return const _RegionCaptureSelection();
      }

      var windowAlreadyHidden = false;
      if (hideWindowAfterSelection && await windowManager.isVisible()) {
        await windowManager.hide();
        windowAlreadyHidden = true;
      }

      if (windowAlreadyHidden) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }

      return _RegionCaptureSelection(
        captureRect: overlayMetrics.selectionToPhysicalRect(selectedRect),
        windowAlreadyHidden: windowAlreadyHidden,
        overlayOrigin: overlayOrigin,
        overlaySize: overlaySize,
      );
    } finally {
      _regionSelectionCompleter = null;
      await windowManager.setMinimumSize(state.windowSize);
      await windowManager.setMaximumSize(state.windowSize);
      await windowManager.setSize(state.windowSize);
      await windowManager.setPosition(state.position);
      if (mounted) {
        context.read<FloatingButtonBloc>().add(
          const FloatingButtonRegionSelectionEnded(),
        );
      }
    }
  }

  List<ProjectEntity?> _resolveQuickProjectSlots(FloatingButtonState state) {
    final byId = <String, ProjectEntity>{
      for (final project in state.projects) project.id: project,
    };

    final quickProjects = state.quickProjectIds
        .map((id) => byId[id])
        .take(3)
        .toList(growable: true);

    while (quickProjects.length < 3) {
      quickProjects.add(null);
    }

    return quickProjects;
  }

  void _handleModeTap(FloatingCaptureMode mode, FloatingButtonState state) {
    if (_isVideoRecording || _isVideoBusy) {
      return;
    }
    final floatingBloc = context.read<FloatingButtonBloc>();

    if (mode == FloatingCaptureMode.clip && state.isClipSessionActive) {
      floatingBloc.add(const FloatingButtonClipSessionStopped());
      return;
    }

    floatingBloc.add(FloatingButtonCaptureModeChanged(mode));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _videoRuntime,
      builder: (context, _) {
        return BlocBuilder<FloatingButtonBloc, FloatingButtonState>(
          builder: (context, state) {
            if (_videoTargetCompleter != null) {
              final displays = _pendingVideoDisplays;
              return _VideoTargetSelectionSurface(
                displays: displays,
                anchorBounds:
                    _pendingVideoTargetAnchorBounds ??
                    const Rect.fromLTWH(0, 0, 1200, 800),
                onSelected: _completeVideoTargetSelection,
              );
            }

            if (state.isRegionSelecting) {
              return _RegionSelectionSurface(
                onCompleted: _completeRegionSelection,
              );
            }

            if (_videoCountdownValue != null) {
              return _VideoCountdownSurface(
                countdown: _videoCountdownValue!,
                label: _videoCountdownLabel ?? 'Preparando grabación',
              );
            }

            if (state.isVideoRecordingHud ||
                _videoRuntime.isHudVisible ||
                _isVideoRecording) {
              return AnimatedBuilder(
                animation: _videoRuntime,
                builder: (context, _) {
                  return _VideoRecordingHud(
                    elapsed: _videoRuntime.elapsed,
                    isPaused: _videoRuntime.isPaused,
                    isBusy: _videoRuntime.isBusy || _isVideoBusy,
                    onPauseToggle: _toggleVideoPause,
                    onStop: _stopVideoRecording,
                  );
                },
              );
            }

            if (_showClipNamingTransition) {
              return const _ClipNamingTransitionSurface();
            }

            final quickProjectSlots = _resolveQuickProjectSlots(state);

            return Material(
              color: Colors.transparent,
              child: GestureDetector(
                onPanStart: (_) {
                  widget.onDragStarted?.call();
                  unawaited(windowManager.startDragging());
                },
                behavior: HitTestBehavior.opaque,
                child: TooltipVisibility(
                  visible: false,
                  child: state.isVertical
                      ? _VerticalFloatingContent(
                          state: state,
                          isVideoRecording: _isVideoRecording,
                          isVideoBusy: _isVideoBusy,
                          isSystemClosing: _isSystemClosing,
                          videoElapsed: _videoRuntime.elapsed,
                          quickProjectSlots: quickProjectSlots,
                          onOpenViewerTap: () {
                            unawaited(AppRouter.openViewer());
                          },
                          onQuickSlotPrimaryTap: _handleQuickSlotPrimaryTap,
                          onQuickSlotSecondaryTap: (slotIndex) {
                            unawaited(_handleQuickSlotSecondaryTap(slotIndex));
                          },
                          onCaptureTap: () => _handleCaptureTap(state),
                          onModeTap: (mode) => _handleModeTap(mode, state),
                          onCloseSystemTap: _handleSystemCloseTap,
                        )
                      : _HorizontalFloatingContent(
                          state: state,
                          isVideoRecording: _isVideoRecording,
                          isVideoBusy: _isVideoBusy,
                          isSystemClosing: _isSystemClosing,
                          videoElapsed: _videoRuntime.elapsed,
                          quickProjectSlots: quickProjectSlots,
                          onOpenViewerTap: () {
                            unawaited(AppRouter.openViewer());
                          },
                          onQuickSlotPrimaryTap: _handleQuickSlotPrimaryTap,
                          onQuickSlotSecondaryTap: (slotIndex) {
                            unawaited(_handleQuickSlotSecondaryTap(slotIndex));
                          },
                          onCaptureTap: () => _handleCaptureTap(state),
                          onModeTap: (mode) => _handleModeTap(mode, state),
                          onCloseSystemTap: _handleSystemCloseTap,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _completeRegionSelection(_RegionSelectionDialogResult result) {
    final completer = _regionSelectionCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(result);
  }

  List<Display> _pendingVideoDisplays = const <Display>[];

  void _completeVideoTargetSelection(_VideoTargetChoice? result) {
    final completer = _videoTargetCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(result);
  }
}

class _HorizontalFloatingContent extends StatelessWidget {
  const _HorizontalFloatingContent({
    required this.state,
    required this.isVideoRecording,
    required this.isVideoBusy,
    required this.isSystemClosing,
    required this.videoElapsed,
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
    required this.onCloseSystemTap,
  });

  final FloatingButtonState state;
  final bool isVideoRecording;
  final bool isVideoBusy;
  final bool isSystemClosing;
  final Duration videoElapsed;
  final List<ProjectEntity?> quickProjectSlots;
  final VoidCallback onOpenViewerTap;
  final void Function(int slotIndex, ProjectEntity? project)
  onQuickSlotPrimaryTap;
  final void Function(int slotIndex) onQuickSlotSecondaryTap;
  final VoidCallback onCaptureTap;
  final ValueChanged<FloatingCaptureMode> onModeTap;
  final Future<void> Function() onCloseSystemTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: _floatingPanelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(kFloatingPanelInnerPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconCircleButton(
                icon: Icons.photo_library_outlined,
                onTap: onOpenViewerTap,
              ),
              const SizedBox(width: _kControlGap),
              ...quickProjectSlots.asMap().entries.expand((entry) {
                final badge = _QuickProjectBadge(
                  project: entry.value,
                  slotIndex: entry.key,
                  isSelected: entry.value?.id == state.activeProject?.id,
                  onPrimaryTap: () =>
                      onQuickSlotPrimaryTap(entry.key, entry.value),
                  onSecondaryTap: () => onQuickSlotSecondaryTap(entry.key),
                );
                if (entry.key == quickProjectSlots.length - 1) {
                  return <Widget>[badge];
                }
                return <Widget>[
                  badge,
                  const SizedBox(width: _kControlGap),
                ];
              }),
              const SizedBox(width: _kControlGap),
              _CapturePrimaryButton(
                onTap: onCaptureTap,
                clipActive: state.isClipSessionActive,
                videoMode: state.captureMode == FloatingCaptureMode.video,
                videoRecording: isVideoRecording,
                videoBusy: isVideoBusy,
                videoElapsed: videoElapsed,
              ),
              const SizedBox(width: _kControlGap),
              _ModeIconButton(
                icon: Icons.monitor,
                selected: state.captureMode == FloatingCaptureMode.screen,
                onTap: () => onModeTap(FloatingCaptureMode.screen),
              ),
              const SizedBox(width: _kControlGap),
              _ModeIconButton(
                icon: Icons.crop_free,
                selected: state.captureMode == FloatingCaptureMode.region,
                onTap: () => onModeTap(FloatingCaptureMode.region),
              ),
              const SizedBox(width: _kControlGap),
              _ModeIconButton(
                icon: Icons.content_cut,
                selected: state.captureMode == FloatingCaptureMode.clip,
                highlighted: state.isClipSessionActive,
                onTap: () => onModeTap(FloatingCaptureMode.clip),
              ),
              const SizedBox(width: _kControlGap),
              _ModeIconButton(
                icon: Icons.videocam_outlined,
                selected: state.captureMode == FloatingCaptureMode.video,
                highlighted: isVideoRecording,
                onTap: () => onModeTap(FloatingCaptureMode.video),
              ),
              const SizedBox(width: _kControlGap),
              _IconCircleButton(
                icon: Icons.power_settings_new,
                onTap: isSystemClosing
                    ? null
                    : () {
                        unawaited(onCloseSystemTap());
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalFloatingContent extends StatelessWidget {
  const _VerticalFloatingContent({
    required this.state,
    required this.isVideoRecording,
    required this.isVideoBusy,
    required this.isSystemClosing,
    required this.videoElapsed,
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
    required this.onCloseSystemTap,
  });

  final FloatingButtonState state;
  final bool isVideoRecording;
  final bool isVideoBusy;
  final bool isSystemClosing;
  final Duration videoElapsed;
  final List<ProjectEntity?> quickProjectSlots;
  final VoidCallback onOpenViewerTap;
  final void Function(int slotIndex, ProjectEntity? project)
  onQuickSlotPrimaryTap;
  final void Function(int slotIndex) onQuickSlotSecondaryTap;
  final VoidCallback onCaptureTap;
  final ValueChanged<FloatingCaptureMode> onModeTap;
  final Future<void> Function() onCloseSystemTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: DecoratedBox(
        decoration: _floatingPanelDecoration(vertical: true),
        child: Padding(
          padding: const EdgeInsets.all(kFloatingPanelInnerPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconCircleButton(
                icon: Icons.photo_library_outlined,
                onTap: onOpenViewerTap,
              ),
              const SizedBox(height: _kControlGap),
              ...quickProjectSlots.asMap().entries.expand((entry) {
                final badge = _QuickProjectBadge(
                  project: entry.value,
                  slotIndex: entry.key,
                  isSelected: entry.value?.id == state.activeProject?.id,
                  onPrimaryTap: () =>
                      onQuickSlotPrimaryTap(entry.key, entry.value),
                  onSecondaryTap: () => onQuickSlotSecondaryTap(entry.key),
                );
                if (entry.key == quickProjectSlots.length - 1) {
                  return <Widget>[badge];
                }
                return <Widget>[
                  badge,
                  const SizedBox(height: _kControlGap),
                ];
              }),
              const SizedBox(height: _kControlGap),
              _CapturePrimaryButton(
                onTap: onCaptureTap,
                clipActive: state.isClipSessionActive,
                videoMode: state.captureMode == FloatingCaptureMode.video,
                videoRecording: isVideoRecording,
                videoBusy: isVideoBusy,
                videoElapsed: videoElapsed,
              ),
              const SizedBox(height: _kControlGap),
              _ModeIconButton(
                icon: Icons.monitor,
                selected: state.captureMode == FloatingCaptureMode.screen,
                onTap: () => onModeTap(FloatingCaptureMode.screen),
              ),
              const SizedBox(height: _kControlGap),
              _ModeIconButton(
                icon: Icons.crop_free,
                selected: state.captureMode == FloatingCaptureMode.region,
                onTap: () => onModeTap(FloatingCaptureMode.region),
              ),
              const SizedBox(height: _kControlGap),
              _ModeIconButton(
                icon: Icons.content_cut,
                selected: state.captureMode == FloatingCaptureMode.clip,
                highlighted: state.isClipSessionActive,
                onTap: () => onModeTap(FloatingCaptureMode.clip),
              ),
              const SizedBox(height: _kControlGap),
              _ModeIconButton(
                icon: Icons.videocam_outlined,
                selected: state.captureMode == FloatingCaptureMode.video,
                highlighted: isVideoRecording,
                onTap: () => onModeTap(FloatingCaptureMode.video),
              ),
              const SizedBox(height: _kControlGap),
              _IconCircleButton(
                icon: Icons.power_settings_new,
                onTap: isSystemClosing
                    ? null
                    : () {
                        unawaited(onCloseSystemTap());
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoRecordingHud extends StatelessWidget {
  const _VideoRecordingHud({
    required this.elapsed,
    required this.isPaused,
    required this.isBusy,
    required this.onPauseToggle,
    required this.onStop,
  });

  final Duration elapsed;
  final bool isPaused;
  final bool isBusy;
  final VoidCallback onPauseToggle;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: DecoratedBox(
        decoration: _floatingPanelDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isPaused
                          ? const Color(0xFFE0B74C)
                          : const Color(0xFFE25252),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 68,
                    child: Text(
                      _formatDuration(elapsed),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'GRABANDO VIDEO',
                    style: TextStyle(
                      color: isPaused
                          ? Colors.white.withValues(alpha: 0.78)
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.35,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RecordingHudButton(
                    icon: isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap: isBusy ? null : onPauseToggle,
                  ),
                  const SizedBox(width: 8),
                  _RecordingHudButton(
                    icon: Icons.stop_rounded,
                    destructive: true,
                    onTap: isBusy ? null : onStop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: DecoratedBox(
        decoration: _floatingPanelDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isPaused
                      ? const Color(0xFFE0B74C)
                      : const Color(0xFFE25252),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 68,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused ? 'Grabación en pausa' : 'Grabando video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RecordingHudButton(
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: isBusy ? null : onPauseToggle,
              ),
              const SizedBox(width: 8),
              _RecordingHudButton(
                icon: Icons.stop_rounded,
                destructive: true,
                onTap: isBusy ? null : onStop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingHudButton extends StatelessWidget {
  const _RecordingHudButton({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: destructive
                ? const Color(0xFF6B2525)
                : const Color(0xCC25384A),
            shape: BoxShape.circle,
            border: Border.all(
              color: destructive
                  ? const Color(0xFFDA8B8B)
                  : const Color(0x668BB8DB),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CapturePrimaryButton extends StatelessWidget {
  const _CapturePrimaryButton({
    required this.onTap,
    required this.clipActive,
    required this.videoMode,
    required this.videoRecording,
    required this.videoBusy,
    required this.videoElapsed,
  });

  final VoidCallback onTap;
  final bool clipActive;
  final bool videoMode;
  final bool videoRecording;
  final bool videoBusy;
  final Duration videoElapsed;

  @override
  Widget build(BuildContext context) {
    final icon = videoRecording
        ? Icons.stop_rounded
        : videoMode
        ? Icons.videocam_rounded
        : Icons.photo_camera;
    final timeLabel = _formatDuration(videoElapsed);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _kCaptureButtonSize,
        height: _kCaptureButtonSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD75A55), Color(0xFFBE4540)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF0A8A5), width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: _kCaptureButtonSize - 8,
              height: _kCaptureButtonSize - 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ),
            ),
            Icon(
              icon,
              color: Colors.white,
              size: _kControlIconSize,
            ),
            if (clipActive)
              const Positioned(
                top: 11,
                right: 11,
                child: Icon(
                  Icons.fiber_manual_record,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            if (videoRecording)
              Positioned(
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (videoBusy)
              const Positioned(
                top: 11,
                right: 11,
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

BoxDecoration _floatingPanelDecoration({bool vertical = false}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    gradient: const LinearGradient(
      colors: [
        Color(0xFF122235),
        Color(0xFF173149),
        Color(0xFF211B27),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    border: Border.all(
      color: const Color(0x78A9D8FF),
    ),
  );
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kControlButtonSize / 2),
        onTap: onTap,
        child: Ink(
          width: _kControlButtonSize,
          height: _kControlButtonSize,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xCC25384A) : const Color(0x7A25384A),
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? const Color(0x668BB8DB)
                  : const Color(0x408BB8DB),
            ),
          ),
          child: Icon(
            icon,
            size: _kControlIconSize,
            color: enabled ? const Color(0xFFF3F7FC) : const Color(0x99F3F7FC),
          ),
        ),
      ),
    );
  }
}

class _ModeIconButton extends StatelessWidget {
  const _ModeIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kControlButtonSize / 2),
        onTap: onTap,
        child: Ink(
          width: _kControlButtonSize,
          height: _kControlButtonSize,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F78E0) : const Color(0xC825384A),
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFB44545)
                  : selected
                  ? const Color(0xFF90CBFF)
                  : const Color(0x668BB8DB),
              width: highlighted ? 1.4 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: _kControlIconSize,
            color: selected ? const Color(0xFFF8FBFF) : const Color(0xFFE6EEF6),
          ),
        ),
      ),
    );
  }
}

class _QuickProjectBadge extends StatelessWidget {
  const _QuickProjectBadge({
    required this.project,
    required this.slotIndex,
    required this.isSelected,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final ProjectEntity? project;
  final int slotIndex;
  final bool isSelected;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final label = _buildSlotLabel(project);
    final isAssigned = project != null;
    final backgroundColor = isSelected
        ? const Color(0xFF2C8C63)
        : Colors.transparent;
    final borderColor = isSelected
        ? const Color(0xFFBFE8CF)
        : const Color(0x668BB8DB);
    final textColor = isSelected
        ? Colors.white
        : isAssigned
        ? const Color(0xFFE6EEF6)
        : const Color(0x99C6D6E7);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPrimaryTap,
      onSecondaryTap: onSecondaryTap,
      child: Container(
        width: _kControlButtonSize,
        height: _kControlButtonSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: AppText(
            label,
            variant: TextVariant.labelSmall,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _buildSlotLabel(ProjectEntity? project) {
    if (project == null) return '---';

    final source = project.name.trim().isNotEmpty
        ? project.name.trim()
        : _folderNameFromPath(project.folderPath);
    final cleaned = source.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();

    if (cleaned.isEmpty) return 'PRY';
    if (cleaned.length >= 3) {
      return cleaned.substring(0, 3);
    }
    return cleaned.padRight(3, 'X');
  }

  String _folderNameFromPath(String path) {
    var normalized = path.trim().replaceAll(r'\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.isEmpty) return '';
    final pieces = normalized.split('/');
    return pieces.isEmpty ? normalized : pieces.last.trim();
  }
}

class _ClipCaptureNamingDecision {
  const _ClipCaptureNamingDecision({
    required this.baseName,
    required this.sequenceSeed,
    required this.applyToRemaining,
  });

  final String baseName;
  final String sequenceSeed;
  final bool applyToRemaining;

  String get effectiveSequenceSeed {
    final trimmedSeed = sequenceSeed.trim();
    if (trimmedSeed.isNotEmpty) {
      return trimmedSeed;
    }
    return applyToRemaining ? '1' : '';
  }

  String get fileName {
    final trimmedBase = baseName.trim();
    if (trimmedBase.isEmpty) {
      return '';
    }

    final token = applyToRemaining
        ? effectiveSequenceSeed
        : sequenceSeed.trim();
    if (token.isEmpty) {
      return trimmedBase;
    }
    return '$trimmedBase-$token';
  }
}

class _ClipNamingSequence {
  _ClipNamingSequence({
    required this.baseName,
    required this.tokenPrefix,
    required this.nextValue,
    required this.padding,
    required this.tokenSuffix,
  });

  final String baseName;
  final String tokenPrefix;
  int nextValue;
  final int padding;
  final String tokenSuffix;

  factory _ClipNamingSequence.fromBaseAndSeed({
    required String baseName,
    required String initialToken,
  }) {
    final normalizedBase = baseName.trim();
    final normalizedToken = initialToken.trim().isEmpty
        ? '1'
        : initialToken.trim();
    final match = RegExp(r'^(.*?)(\d+)(.*)$').firstMatch(normalizedToken);
    if (match == null) {
      return _ClipNamingSequence(
        baseName: normalizedBase,
        tokenPrefix: '$normalizedToken-',
        nextValue: 2,
        padding: 1,
        tokenSuffix: '',
      );
    }

    return _ClipNamingSequence(
      baseName: normalizedBase,
      tokenPrefix: match.group(1) ?? '',
      nextValue: int.parse(match.group(2)!) + 1,
      padding: match.group(2)!.length,
      tokenSuffix: match.group(3) ?? '',
    );
  }

  String consumeCurrentName() {
    final currentToken =
        '$tokenPrefix${nextValue.toString().padLeft(padding, '0')}$tokenSuffix';
    nextValue++;
    return '$baseName-$currentToken';
  }
}

class _ClipCaptureNamingDialog extends StatefulWidget {
  const _ClipCaptureNamingDialog();

  @override
  State<_ClipCaptureNamingDialog> createState() =>
      _ClipCaptureNamingDialogState();
}

class _ClipCaptureNamingDialogState extends State<_ClipCaptureNamingDialog> {
  late final TextEditingController _baseNameController;
  late final TextEditingController _sequenceController;
  bool _applyToRemaining = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _baseNameController = TextEditingController();
    _sequenceController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _baseNameController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF151A1F);
    const frame = Color(0xFF0E141A);
    const border = Color(0xFF2A3642);
    const primary = Color(0xFF6EC1FF);
    final baseTheme = Theme.of(context);
    final theme = baseTheme.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF062033),
        surface: surface,
        onSurface: Color(0xFFF4F8FC),
        error: Color(0xFFFFB4AB),
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: const Color(0xFFF4F8FC),
        displayColor: const Color(0xFFF4F8FC),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: Color(0xFFC8D6E5)),
        floatingLabelStyle: const TextStyle(color: Color(0xFF9ED6FF)),
        hintStyle: const TextStyle(color: Color(0xFF7F96AB)),
        filled: true,
        fillColor: const Color(0xFF11171D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return const Color(0xFF1A232C);
        }),
        checkColor: const WidgetStatePropertyAll(Color(0xFF062033)),
        side: const BorderSide(color: border),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD6E6F5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF062033),
        ),
      ),
    );

    final currentBaseName = _baseNameController.text.trim();
    final currentSeed = _sequenceController.text.trim();
    final effectiveSeed = currentSeed.isNotEmpty
        ? currentSeed
        : _applyToRemaining
        ? '1'
        : '';
    final currentPreview = currentBaseName.isEmpty
        ? 'Sin nombre personalizado'
        : effectiveSeed.isEmpty
        ? currentBaseName
        : '$currentBaseName-$effectiveSeed';
    final nextPreview = _buildNextSequencePreview(
      currentBaseName,
      effectiveSeed,
    );

    return Theme(
      data: theme,
      child: Material(
        color: frame,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: frame,
            border: Border.all(color: border),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Nombre para la captura clip',
                            variant: TextVariant.titleMedium,
                            color: Color(0xFFF4F8FC),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10161C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Siguiente paso',
                                  variant: TextVariant.labelSmall,
                                  color: Color(0xFF8FA7BD),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Configura el nombre y luego realiza el clip para tomar la captura.',
                                  style: TextStyle(
                                    color: Color(0xFFE7EEF6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Nombre base',
                            controller: _baseNameController,
                            hint: 'Ejemplo: cafecaliente',
                            onChanged: (_) {
                              setState(() {
                                _validationMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Nomenclatura inicial',
                            controller: _sequenceController,
                            hint: 'Ejemplo: 1, 01, A1 o 1a',
                            onChanged: (_) {
                              setState(() {
                                _validationMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _applyToRemaining,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const AppText(
                              'Usar este patron para las siguientes capturas',
                              color: Color(0xFFE7EEF6),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _applyToRemaining = value ?? false;
                                _validationMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10161C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Vista previa',
                                  variant: TextVariant.labelSmall,
                                  color: Color(0xFF8FA7BD),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentPreview,
                                  style: const TextStyle(
                                    color: Color(0xFFF4F8FC),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_applyToRemaining &&
                                    nextPreview.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Siguientes: $nextPreview...',
                                    style: const TextStyle(
                                      color: Color(0xFF9ED6FF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const AppText(
                            'Si activas el patron y dejas la nomenclatura vacia, se usara 1. Si omites sin escribir un nombre, esta captura conservara el nombre por defecto.',
                            variant: TextVariant.bodySmall,
                            color: Color(0xFF8FA7BD),
                          ),
                          if (_validationMessage != null) ...[
                            const SizedBox(height: 10),
                            AppText(
                              _validationMessage!,
                              variant: TextVariant.bodySmall,
                              color: const Color(0xFFFFB4AB),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'Cancelar',
                        variant: AppButtonVariant.text,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: 'Omitir',
                        variant: AppButtonVariant.text,
                        onPressed: _submitSkip,
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: 'Guardar',
                        onPressed: _submitSave,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSkip() async {
    final trimmedBase = _baseNameController.text.trim();
    if (trimmedBase.isEmpty) {
      final acknowledged = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF151A1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2A3642)),
            ),
            title: const Text('Nombre por defecto'),
            content: const Text(
              'Esta captura se guardara con el nombre por defecto actual.',
              style: TextStyle(color: Color(0xFFD6E6F5)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Entendido',
                  style: TextStyle(color: Color(0xFF6EC1FF)),
                ),
              ),
            ],
          );
        },
      );
      if (!mounted || acknowledged != true) {
        return;
      }
    }

    Navigator.of(context).pop(
      _ClipCaptureNamingDecision(
        baseName: trimmedBase,
        sequenceSeed: _sequenceController.text.trim(),
        applyToRemaining: false,
      ),
    );
  }

  void _submitSave() {
    final trimmedBase = _baseNameController.text.trim();
    if (trimmedBase.isEmpty) {
      setState(() {
        _validationMessage =
            'Escribe un nombre para guardar o usa Omitir para conservar el nombre por defecto.';
      });
      return;
    }

    Navigator.of(context).pop(
      _ClipCaptureNamingDecision(
        baseName: trimmedBase,
        sequenceSeed: _sequenceController.text.trim(),
        applyToRemaining: _applyToRemaining,
      ),
    );
  }

  String _buildNextSequencePreview(String baseName, String sequenceSeed) {
    final trimmedBase = baseName.trim();
    if (trimmedBase.isEmpty) {
      return '';
    }

    final sequence = _ClipNamingSequence.fromBaseAndSeed(
      baseName: trimmedBase,
      initialToken: sequenceSeed,
    );
    final first = sequence.consumeCurrentName();
    final second = sequence.consumeCurrentName();
    return '$first, $second';
  }
}

class _ClipNamingTransitionSurface extends StatelessWidget {
  const _ClipNamingTransitionSurface();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF11171D),
      child: SizedBox.expand(),
    );
  }
}

class _ClipSessionFinishedDialog extends StatefulWidget {
  const _ClipSessionFinishedDialog();

  @override
  State<_ClipSessionFinishedDialog> createState() =>
      _ClipSessionFinishedDialogState();
}

class _ClipSessionFinishedDialogState
    extends State<_ClipSessionFinishedDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(_autoClose());
  }

  Future<void> _autoClose() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const _ClipSessionFinishedDialogContent();
  }
}

class _ClipSessionFinishedDialogContent extends StatelessWidget {
  const _ClipSessionFinishedDialogContent();

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF151A1F);
    const frame = Color(0xFF0E141A);
    const border = Color(0xFF2A3642);
    const primary = Color(0xFF6EC1FF);

    final theme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF062033),
        surface: surface,
        onSurface: Color(0xFFF4F8FC),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF062033),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Material(
        color: frame,
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: frame,
              border: Border.all(color: border),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Captura continua finalizada',
                    variant: TextVariant.titleMedium,
                    color: Color(0xFFF4F8FC),
                  ),
                  const SizedBox(height: 10),
                  const AppText(
                    'El proceso de toma de capturas en modo clip se ha detenido correctamente.',
                    variant: TextVariant.bodyMedium,
                    color: Color(0xFFD6E6F5),
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'La ventana se cerrara automaticamente en 3 segundos.',
                    variant: TextVariant.bodySmall,
                    color: Color(0xFF8FA7BD),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'OK',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionSelectionSurface extends StatefulWidget {
  const _RegionSelectionSurface({
    required this.onCompleted,
  });

  final ValueChanged<_RegionSelectionDialogResult> onCompleted;

  @override
  State<_RegionSelectionSurface> createState() =>
      _RegionSelectionSurfaceState();
}

class _RegionSelectionSurfaceState extends State<_RegionSelectionSurface> {
  Offset? _start;
  Offset? _current;

  Rect? get _rect {
    if (_start == null || _current == null) return null;
    return Rect.fromPoints(_start!, _current!);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _start = details.localPosition;
              _current = details.localPosition;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _current = details.localPosition;
            });
          },
          onPanEnd: (_) {
            final rect = _rect;
            if (rect == null || rect.width < 4 || rect.height < 4) {
              widget.onCompleted(const _RegionSelectionDialogResult());
              return;
            }
            widget.onCompleted(_RegionSelectionDialogResult(rect: rect));
          },
          onSecondaryTap: () {
            widget.onCompleted(
              const _RegionSelectionDialogResult(cancelledByRightClick: true),
            );
          },
          child: CustomPaint(
            painter: _RegionSelectionPainter(selection: _rect),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _RegionCaptureSelection {
  const _RegionCaptureSelection({
    this.captureRect,
    this.cancelledByRightClick = false,
    this.windowAlreadyHidden = false,
    this.overlayOrigin,
    this.overlaySize,
    this.anchorOrigin,
    this.anchorSize,
  });

  final Rect? captureRect;
  final bool cancelledByRightClick;
  final bool windowAlreadyHidden;
  final Offset? overlayOrigin;
  final Size? overlaySize;
  final Offset? anchorOrigin;
  final Size? anchorSize;
}

class _RegionSelectionDialogResult {
  const _RegionSelectionDialogResult({
    this.rect,
    this.cancelledByRightClick = false,
  });

  final Rect? rect;
  final bool cancelledByRightClick;
}

class _RegionSelectionPainter extends CustomPainter {
  const _RegionSelectionPainter({required this.selection});

  final Rect? selection;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = selection;
    if (rect == null) return;

    final normalized = Rect.fromLTRB(
      rect.left < rect.right ? rect.left : rect.right,
      rect.top < rect.bottom ? rect.top : rect.bottom,
      rect.left > rect.right ? rect.left : rect.right,
      rect.top > rect.bottom ? rect.top : rect.bottom,
    );

    final fill = Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.2);
    final stroke = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas
      ..drawRect(normalized, fill)
      ..drawRect(normalized, stroke);
  }

  @override
  bool shouldRepaint(covariant _RegionSelectionPainter oldDelegate) {
    return oldDelegate.selection != selection;
  }
}

enum _VideoTargetChoiceKind { region, display }

class _VideoTargetChoice {
  const _VideoTargetChoice.region()
    : kind = _VideoTargetChoiceKind.region,
      display = null,
      label = 'Área personalizada';

  const _VideoTargetChoice.display({
    required this.display,
    required this.label,
  }) : kind = _VideoTargetChoiceKind.display;

  final _VideoTargetChoiceKind kind;
  final Display? display;
  final String label;
}

class _VideoTargetSelection {
  const _VideoTargetSelection({
    required this.target,
    required this.overlayOrigin,
    required this.overlaySize,
  });

  final VideoRecordingTarget target;
  final Offset overlayOrigin;
  final Size overlaySize;
}

class _VideoTargetDialog extends StatelessWidget {
  const _VideoTargetDialog({
    required this.displays,
  });

  final List<Display> displays;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161C24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Grabar video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige si quieres grabar una región o una pantalla completa.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _VideoTargetOptionTile(
                icon: Icons.crop_free,
                title: 'Área personalizada',
                subtitle: 'Selecciona manualmente la zona a grabar',
                onTap: () {
                  Navigator.of(
                    context,
                  ).pop(const _VideoTargetChoice.region());
                },
              ),
              const SizedBox(height: 10),
              ...displays.asMap().entries.map((entry) {
                final display = entry.value;
                final size = display.size;
                final label = 'Pantalla ${entry.key + 1}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VideoTargetOptionTile(
                    icon: Icons.monitor,
                    title: label,
                    subtitle: '${size.width.round()} x ${size.height.round()}',
                    onTap: () {
                      Navigator.of(context).pop(
                        _VideoTargetChoice.display(
                          display: display,
                          label: label,
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTargetSelectionSurface extends StatelessWidget {
  const _VideoTargetSelectionSurface({
    required this.displays,
    required this.anchorBounds,
    required this.onSelected,
  });

  final List<Display> displays;
  final Rect anchorBounds;
  final ValueChanged<_VideoTargetChoice?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTap: () => onSelected(null),
        child: Stack(
          children: [
            Positioned(
              left: anchorBounds.left,
              top:
                  anchorBounds.top +
                  ((anchorBounds.height - 420) / 2).clamp(24.0, 220.0),
              width: anchorBounds.width,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: anchorBounds.width.clamp(320.0, 460.0),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xEE161C24),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grabar video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Elige si vas a grabar una región o una pantalla completa.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _VideoTargetOptionTile(
                            icon: Icons.crop_free,
                            title: 'Área personalizada',
                            subtitle: 'Selecciona manualmente la zona a grabar',
                            onTap: () {
                              onSelected(const _VideoTargetChoice.region());
                            },
                          ),
                          const SizedBox(height: 10),
                          ...displays.asMap().entries.map((entry) {
                            final display = entry.value;
                            final size = display.size;
                            final label = 'Pantalla ${entry.key + 1}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _VideoTargetOptionTile(
                                icon: Icons.monitor,
                                title: label,
                                subtitle:
                                    '${size.width.round()} x ${size.height.round()} · Próximamente',
                                badgeLabel: 'En construcción',
                                enabled: false,
                                onTap: () {},
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Clic derecho para cancelar',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => onSelected(null),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  backgroundColor: const Color(0xFF1B2530),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoTargetOptionTile extends StatelessWidget {
  const _VideoTargetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeLabel,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.52);
    final secondary = enabled
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.42);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: enabled ? const Color(0xFF0F141B) : const Color(0xFF131920),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFF1C2632)
                      : const Color(0xFF19212B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x29F0B35A),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x66F0B35A),
                              ),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: const TextStyle(
                                color: Color(0xFFF0C980),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right_rounded : Icons.build_rounded,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCountdownSurface extends StatelessWidget {
  const _VideoCountdownSurface({
    required this.countdown,
    required this.label,
  });

  final int countdown;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xF019202B),
                    Color(0xEE10161D),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 34,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x26FF6B6B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0x55FF8A8A),
                        ),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFFFF7B7B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnimatedCountdownNumber(countdown: countdown),
                    const SizedBox(height: 14),
                    const Text(
                      'La grabación está por comenzar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCountdownNumber extends StatelessWidget {
  const _AnimatedCountdownNumber({
    required this.countdown,
  });

  final int countdown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('ring-$countdown'),
            tween: Tween(begin: 1.22, end: 0.96),
            duration: const Duration(milliseconds: 920),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: (1.26 - value).clamp(0.18, 0.72),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x66FF7B7B),
                  width: 2.4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44FF6B6B),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            key: ValueKey('pulse-$countdown'),
            tween: Tween(begin: 0.86, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: (value * 1.08).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF8F8),
                    Color(0xFFFF8A8A),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                '$countdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: countdown == 1 ? 72 : 78,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const [
                    Shadow(
                      color: Color(0x66FF6B6B),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
