import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/services/video_recording_service.dart';
import 'package:qavision/core/services/video_recording_runtime_service.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
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
  Completer<_RegionSelectionDialogResult?>? _regionSelectionCompleter;
  Completer<_VideoTargetChoice?>? _videoTargetCompleter;
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
    if (!Platform.isWindows) {
      return;
    }

    _clipLoopRunning = true;
    floatingBloc.add(const FloatingButtonClipSessionStarted());
    var clipWindowHidden = false;

    VideoRecordingSession? startedSession;
    try {
      clipWindowHidden = await _hideWindowForClipSession();
      await _waitUntilMouseReleased();

      while (mounted) {
        final currentState = floatingBloc.state;
        if (currentState.captureMode != FloatingCaptureMode.clip) {
          break;
        }
        if (!currentState.isClipSessionActive) {
          break;
        }

        final action = await _waitForClipPointerAction(floatingBloc);
        if (!mounted || action == null) break;

        if (action == _ClipPointerAction.stop) {
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }

        floatingBloc.add(
          const FloatingButtonCaptureRequested(
            windowAlreadyHidden: true,
            restoreFloatingWindow: false,
          ),
        );

        final completed = await _waitForCaptureCompletion(floatingBloc);
        if (!completed) {
          floatingBloc.add(const FloatingButtonClipSessionStopped());
          break;
        }
        await _waitUntilMouseReleased();
      }
    } finally {
      _clipLoopRunning = false;
      if (mounted && floatingBloc.state.isClipSessionActive) {
        floatingBloc.add(const FloatingButtonClipSessionStopped());
      }
      if (clipWindowHidden && mounted) {
        final isVisible = await windowManager.isVisible();
        if (!isVisible) {
          await windowManager.show();
        }
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

    while (mounted) {
      final state = floatingBloc.state;
      if (state.captureMode != FloatingCaptureMode.clip ||
          !state.isClipSessionActive) {
        return _ClipPointerAction.stop;
      }

      final rightDown = _isMouseButtonDown(VK_RBUTTON);
      final leftDown = _isMouseButtonDown(VK_LBUTTON);

      if (rightDown && !previousRightDown) {
        return _ClipPointerAction.stop;
      }

      if (leftDown && !previousLeftDown) {
        return _ClipPointerAction.capture;
      }

      previousRightDown = rightDown;
      previousLeftDown = leftDown;
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }

    return null;
  }

  bool _isMouseButtonDown(int virtualKeyCode) {
    return (GetAsyncKeyState(virtualKeyCode) & 0x8000) != 0;
  }

  Future<bool> _waitForCaptureCompletion(
    FloatingButtonBloc floatingBloc,
  ) async {
    if (!Platform.isWindows) {
      return true;
    }

    final captureBloc = context.read<CaptureBloc>();
    var previousRightDown = _isMouseButtonDown(VK_RBUTTON);
    final deadline = DateTime.now().add(const Duration(seconds: 8));

    while (mounted) {
      final state = floatingBloc.state;
      if (state.captureMode != FloatingCaptureMode.clip ||
          !state.isClipSessionActive) {
        return false;
      }

      final rightDown = _isMouseButtonDown(VK_RBUTTON);
      if (rightDown && !previousRightDown) {
        return false;
      }
      previousRightDown = rightDown;

      if (captureBloc.state is! CaptureInProgress) {
        return true;
      }

      if (DateTime.now().isAfter(deadline)) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 14));
    }

    return false;
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
    final selectedPath = await FilePicker.platform.getDirectoryPath();
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

  Future<_VideoTargetChoice?> _requestVideoTargetSelectionOverlay(
    FloatingButtonState state,
  ) async {
    final displays = await screenRetriever.getAllDisplays();
    final availableDisplays = displays.isEmpty
        ? <Display>[await screenRetriever.getPrimaryDisplay()]
        : displays;
    final overlayDisplay = await screenRetriever.getPrimaryDisplay();
    final overlaySize = overlayDisplay.size;
    final overlayOrigin = overlayDisplay.visiblePosition ?? Offset.zero;
    final completer = Completer<_VideoTargetChoice?>();
    _VideoTargetChoice? selectedChoice;
    var shouldRestoreWindow = true;
    _videoTargetCompleter = completer;
    _pendingVideoDisplays = availableDisplays;
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
          overlayOrigin: selection.overlayOrigin ?? Offset.zero,
          overlaySize: selection.overlaySize ?? const Size(1200, 800),
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

    final display = await screenRetriever.getPrimaryDisplay();
    final dpr =
        display.scaleFactor?.toDouble() ?? windowManager.getDevicePixelRatio();
    final overlaySize = display.size;
    final overlayOrigin = display.visiblePosition ?? Offset.zero;

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

      return _RegionCaptureSelection(
        captureRect: Rect.fromLTWH(
          (overlayOrigin.dx + selectedRect.left) * dpr,
          (overlayOrigin.dy + selectedRect.top) * dpr,
          selectedRect.width * dpr,
          selectedRect.height * dpr,
        ),
        windowAlreadyHidden: false,
        overlayOrigin: overlayOrigin,
        overlaySize: overlaySize,
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
    FloatingButtonState state,
    {bool useFullDisplayBounds = false, bool hideWindowAfterSelection = true,}
  ) async {
    final completer = Completer<_RegionSelectionDialogResult?>();
    _regionSelectionCompleter = completer;

    context.read<FloatingButtonBloc>().add(
      const FloatingButtonRegionSelectionStarted(),
    );

    final display = await screenRetriever.getPrimaryDisplay();
    final dpr =
        display.scaleFactor?.toDouble() ?? windowManager.getDevicePixelRatio();

    final overlaySize = useFullDisplayBounds
        ? display.size
        : (display.visibleSize ?? display.size);
    final overlayOrigin = useFullDisplayBounds
        ? (display.visiblePosition ?? Offset.zero)
        : (display.visiblePosition ?? Offset.zero);

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
        captureRect: Rect.fromLTWH(
          (overlayOrigin.dx + selectedRect.left) * dpr,
          (overlayOrigin.dy + selectedRect.top) * dpr,
          selectedRect.width * dpr,
          selectedRect.height * dpr,
        ),
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

        if (state.isVideoRecordingHud || _videoRuntime.isHudVisible || _isVideoRecording) {
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
                    )
                  : _HorizontalFloatingContent(
                      state: state,
                      isVideoRecording: _isVideoRecording,
                      isVideoBusy: _isVideoBusy,
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
    required this.videoElapsed,
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
  });

  final FloatingButtonState state;
  final bool isVideoRecording;
  final bool isVideoBusy;
  final Duration videoElapsed;
  final List<ProjectEntity?> quickProjectSlots;
  final VoidCallback onOpenViewerTap;
  final void Function(int slotIndex, ProjectEntity? project)
  onQuickSlotPrimaryTap;
  final void Function(int slotIndex) onQuickSlotSecondaryTap;
  final VoidCallback onCaptureTap;
  final ValueChanged<FloatingCaptureMode> onModeTap;

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
                onTap: () async {
                  await AppRouter.closeSystem();
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
    required this.videoElapsed,
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
  });

  final FloatingButtonState state;
  final bool isVideoRecording;
  final bool isVideoBusy;
  final Duration videoElapsed;
  final List<ProjectEntity?> quickProjectSlots;
  final VoidCallback onOpenViewerTap;
  final void Function(int slotIndex, ProjectEntity? project)
  onQuickSlotPrimaryTap;
  final void Function(int slotIndex) onQuickSlotSecondaryTap;
  final VoidCallback onCaptureTap;
  final ValueChanged<FloatingCaptureMode> onModeTap;

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
                onTap: () async {
                  await AppRouter.closeSystem();
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const SizedBox(width: 8),
              Expanded(
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
            color: const Color(0xCC25384A),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x668BB8DB)),
          ),
          child: Icon(
            icon,
            size: _kControlIconSize,
            color: const Color(0xFFF3F7FC),
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
            color: selected
                ? const Color(0xFF2F78E0)
                : const Color(0xC825384A),
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
            color: selected
                ? const Color(0xFFF8FBFF)
                : const Color(0xFFE6EEF6),
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
  });

  final Rect? captureRect;
  final bool cancelledByRightClick;
  final bool windowAlreadyHidden;
  final Offset? overlayOrigin;
  final Size? overlaySize;
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
                    subtitle:
                        '${size.width.round()} x ${size.height.round()}',
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
    required this.onSelected,
  });

  final List<Display> displays;
  final ValueChanged<_VideoTargetChoice?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTap: () => onSelected(null),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                              '${size.width.round()} x ${size.height.round()}',
                          onTap: () {
                            onSelected(
                              _VideoTargetChoice.display(
                                display: display,
                                label: label,
                              ),
                            );
                          },
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
                            foregroundColor: Colors.white.withValues(alpha: 0.88),
                            backgroundColor: const Color(0xFF1B2530),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
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
    );
  }
}

class _VideoTargetOptionTile extends StatelessWidget {
  const _VideoTargetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0F141B),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2632),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.62),
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
