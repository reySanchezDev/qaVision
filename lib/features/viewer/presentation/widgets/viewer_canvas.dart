import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_canvas_interaction_service.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_canvas_text_actions.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas_painter.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_text_dialog.dart';

enum _DragMode {
  none,
  moveElement,
  resizeElement,
  draw,
}

/// Interactive composition canvas for viewer/editor.
class ViewerCanvas extends StatefulWidget {
  /// Creates [ViewerCanvas].
  const ViewerCanvas({
    this.contentZoom = 1,
    super.key,
  });

  /// Visual zoom applied to frame content only.
  final double contentZoom;

  @override
  State<ViewerCanvas> createState() => _ViewerCanvasState();
}

class _ViewerCanvasState extends State<ViewerCanvas> {
  _DragMode _dragMode = _DragMode.none;
  String? _dragElementId;
  Offset _dragAnchor = Offset.zero;
  Size _elementResizeStartSize = Size.zero;
  Offset _elementResizeStartPointer = Offset.zero;
  Rect _elementResizeStartRect = Rect.zero;
  ViewerImageResizeHandle _imageResizeHandle = ViewerImageResizeHandle.none;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (previous, current) =>
          previous.frame != current.frame ||
          previous.selectedElementId != current.selectedElementId ||
          previous.activeTool != current.activeTool,
      builder: (context, state) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            unawaited(_onTapDown(context, details));
          },
          onDoubleTapDown: (details) {
            unawaited(
              ViewerCanvasTextActions.handleDoubleTapDown(
                context: context,
                state: context.read<ViewerBloc>().state,
                details: details,
                contentZoom: widget.contentZoom,
              ),
            );
          },
          onPanStart: (details) => _onPanStart(context, details),
          onPanUpdate: (details) => _onPanUpdate(context, details),
          onPanEnd: (_) => _onPanEnd(context),
          child: SizedBox(
            width: state.frame.canvasSize.width,
            height: state.frame.canvasSize.height,
            child: CustomPaint(
              painter: ViewerCanvasPainter(
                frame: state.frame,
                selectedElementId: state.selectedElementId,
                contentZoom: widget.contentZoom,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onTapDown(
    BuildContext context,
    TapDownDetails details,
  ) async {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    final point = ViewerCanvasInteractionService.toLogicalPoint(
      point: details.localPosition,
      frameSize: state.frame.canvasSize,
      zoom: widget.contentZoom,
    );

    if (state.activeTool == AnnotationType.selection) {
      final hit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        point,
        zoom: widget.contentZoom,
      );
      bloc.add(
        ViewerElementSelected(
          elementId: hit?.id,
          centerImage: false,
        ),
      );
      return;
    }

    if (state.activeTool == AnnotationType.eraser) {
      final hit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        point,
        zoom: widget.contentZoom,
      );
      if (hit != null) {
        bloc.add(ViewerElementDeleted(elementId: hit.id));
      }
      return;
    }

    if (state.activeTool == AnnotationType.text ||
        state.activeTool == AnnotationType.commentBubble) {
      final text = await ViewerTextDialog.prompt(context);
      if (!context.mounted || text == null || text.trim().isEmpty) return;
      bloc.add(ViewerTextAdded(position: point, text: text.trim()));
      return;
    }

    if (state.activeTool == AnnotationType.stepMarker) {
      bloc.add(ViewerAnnotationStarted(point));
    }
  }

  void _onPanStart(
    BuildContext context,
    DragStartDetails details,
  ) {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    final point = ViewerCanvasInteractionService.toLogicalPoint(
      point: details.localPosition,
      frameSize: state.frame.canvasSize,
      zoom: widget.contentZoom,
    );

    if (state.activeTool == AnnotationType.selection) {
      final selected = ViewerCanvasInteractionService.selectedElement(state);
      final selectedImage = selected is ImageFrameComponent ? selected : null;

      // Prioriza siempre la imagen seleccionada para evitar intermitencia
      // cuando existen elementos superpuestos.
      if (selectedImage != null) {
        final selectedImageHandle =
            ViewerCanvasInteractionService.hitTestFrameResizeHandles(
              logicalPoint: point,
              element: selectedImage,
            );
        if (selectedImageHandle != null &&
            selectedImageHandle != ViewerImageResizeHandle.none) {
          _dragMode = _DragMode.resizeElement;
          _dragElementId = selectedImage.id;
          _imageResizeHandle = selectedImageHandle;
          _elementResizeStartPointer = point;
          _elementResizeStartSize = selectedImage.size;
          _elementResizeStartRect = selectedImage.position & selectedImage.size;
          bloc.add(const ViewerInteractionStarted());
          return;
        }
        if (ViewerCanvasInteractionService.isInsideImageFrame(
          selectedImage,
          point,
        )) {
          _dragMode = _DragMode.moveElement;
          _dragElementId = selectedImage.id;
          _imageResizeHandle = ViewerImageResizeHandle.none;
          _dragAnchor = point - selectedImage.position;
          bloc.add(const ViewerInteractionStarted());
          return;
        }
      }

      final topImageResizeHit =
          ViewerCanvasInteractionService.hitTopImageResizeHandle(
            state.frame,
            point,
          );
      if (topImageResizeHit != null) {
        bloc.add(
          ViewerElementSelected(
            elementId: topImageResizeHit.element.id,
            centerImage: false,
          ),
        );
        _dragMode = _DragMode.resizeElement;
        _dragElementId = topImageResizeHit.element.id;
        _imageResizeHandle = topImageResizeHit.handle;
        _elementResizeStartPointer = point;
        _elementResizeStartSize = topImageResizeHit.element.size;
        _elementResizeStartRect =
            topImageResizeHit.element.position & topImageResizeHit.element.size;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      final topImage = ViewerCanvasInteractionService.hitTopImageFrame(
        state.frame,
        point,
      );
      if (topImage != null) {
        bloc.add(
          ViewerElementSelected(
            elementId: topImage.id,
            centerImage: false,
          ),
        );
        _dragMode = _DragMode.moveElement;
        _dragElementId = topImage.id;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        _dragAnchor = point - topImage.position;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      final hit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        point,
        zoom: widget.contentZoom,
      );
      bloc.add(
        ViewerElementSelected(
          elementId: hit?.id,
          centerImage: false,
        ),
      );
      if (hit == null) return;

      if (hit is ImageFrameComponent) {
        final handle = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
          logicalPoint: point,
          element: hit,
        );
        if (handle != null && handle != ViewerImageResizeHandle.none) {
          _dragMode = _DragMode.resizeElement;
          _dragElementId = hit.id;
          _imageResizeHandle = handle;
          _elementResizeStartPointer = point;
          _elementResizeStartSize = hit.size;
          _elementResizeStartRect = hit.position & hit.size;
          bloc.add(const ViewerInteractionStarted());
          return;
        }

        _dragMode = _DragMode.moveElement;
        _dragElementId = hit.id;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        _dragAnchor = point - hit.position;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      if (ViewerCanvasInteractionService.isOnResizeHandle(hit, point)) {
        _dragMode = _DragMode.resizeElement;
        _dragElementId = hit.id;
        _elementResizeStartPointer = point;
        _elementResizeStartSize =
            ViewerCanvasInteractionService.selectionBounds(hit).size;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      _dragMode = _DragMode.moveElement;
      _dragElementId = hit.id;
      _imageResizeHandle = ViewerImageResizeHandle.none;
      _dragAnchor = point - hit.position;
      bloc.add(const ViewerInteractionStarted());
      return;
    }

    if (state.activeTool == AnnotationType.text ||
        state.activeTool == AnnotationType.commentBubble ||
        state.activeTool == AnnotationType.eraser ||
        state.activeTool == AnnotationType.stepMarker) {
      return;
    }

    _dragMode = _DragMode.draw;
    bloc.add(ViewerAnnotationStarted(point));
  }

  void _onPanUpdate(
    BuildContext context,
    DragUpdateDetails details,
  ) {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    final point = ViewerCanvasInteractionService.toLogicalPoint(
      point: details.localPosition,
      frameSize: state.frame.canvasSize,
      zoom: widget.contentZoom,
    );

    if (_dragMode == _DragMode.moveElement) {
      final id = _dragElementId;
      if (id != null) {
        bloc.add(
          ViewerElementMoved(
            elementId: id,
            position: point - _dragAnchor,
          ),
        );
      }
      return;
    }

    if (_dragMode == _DragMode.resizeElement) {
      final id = _dragElementId;
      if (id != null) {
        final delta = point - _elementResizeStartPointer;
        if (_imageResizeHandle != ViewerImageResizeHandle.none) {
          final resizedRect = ViewerCanvasInteractionService.computeResizedRect(
            startRect: _elementResizeStartRect,
            delta: delta,
            handle: _imageResizeHandle,
            frameSize: state.frame.canvasSize,
          );
          bloc.add(
            ViewerElementResized(
              elementId: id,
              size: resizedRect.size,
              position: resizedRect.topLeft,
            ),
          );
          return;
        }

        final newSize = ViewerCanvasInteractionService.computeGenericResizeSize(
          startSize: _elementResizeStartSize,
          delta: delta,
        );
        bloc.add(ViewerElementResized(elementId: id, size: newSize));
      }
      return;
    }

    if (_dragMode == _DragMode.draw && state.isDrawing) {
      bloc.add(ViewerAnnotationUpdated(point));
    }
  }

  void _onPanEnd(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    if (_dragMode == _DragMode.draw && state.isDrawing) {
      bloc.add(const ViewerAnnotationFinished());
    } else if (_dragMode == _DragMode.moveElement ||
        _dragMode == _DragMode.resizeElement) {
      bloc.add(const ViewerInteractionFinished());
    }

    _dragMode = _DragMode.none;
    _dragElementId = null;
    _imageResizeHandle = ViewerImageResizeHandle.none;
    _elementResizeStartRect = Rect.zero;
  }
}
