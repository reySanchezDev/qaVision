import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
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

  @override
  void dispose() {
    if (!(_regionSelectionCompleter?.isCompleted ?? true)) {
      _regionSelectionCompleter?.complete(null);
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
    final floatingBloc = context.read<FloatingButtonBloc>();
    var effectiveState = state;

    final hasAnyProject = effectiveState.projects.isNotEmpty;
    if (!hasAnyProject) {
      final selected = await _pickFolderForSlot(0);
      if (!mounted || !selected) return;
      effectiveState = context.read<FloatingButtonBloc>().state;
      if (effectiveState.projects.isEmpty) return;
    }

    if (effectiveState.activeProject == null &&
        effectiveState.projects.isNotEmpty) {
      if (!mounted) return;
      context.read<FloatingButtonBloc>().add(
        FloatingButtonProjectChanged(effectiveState.projects.first),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      effectiveState = context.read<FloatingButtonBloc>().state;
    }

    if (effectiveState.activeProject == null) {
      return;
    }

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
    }
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

  Future<_RegionCaptureSelection?> _requestRegionCaptureRect(
    FloatingButtonState state,
  ) async {
    final completer = Completer<_RegionSelectionDialogResult?>();
    _regionSelectionCompleter = completer;

    context.read<FloatingButtonBloc>().add(
      const FloatingButtonRegionSelectionStarted(),
    );

    final display = await screenRetriever.getPrimaryDisplay();
    final dpr =
        display.scaleFactor?.toDouble() ?? windowManager.getDevicePixelRatio();

    final overlaySize = display.visibleSize ?? display.size;
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

      var windowAlreadyHidden = false;
      if (await windowManager.isVisible()) {
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
    final floatingBloc = context.read<FloatingButtonBloc>();

    if (mode == FloatingCaptureMode.clip && state.isClipSessionActive) {
      floatingBloc.add(const FloatingButtonClipSessionStopped());
      return;
    }

    floatingBloc.add(FloatingButtonCaptureModeChanged(mode));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FloatingButtonBloc, FloatingButtonState>(
      builder: (context, state) {
        if (state.isRegionSelecting) {
          return _RegionSelectionSurface(
            onCompleted: _completeRegionSelection,
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
  }

  void _completeRegionSelection(_RegionSelectionDialogResult result) {
    final completer = _regionSelectionCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(result);
  }
}

class _HorizontalFloatingContent extends StatelessWidget {
  const _HorizontalFloatingContent({
    required this.state,
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
  });

  final FloatingButtonState state;
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
      padding: const EdgeInsets.all(kFloatingWindowOuterPadding),
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
    required this.quickProjectSlots,
    required this.onOpenViewerTap,
    required this.onQuickSlotPrimaryTap,
    required this.onQuickSlotSecondaryTap,
    required this.onCaptureTap,
    required this.onModeTap,
  });

  final FloatingButtonState state;
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
      padding: const EdgeInsets.all(kFloatingWindowOuterPadding),
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

class _CapturePrimaryButton extends StatelessWidget {
  const _CapturePrimaryButton({
    required this.onTap,
    required this.clipActive,
  });

  final VoidCallback onTap;
  final bool clipActive;

  @override
  Widget build(BuildContext context) {
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
            const Icon(
              Icons.photo_camera,
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
          ],
        ),
      ),
    );
  }
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
  });

  final Rect? captureRect;
  final bool cancelledByRightClick;
  final bool windowAlreadyHidden;
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
