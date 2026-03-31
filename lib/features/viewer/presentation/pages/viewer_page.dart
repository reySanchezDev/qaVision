import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/pages/viewer_page_intents.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_viewport_transform_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_canvas_resize_policy.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_captures_strip.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas_drop_target.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_empty_state_overlay.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_layers_panel.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_section_boundary.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_zoom_controls.dart';

/// Main viewer/editor page.
class ViewerPage extends StatefulWidget {
  /// Creates [ViewerPage].
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  Size? _lastRequestedFrameSize;
  Size _lastViewportSize = Size.zero;
  String? _lastAutoFitImageId;
  bool _showLayersPanel = true;

  @override
  Widget build(BuildContext context) {
    final showRecentStrip = _resolveShowRecentStrip(context);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            ViewerUndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true):
            ViewerRedoIntent(),
        SingleActivator(LogicalKeyboardKey.delete): ViewerDeleteIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): ViewerDeleteIntent(),
      },
      child: Actions(
        actions: {
          ViewerUndoIntent: CallbackAction<ViewerUndoIntent>(
            onInvoke: (_) {
              context.read<ViewerBloc>().add(const ViewerUndoRequested());
              return null;
            },
          ),
          ViewerRedoIntent: CallbackAction<ViewerRedoIntent>(
            onInvoke: (_) {
              context.read<ViewerBloc>().add(const ViewerRedoRequested());
              return null;
            },
          ),
          ViewerDeleteIntent: CallbackAction<ViewerDeleteIntent>(
            onInvoke: (_) {
              final selectedId = context
                  .read<ViewerBloc>()
                  .state
                  .selectedElementId;
              if (selectedId != null) {
                context.read<ViewerBloc>().add(
                  ViewerElementDeleted(elementId: selectedId),
                );
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF101010),
            body: BlocBuilder<ViewerBloc, ViewerState>(
              builder: (context, state) {
                if (state.isLoading && state.frame.elements.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      ViewerSectionBoundary(
                        sectionName: 'toolbar',
                        fallbackHeight: 66,
                        builder: (_) => const ViewerToolbar(),
                      ),
                      Expanded(
                        child: ViewerSectionBoundary(
                          sectionName: 'canvas',
                          builder: (_) => Stack(
                            children: [
                              ColoredBox(
                                color: const Color(0xFF0F0F0F),
                                child: Listener(
                                  onPointerSignal: _onPointerSignal,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      _lastViewportSize = Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      );
                                      final targetWidth = math
                                          .max(
                                            320,
                                            constraints.maxWidth,
                                          )
                                          .toDouble();
                                      final targetHeight = math
                                          .max(
                                            220,
                                            constraints.maxHeight,
                                          )
                                          .toDouble();
                                      final targetSize = Size(
                                        targetWidth,
                                        targetHeight,
                                      );
                                      _requestFrameResizeIfNeeded(
                                        context: context,
                                        targetSize: targetSize,
                                        currentSize: state.frame.canvasSize,
                                      );
                                      final maxZoom = _maxZoomForState(state);
                                      final fitZoom = _fitZoomForState(
                                        state,
                                        _lastViewportSize,
                                      );
                                      _autoFitPrimaryImageIfNeeded(
                                        state,
                                        fitZoom,
                                      );
                                      final effectiveZoom = state.canvasZoom
                                          .clamp(
                                            ViewerViewportTransformService
                                                .defaultViewMinZoom,
                                            maxZoom,
                                          );

                                      return ClipRect(
                                        child: Center(
                                          child: ViewerCanvasDropTarget(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black38,
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      6,
                                                    ),
                                              ),
                                              child: ViewerCanvas(
                                                contentZoom: effectiveZoom,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (!state.isLoading &&
                                  state.frame.elements.isEmpty)
                                const ViewerEmptyStateOverlay(),
                              if (state.frame.elements.isNotEmpty)
                                ViewerLayersPanel(
                                  isVisible: _showLayersPanel,
                                  onToggleVisibility: _toggleLayersPanel,
                                ),
                              ViewerZoomControls(
                                zoom: state.canvasZoom.clamp(
                                  ViewerViewportTransformService
                                      .defaultViewMinZoom,
                                  _maxZoomForState(state),
                                ),
                                fitZoom: _fitZoomForState(
                                  state,
                                  _lastViewportSize,
                                ),
                                minEditableZoom: ViewerViewportTransformService
                                    .defaultEditableMinZoom,
                                canZoomOut:
                                    state.canvasZoom >
                                    ViewerViewportTransformService
                                            .defaultEditableMinZoom +
                                        0.001,
                                onFitToScreen: () => _fitToScreen(state),
                                onActualSize: () => _setActualSize(state),
                                onZoomIn: () => _zoomIn(state),
                                onZoomOut: () => _zoomOut(state),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showRecentStrip)
                        ViewerSectionBoundary(
                          sectionName: 'recent_strip',
                          fallbackHeight: 176,
                          builder: (_) => const RecentCapturesStrip(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _toggleLayersPanel() {
    setState(() {
      _showLayersPanel = !_showLayersPanel;
    });
  }

  bool _resolveShowRecentStrip(BuildContext context) {
    return kAppDefaults.showRecentStrip;
  }

  void _requestFrameResizeIfNeeded({
    required BuildContext context,
    required Size targetSize,
    required Size currentSize,
  }) {
    if (ViewerCanvasResizePolicy.isCanvasAligned(
      targetSize: targetSize,
      currentSize: currentSize,
    )) {
      _lastRequestedFrameSize = null;
      return;
    }
    if (_lastRequestedFrameSize == targetSize) {
      return;
    }

    _lastRequestedFrameSize = targetSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ViewerBloc>().add(ViewerCanvasResized(targetSize));
    });
  }

  void _zoomIn(ViewerState state) {
    final maxZoom = _maxZoomForState(state);
    final nextZoom = state.canvasZoom <
            ViewerViewportTransformService.defaultEditableMinZoom
        ? ViewerViewportTransformService.defaultEditableMinZoom
        : state.canvasZoom + 0.1;
    context.read<ViewerBloc>().add(
      ViewerZoomChanged(
        nextZoom.clamp(
          ViewerViewportTransformService.defaultEditableMinZoom,
          maxZoom,
        ),
      ),
    );
  }

  void _zoomOut(ViewerState state) {
    final maxZoom = _maxZoomForState(state);
    context.read<ViewerBloc>().add(
      ViewerZoomChanged(
        (state.canvasZoom - 0.1).clamp(
          ViewerViewportTransformService.defaultEditableMinZoom,
          maxZoom,
        ),
      ),
    );
  }

  void _setActualSize(ViewerState state) {
    final maxZoom = _maxZoomForState(state);
    context.read<ViewerBloc>().add(
      ViewerZoomChanged(
        1
            .clamp(
              ViewerViewportTransformService.defaultEditableMinZoom,
              maxZoom,
            )
            .toDouble(),
      ),
    );
  }

  void _fitToScreen(ViewerState state) {
    final fitZoom = _fitZoomForState(state, _lastViewportSize);
    context.read<ViewerBloc>().add(ViewerZoomChanged(fitZoom));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final state = context.read<ViewerBloc>().state;
    if (event.scrollDelta.dy > 0) {
      _zoomOut(state);
      return;
    }
    if (event.scrollDelta.dy < 0) {
      _zoomIn(state);
    }
  }

  double _maxZoomForState(ViewerState state) {
    final image = _fitTargetImage(state);
    if (image == null) {
      return ViewerViewportTransformService.defaultHardMaxZoom;
    }

    return ViewerViewportTransformService.resolveMaxZoom(
      canvasSize: state.frame.canvasSize,
      imageSize: image.size,
    );
  }

  double _fitZoomForState(ViewerState state, Size viewportSize) {
    final image = _fitTargetImage(state);
    if (image == null || viewportSize == Size.zero) {
      return 1;
    }

    return ViewerViewportTransformService.resolveFitZoom(
      viewportSize: viewportSize,
      imageSize: image.size,
      maxZoom: _maxZoomForState(state),
    );
  }

  ImageFrameComponent? _fitTargetImage(ViewerState state) {
    return state.frame.elements.whereType<ImageFrameComponent>().firstOrNull;
  }

  void _autoFitPrimaryImageIfNeeded(ViewerState state, double fitZoom) {
    final image = _fitTargetImage(state);
    if (image == null) {
      _lastAutoFitImageId = null;
      return;
    }
    if (_lastAutoFitImageId == image.id) return;

    _lastAutoFitImageId = image.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ViewerBloc>().add(ViewerZoomChanged(fitZoom));
    });
  }
}
