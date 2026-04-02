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
import 'package:qavision/features/viewer/presentation/services/viewer_viewport_transform_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
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
    this.onRichTextPanelEditRequested,
    this.hiddenElementId,
    super.key,
  });

  /// Visual zoom applied to frame content only.
  final double contentZoom;

  /// Requests inline editing for a rich text panel.
  final ValueChanged<String>? onRichTextPanelEditRequested;

  /// Elemento que no debe pintarse porque se esta editando inline.
  final String? hiddenElementId;

  @override
  State<ViewerCanvas> createState() => _ViewerCanvasState();
}

class _ViewerCanvasState extends State<ViewerCanvas> {
  _DragMode _dragMode = _DragMode.none;
  String? _dragElementId;
  Offset _dragAnchor = Offset.zero;
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
            final state = context.read<ViewerBloc>().state;
            final hit = ViewerCanvasInteractionService.hitTest(
              state.frame,
              details.localPosition,
              zoom: widget.contentZoom,
            );
            if (hit is AnnotationElement &&
                hit.type == AnnotationType.richTextPanel) {
              context.read<ViewerBloc>().add(
                ViewerElementSelected(
                  elementId: hit.id,
                  centerImage: false,
                ),
              );
              widget.onRichTextPanelEditRequested?.call(hit.id);
              return;
            }
            unawaited(
              ViewerCanvasTextActions.handleDoubleTapDown(
                context: context,
                state: state,
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
                hiddenElementId: widget.hiddenElementId,
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
    final point = details.localPosition;

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

    if (_ensureEditableZoom(context, state)) {
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

    if (state.activeTool == AnnotationType.richTextPanel) {
      bloc.add(ViewerRichTextPanelAdded(point));
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
      final hit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        point,
        zoom: widget.contentZoom,
      );
      if (hit is AnnotationElement && hit.type == AnnotationType.stepMarker) {
        bloc.add(
          ViewerElementSelected(
            elementId: hit.id,
            centerImage: false,
          ),
        );
        return;
      }
      bloc.add(ViewerAnnotationStarted(point));
    }
  }

  void _onPanStart(
    BuildContext context,
    DragStartDetails details,
  ) {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    final displayPoint = details.localPosition;

    if (_ensureEditableZoom(context, state)) {
      return;
    }

    if (state.activeTool == AnnotationType.selection) {
      final selected = ViewerCanvasInteractionService.selectedElement(state);
      final selectedImage = selected is ImageFrameComponent ? selected : null;
      final topHit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        displayPoint,
        zoom: widget.contentZoom,
      );

      if (topHit is AnnotationElement) {
        final projectedTopHit = ViewerCompositionHelper.projectAnnotation(
          state.frame.elements,
          topHit,
          imageZoom: widget.contentZoom,
        );
        bloc.add(
          ViewerElementSelected(
            elementId: topHit.id,
            centerImage: false,
          ),
        );

        if (ViewerCanvasInteractionService.isOnResizeHandle(
          topHit,
          displayPoint,
          elements: state.frame.elements,
          zoom: widget.contentZoom,
        )) {
          final handle = ViewerCanvasInteractionService.hitTestElementResizeHandle(
            element: topHit,
            logicalPoint: displayPoint,
            elements: state.frame.elements,
            zoom: widget.contentZoom,
          );
          _dragMode = _DragMode.resizeElement;
          _dragElementId = topHit.id;
          _elementResizeStartPointer = displayPoint;
          _elementResizeStartRect =
              ViewerCanvasInteractionService.genericResizeBounds(
                topHit,
                elements: state.frame.elements,
                zoom: widget.contentZoom,
              );
          _imageResizeHandle = handle ?? ViewerImageResizeHandle.bottomRight;
          bloc.add(const ViewerInteractionStarted());
          return;
        }

        _dragMode = _DragMode.moveElement;
        _dragElementId = topHit.id;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        _dragAnchor = displayPoint - projectedTopHit.position;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      if (selectedImage != null) {
        final selectedImageHandle =
            ViewerCanvasInteractionService.hitTestFrameResizeHandles(
              logicalPoint: displayPoint,
              element: selectedImage,
              elements: state.frame.elements,
              zoom: widget.contentZoom,
            );
        if (selectedImageHandle != null &&
            selectedImageHandle != ViewerImageResizeHandle.none) {
          _dragMode = _DragMode.resizeElement;
          _dragElementId = selectedImage.id;
          _imageResizeHandle = selectedImageHandle;
          _elementResizeStartPointer = displayPoint;
          _elementResizeStartRect = ViewerCompositionHelper.imageFrameRect(
            selectedImage,
            elements: state.frame.elements,
            imageZoom: widget.contentZoom,
          );
          bloc.add(const ViewerInteractionStarted());
          return;
        }
        if (ViewerCanvasInteractionService.isInsideImageFrame(
          selectedImage,
          displayPoint,
          elements: state.frame.elements,
          zoom: widget.contentZoom,
        )) {
          _dragMode = _DragMode.moveElement;
          _dragElementId = selectedImage.id;
          _imageResizeHandle = ViewerImageResizeHandle.none;
          _dragAnchor =
              displayPoint -
              ViewerCompositionHelper.imageFrameRect(
                selectedImage,
                elements: state.frame.elements,
                imageZoom: widget.contentZoom,
              ).topLeft;
          bloc.add(const ViewerInteractionStarted());
          return;
        }
      }

      final topImageResizeHit =
          ViewerCanvasInteractionService.hitTopImageResizeHandle(
            state.frame,
            displayPoint,
            zoom: widget.contentZoom,
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
        _elementResizeStartPointer = displayPoint;
        _elementResizeStartRect = ViewerCompositionHelper.imageFrameRect(
          topImageResizeHit.element,
          elements: state.frame.elements,
          imageZoom: widget.contentZoom,
        );
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      final topImage = ViewerCanvasInteractionService.hitTopImageFrame(
        state.frame,
        displayPoint,
        zoom: widget.contentZoom,
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
        _dragAnchor =
            displayPoint -
            ViewerCompositionHelper.imageFrameRect(
              topImage,
              elements: state.frame.elements,
              imageZoom: widget.contentZoom,
            ).topLeft;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      final hit = topHit;
      bloc.add(
        ViewerElementSelected(
          elementId: hit?.id,
          centerImage: false,
        ),
      );
      if (hit == null) return;

      if (hit is ImageFrameComponent) {
        final handle = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
          logicalPoint: displayPoint,
          element: hit,
          elements: state.frame.elements,
          zoom: widget.contentZoom,
        );
        if (handle != null && handle != ViewerImageResizeHandle.none) {
          _dragMode = _DragMode.resizeElement;
          _dragElementId = hit.id;
          _imageResizeHandle = handle;
          _elementResizeStartPointer = displayPoint;
          _elementResizeStartRect = ViewerCompositionHelper.imageFrameRect(
            hit,
            elements: state.frame.elements,
            imageZoom: widget.contentZoom,
          );
          bloc.add(const ViewerInteractionStarted());
          return;
        }

        _dragMode = _DragMode.moveElement;
        _dragElementId = hit.id;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        _dragAnchor =
            displayPoint -
            ViewerCompositionHelper.imageFrameRect(
              hit,
              elements: state.frame.elements,
              imageZoom: widget.contentZoom,
            ).topLeft;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      if (ViewerCanvasInteractionService.isOnResizeHandle(
        hit,
        displayPoint,
        elements: state.frame.elements,
        zoom: widget.contentZoom,
      )) {
        final handle = ViewerCanvasInteractionService.hitTestElementResizeHandle(
          element: hit,
          logicalPoint: displayPoint,
          elements: state.frame.elements,
          zoom: widget.contentZoom,
        );
        _dragMode = _DragMode.resizeElement;
        _dragElementId = hit.id;
        _elementResizeStartPointer = displayPoint;
        _elementResizeStartRect =
            ViewerCanvasInteractionService.genericResizeBounds(
              hit,
              elements: state.frame.elements,
              zoom: widget.contentZoom,
            );
        _imageResizeHandle = handle ?? ViewerImageResizeHandle.bottomRight;
        bloc.add(const ViewerInteractionStarted());
        return;
      }

      _dragMode = _DragMode.moveElement;
      _dragElementId = hit.id;
      _imageResizeHandle = ViewerImageResizeHandle.none;
      final dragOrigin = hit is AnnotationElement
          ? ViewerCompositionHelper.projectAnnotation(
              state.frame.elements,
              hit,
              imageZoom: widget.contentZoom,
            ).position
          : hit.position;
      _dragAnchor = displayPoint - dragOrigin;
      bloc.add(const ViewerInteractionStarted());
      return;
    }

    if (state.activeTool == AnnotationType.text ||
        state.activeTool == AnnotationType.richTextPanel ||
        state.activeTool == AnnotationType.commentBubble ||
        state.activeTool == AnnotationType.eraser) {
      return;
    }

    if (state.activeTool == AnnotationType.stepMarker) {
      final hit = ViewerCanvasInteractionService.hitTest(
        state.frame,
        displayPoint,
        zoom: widget.contentZoom,
      );
      if (hit is AnnotationElement && hit.type == AnnotationType.stepMarker) {
        final projected = ViewerCompositionHelper.projectAnnotation(
          state.frame.elements,
          hit,
          imageZoom: widget.contentZoom,
        );
        bloc.add(
          ViewerElementSelected(
            elementId: hit.id,
            centerImage: false,
          ),
        );
        _dragMode = _DragMode.moveElement;
        _dragElementId = hit.id;
        _imageResizeHandle = ViewerImageResizeHandle.none;
        _dragAnchor = displayPoint - projected.position;
        bloc.add(const ViewerInteractionStarted());
      }
      return;
    }

    _dragMode = _DragMode.draw;
    bloc.add(ViewerAnnotationStarted(displayPoint));
  }

  void _onPanUpdate(
    BuildContext context,
    DragUpdateDetails details,
  ) {
    final bloc = context.read<ViewerBloc>();
    final state = bloc.state;
    final displayPoint = details.localPosition;
    final draggedElement = _dragElementId == null
        ? null
        : state.frame.elements
              .where((element) => element.id == _dragElementId)
              .firstOrNull;

    if (_dragMode == _DragMode.moveElement) {
      final id = _dragElementId;
      if (id != null) {
        if (draggedElement is ImageFrameComponent) {
          final displayTopLeft = displayPoint - _dragAnchor;
          final logicalTopLeft =
              ViewerCompositionHelper.logicalFrameTopLeftFromDisplayTopLeft(
                displayTopLeft: displayTopLeft,
                parentImageId: draggedElement.parentImageId,
                elements: state.frame.elements,
                imageZoom: widget.contentZoom,
              );
          bloc.add(
            ViewerElementMoved(
              elementId: id,
              position: logicalTopLeft,
            ),
          );
        } else {
          bloc.add(
            ViewerElementMoved(
              elementId: id,
              position: displayPoint - _dragAnchor,
            ),
          );
        }
      }
      return;
    }

    if (_dragMode == _DragMode.resizeElement) {
      final id = _dragElementId;
      if (id != null) {
        final delta = displayPoint - _elementResizeStartPointer;
        if (draggedElement is ImageFrameComponent &&
            _imageResizeHandle != ViewerImageResizeHandle.none) {
          final resizedDisplayRect =
              ViewerCanvasInteractionService.computeResizedRect(
                startRect: _elementResizeStartRect,
                delta: delta,
                handle: _imageResizeHandle,
                frameSize: state.frame.canvasSize,
              );
          final logicalRect =
              ViewerCompositionHelper.logicalFrameRectFromDisplayRect(
                displayRect: resizedDisplayRect,
                parentImageId: draggedElement.parentImageId,
                elements: state.frame.elements,
                imageZoom: widget.contentZoom,
              );
          bloc.add(
            ViewerElementResized(
              elementId: id,
              size: logicalRect.size,
              position: logicalRect.topLeft,
            ),
          );
          return;
        }

        final resizedDisplayRect =
            ViewerCanvasInteractionService.computeResizedRect(
              startRect: _elementResizeStartRect,
              delta: delta,
              handle: _imageResizeHandle == ViewerImageResizeHandle.none
                  ? ViewerImageResizeHandle.bottomRight
                  : _imageResizeHandle,
              frameSize: state.frame.canvasSize,
            );
        bloc.add(
          ViewerElementResized(
            elementId: id,
            size: resizedDisplayRect.size,
            position: resizedDisplayRect.topLeft,
          ),
        );
      }
      return;
    }

    if (_dragMode == _DragMode.draw && state.isDrawing) {
      bloc.add(ViewerAnnotationUpdated(displayPoint));
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
    _dragAnchor = Offset.zero;
    _elementResizeStartPointer = Offset.zero;
    _imageResizeHandle = ViewerImageResizeHandle.none;
    _elementResizeStartRect = Rect.zero;
  }

  bool _ensureEditableZoom(BuildContext context, ViewerState state) {
    if (state.canvasZoom >=
        ViewerViewportTransformService.defaultEditableMinZoom) {
      return false;
    }

    context.read<ViewerBloc>().add(
      const ViewerZoomChanged(
        ViewerViewportTransformService.defaultEditableMinZoom,
      ),
    );
    return true;
  }
}
