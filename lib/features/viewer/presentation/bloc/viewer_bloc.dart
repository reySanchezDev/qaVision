import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/image_frame_component_service.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';
import 'package:uuid/uuid.dart';

/// State manager for capture viewer/editor.
class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  /// Creates [ViewerBloc].
  ViewerBloc({
    required FileSystemService fileSystemService,
    required ClipboardService clipboardService,
    required ShareService shareService,
  }) : _fileSystemService = fileSystemService,
       _clipboardService = clipboardService,
       _shareService = shareService,
       super(const ViewerState()) {
    on<ViewerStarted>(_onStarted);
    on<ViewerToolChanged>(_onToolChanged);
    on<ViewerPropertiesChanged>(_onPropertiesChanged);
    on<ViewerBackgroundColorChanged>(_onBackgroundColorChanged);
    on<ViewerCanvasResized>(_onCanvasResized);
    on<ViewerZoomChanged>(_onZoomChanged);
    on<ViewerAnnotationStarted>(_onAnnotationStarted);
    on<ViewerAnnotationUpdated>(_onAnnotationUpdated);
    on<ViewerAnnotationFinished>(_onAnnotationFinished);
    on<ViewerTextAdded>(_onTextAdded);
    on<ViewerImageAdded>(_onImageAdded);
    on<ViewerElementSelected>(_onElementSelected);
    on<ViewerElementMoved>(_onElementMoved);
    on<ViewerImageContentMoved>(_onImageContentMoved);
    on<ViewerElementResized>(_onElementResized);
    on<ViewerElementDeleted>(_onElementDeleted);
    on<ViewerElementZOrderChanged>(_onElementZOrderChanged);
    on<ViewerInteractionStarted>(_onInteractionStarted);
    on<ViewerInteractionFinished>(_onInteractionFinished);
    on<ViewerUndoRequested>(_onUndoRequested);
    on<ViewerRedoRequested>(_onRedoRequested);
    on<ViewerRecentCapturesRequested>(_onRecentCapturesRequested);
    on<ViewerRecentCapturesReordered>(_onRecentCapturesReordered);
    on<ViewerSelectedElementTextUpdated>(_onSelectedElementTextUpdated);
    on<ViewerSelectedFrameStyleChanged>(_onSelectedFrameStyleChanged);
    on<ViewerExportRequested>(_onExportRequested);
    on<ViewerCopyRequested>(_onCopyRequested);
    on<ViewerShareRequested>(_onShareRequested);
    if (_autoSaveEnabled) {
      on<ViewerAutoSaveRequested>(_onAutoSaveRequested);
    }
  }

  final FileSystemService _fileSystemService;
  final ClipboardService _clipboardService;
  final ShareService _shareService;
  static const _uuid = Uuid();
  static const bool _autoSaveEnabled = false;
  static const int _defaultFrameBackgroundColor = 0xFFFFFFFF;
  static const double _defaultFrameBackgroundOpacity = 1;
  static const int _defaultFrameBorderColor = 0x33000000;
  static const double _defaultFrameBorderWidth = 1;
  static const double _defaultFramePadding = 0;

  Timer? _autoSaveTimer;
  bool _autoSaveInProgress = false;
  bool _autoSaveQueued = false;
  FrameState? _drawingStartFrame;
  FrameState? _interactionStartFrame;
  String? _activeImagePath;
  String? _projectPath;

  _ImageFrameDefaults _resolveDefaultsFromStart(ViewerStarted event) {
    return _ImageFrameDefaults(
      backgroundColor:
          event.defaultFrameBackgroundColor ?? _defaultFrameBackgroundColor,
      backgroundOpacity:
          (event.defaultFrameBackgroundOpacity ??
                  _defaultFrameBackgroundOpacity)
              .clamp(0.0, 1.0),
      borderColor: event.defaultFrameBorderColor ?? _defaultFrameBorderColor,
      borderWidth: (event.defaultFrameBorderWidth ?? _defaultFrameBorderWidth)
          .clamp(0.0, 20.0),
      padding: (event.defaultFramePadding ?? _defaultFramePadding).clamp(
        0.0,
        300.0,
      ),
    );
  }

  _ImageFrameDefaults _resolveDefaultsFromInsert(ViewerImageAdded event) {
    return _ImageFrameDefaults(
      backgroundColor:
          event.defaultFrameBackgroundColor ?? _defaultFrameBackgroundColor,
      backgroundOpacity:
          (event.defaultFrameBackgroundOpacity ??
                  _defaultFrameBackgroundOpacity)
              .clamp(0.0, 1.0),
      borderColor: event.defaultFrameBorderColor ?? _defaultFrameBorderColor,
      borderWidth: (event.defaultFrameBorderWidth ?? _defaultFrameBorderWidth)
          .clamp(0.0, 20.0),
      padding: (event.defaultFramePadding ?? _defaultFramePadding).clamp(
        0.0,
        300.0,
      ),
    );
  }

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
      ),
    );

    try {
      _activeImagePath = event.imagePath;
      _projectPath = io.File(event.imagePath).parent.path;
      final defaults = _resolveDefaultsFromStart(event);

      final loadedFrame = await _loadFrameForImage(
        event.imagePath,
        defaults: defaults,
      );
      final selectedImageId = loadedFrame.elements
          .whereType<ImageFrameComponent>()
          .firstOrNull
          ?.id;
      final recentCaptures = await _fileSystemService.listJpgFiles(
        _projectPath!,
      );

      _disposeImageFrames([
        state.frame,
        ...state.undoStack,
        ...state.redoStack,
      ]);

      emit(
        state.copyWith(
          frame: loadedFrame,
          activeTool: AnnotationType.selection,
          undoStack: const [],
          redoStack: const [],
          selectedElementId: selectedImageId,
          clearSelectedElement: selectedImageId == null,
          recentCaptures: recentCaptures,
          recentProjectPath: _projectPath,
          isLoading: false,
          clearAutoSavePath: true,
          clearErrorMessage: true,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          clearRecentProjectPath: true,
          errorMessage: 'Error al cargar el visor: $e',
        ),
      );
    }
  }

  void _onToolChanged(ViewerToolChanged event, Emitter<ViewerState> emit) {
    emit(
      state.copyWith(
        activeTool: event.tool,
        clearSelectedElement: event.tool != AnnotationType.selection,
      ),
    );
  }

  void _onPropertiesChanged(
    ViewerPropertiesChanged event,
    Emitter<ViewerState> emit,
  ) {
    final selectedId = state.selectedElementId;
    if (selectedId != null) {
      final elements = List<CanvasElement>.from(state.frame.elements);
      final index = elements.indexWhere((e) => e.id == selectedId);
      if (index != -1 && elements[index] is AnnotationElement) {
        final annotation = elements[index] as AnnotationElement;
        elements[index] = annotation.copyWith(
          color: event.color ?? annotation.color,
          strokeWidth: event.strokeWidth ?? annotation.strokeWidth,
          textSize: event.textSize ?? annotation.textSize,
          opacity: event.opacity ?? annotation.opacity,
        );

        final undoStack = List<FrameState>.from(state.undoStack)
          ..add(state.frame);
        emit(
          state.copyWith(
            frame: state.frame.copyWith(elements: elements),
            undoStack: undoStack,
            redoStack: const [],
            activeColor: event.color ?? state.activeColor,
            activeStrokeWidth: event.strokeWidth ?? state.activeStrokeWidth,
            activeTextSize: event.textSize ?? state.activeTextSize,
            activeOpacity: event.opacity ?? state.activeOpacity,
            selectedElementId: selectedId,
          ),
        );
        _scheduleAutoSave();
        return;
      }
    }

    emit(
      state.copyWith(
        activeColor: event.color ?? state.activeColor,
        activeStrokeWidth: event.strokeWidth ?? state.activeStrokeWidth,
        activeTextSize: event.textSize ?? state.activeTextSize,
        activeOpacity: event.opacity ?? state.activeOpacity,
      ),
    );
  }

  void _onBackgroundColorChanged(
    ViewerBackgroundColorChanged event,
    Emitter<ViewerState> emit,
  ) {
    final updated = state.frame.copyWith(backgroundColor: event.color);
    _commitFrame(
      emit,
      frame: updated,
      pushUndo: true,
      undoSnapshot: state.frame,
    );
  }

  void _onCanvasResized(ViewerCanvasResized event, Emitter<ViewerState> emit) {
    final width = event.size.width.clamp(320, 12000).toDouble();
    final height = event.size.height.clamp(220, 12000).toDouble();
    final resizedFrame = state.frame.copyWith(canvasSize: Size(width, height));
    final constrainedFrame = _constrainImagesToCanvas(
      resizedFrame,
      zoom: state.canvasZoom,
    );
    emit(
      state.copyWith(
        frame: constrainedFrame,
      ),
    );
  }

  void _onZoomChanged(ViewerZoomChanged event, Emitter<ViewerState> emit) {
    final nextZoom = event.zoom.clamp(0.1, 3.0);
    if ((nextZoom - state.canvasZoom).abs() < 0.001) {
      return;
    }
    emit(
      state.copyWith(
        canvasZoom: nextZoom,
      ),
    );
  }

  void _onAnnotationStarted(
    ViewerAnnotationStarted event,
    Emitter<ViewerState> emit,
  ) {
    final tool = state.activeTool;
    if (tool == AnnotationType.selection ||
        tool == AnnotationType.text ||
        tool == AnnotationType.commentBubble ||
        tool == AnnotationType.eraser) {
      return;
    }

    final attachedImageId = _findTopImageIdAtPoint(
      state.frame.elements,
      event.position,
      imageZoom: state.canvasZoom,
    );
    final coordinateSpace = _annotationCoordinateSpaceForAttachment(
      attachedImageId,
    );

    if (tool == AnnotationType.stepMarker) {
      final counter = state.frame.elements
          .whereType<AnnotationElement>()
          .where((e) => e.type == AnnotationType.stepMarker)
          .length;
      final marker = AnnotationElement(
        id: _uuid.v4(),
        type: AnnotationType.stepMarker,
        color: state.activeColor,
        strokeWidth: state.activeStrokeWidth,
        textSize: state.activeTextSize,
        position: _storeAnnotationPoint(
          state.frame.elements,
          attachedImageId: attachedImageId,
          coordinateSpace: coordinateSpace,
          canvasPoint: event.position,
        ),
        text: '${counter + 1}',
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        zIndex: _nextZ(state.frame.elements),
      );
      final elements = List<CanvasElement>.from(state.frame.elements)
        ..add(marker);
      _commitFrame(
        emit,
        frame: state.frame.copyWith(elements: _normalizeZ(elements)),
        pushUndo: true,
        undoSnapshot: state.frame,
        selectedElementId: marker.id,
      );
      return;
    }

    _drawingStartFrame = state.frame;
    final newAnnotation = AnnotationElement(
      id: _uuid.v4(),
      type: tool,
      color: state.activeColor,
      strokeWidth: state.activeStrokeWidth,
      textSize: state.activeTextSize,
      opacity: tool == AnnotationType.highlighter || tool == AnnotationType.blur
          ? state.activeOpacity
          : 1,
      position: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: event.position,
      ),
      endPosition: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: event.position,
      ),
      points: [
        _storeAnnotationPoint(
          state.frame.elements,
          attachedImageId: attachedImageId,
          coordinateSpace: coordinateSpace,
          canvasPoint: event.position,
        ),
      ],
      attachedImageId: attachedImageId,
      coordinateSpace: coordinateSpace,
      zIndex: _nextZ(state.frame.elements),
    );

    final elements = List<CanvasElement>.from(state.frame.elements)
      ..add(newAnnotation);

    emit(
      state.copyWith(
        frame: state.frame.copyWith(elements: _normalizeZ(elements)),
        isDrawing: true,
        selectedElementId: newAnnotation.id,
      ),
    );
  }

  void _onAnnotationUpdated(
    ViewerAnnotationUpdated event,
    Emitter<ViewerState> emit,
  ) {
    if (!state.isDrawing || state.frame.elements.isEmpty) return;

    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.length - 1;
    final last = elements[index];
    if (last is! AnnotationElement) return;

    AnnotationElement updated;
    if (last.type == AnnotationType.pencil) {
      updated = last.copyWith(
        points: [
          ...last.points,
          _storeAnnotationPoint(
            state.frame.elements,
            attachedImageId: last.attachedImageId,
            coordinateSpace: last.coordinateSpace,
            canvasPoint: event.position,
          ),
        ],
      );
    } else {
      updated = last.copyWith(
        endPosition: _storeAnnotationPoint(
          state.frame.elements,
          attachedImageId: last.attachedImageId,
          coordinateSpace: last.coordinateSpace,
          canvasPoint: event.position,
        ),
      );
    }

    elements[index] = updated;
    emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
  }

  void _onAnnotationFinished(
    ViewerAnnotationFinished event,
    Emitter<ViewerState> emit,
  ) {
    if (!state.isDrawing) return;

    final undoSnapshot = _drawingStartFrame ?? state.frame;
    _drawingStartFrame = null;

    _commitFrame(
      emit,
      frame: state.frame,
      pushUndo: true,
      undoSnapshot: undoSnapshot,
    );
  }

  void _onTextAdded(ViewerTextAdded event, Emitter<ViewerState> emit) {
    final text = event.text.trim();
    if (text.isEmpty) return;
    final attachedImageId = _findTopImageIdAtPoint(
      state.frame.elements,
      event.position,
      imageZoom: state.canvasZoom,
    );
    final coordinateSpace = _annotationCoordinateSpaceForAttachment(
      attachedImageId,
    );

    final type = state.activeTool == AnnotationType.commentBubble
        ? AnnotationType.commentBubble
        : AnnotationType.text;
    final annotation = AnnotationElement(
      id: _uuid.v4(),
      type: type,
      color: state.activeColor,
      strokeWidth: state.activeStrokeWidth,
      textSize: state.activeTextSize,
      position: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: event.position,
      ),
      text: text,
      attachedImageId: attachedImageId,
      coordinateSpace: coordinateSpace,
      zIndex: _nextZ(state.frame.elements),
    );

    final elements = List<CanvasElement>.from(state.frame.elements)
      ..add(annotation);
    _commitFrame(
      emit,
      frame: state.frame.copyWith(elements: _normalizeZ(elements)),
      pushUndo: true,
      undoSnapshot: state.frame,
      selectedElementId: annotation.id,
      activeTool: AnnotationType.selection,
    );
  }

  Future<void> _onImageAdded(
    ViewerImageAdded event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final defaults = _resolveDefaultsFromInsert(event);
      final image = await _loadImage(event.imagePath);
      final rawSize = Size(image.width.toDouble(), image.height.toDouble());
      final insertionParent = _resolveInsertionParentImage(state.frame);
      final movementBounds = _movementBoundsForNewImage(
        frame: state.frame,
        parent: insertionParent,
      );
      final availableWorkspaceSize = Size(
        movementBounds.width / state.canvasZoom,
        movementBounds.height / state.canvasZoom,
      );
      final fittedSize = ImageFrameComponentService.fitImageInsideFrame(
        rawSize,
        availableWorkspaceSize,
      );
      final proposedPosition =
          event.position ??
          Offset(
            movementBounds.left + 24.0 * _countNestedImages(state.frame),
            movementBounds.top + 24.0 * _countNestedImages(state.frame),
          );
      final added = ImageFrameComponentService.constrainToCanvas(
        component: ImageFrameComponent(
          id: _uuid.v4(),
          position: proposedPosition,
          zIndex: _nextZ(state.frame.elements),
          path: event.imagePath,
          contentSize: fittedSize,
          style: ImageFrameStyle(
            backgroundColor: defaults.backgroundColor,
            backgroundOpacity: defaults.backgroundOpacity,
            borderColor: defaults.borderColor,
            borderWidth: defaults.borderWidth,
            padding: defaults.padding,
          ),
          transform: ImageFrameTransform(
            position: proposedPosition,
            size: fittedSize,
          ),
          image: image,
          parentImageId: insertionParent?.id,
        ),
        frameSize: state.frame.canvasSize,
        movementBounds: movementBounds,
        displayScale: state.canvasZoom,
      );
      final elements = List<CanvasElement>.from(state.frame.elements)
        ..add(added);

      _commitFrame(
        emit,
        frame: state.frame.copyWith(elements: _normalizeZ(elements)),
        pushUndo: true,
        undoSnapshot: state.frame,
        selectedElementId: added.id,
        isLoading: false,
        activeTool: AnnotationType.selection,
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'No se pudo agregar imagen: $e',
        ),
      );
    }
  }

  void _onElementSelected(
    ViewerElementSelected event,
    Emitter<ViewerState> emit,
  ) {
    final selectedId = event.elementId;
    if (selectedId == null) {
      emit(state.copyWith(clearSelectedElement: true));
      return;
    }

    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((element) => element.id == selectedId);
    if (index < 0) {
      emit(state.copyWith(clearSelectedElement: true));
      return;
    }

    final selected = elements[index];
    if (selected is ImageFrameComponent && event.centerImage) {
      final workspaceRect = _movementBoundsForImage(
        elements,
        selected,
      );
      final centeredComponent = ImageFrameComponentService.move(
        component: selected,
        position: _centerPositionForSize(
          selected.size,
          workspaceRect,
          displayScale: state.canvasZoom,
        ),
        frameSize: state.frame.canvasSize,
        movementBounds: workspaceRect,
        displayScale: state.canvasZoom,
      );
      final delta = centeredComponent.position - selected.position;
      if (delta != Offset.zero) {
        elements[index] = centeredComponent;
        _translateImageDependents(
          elements,
          imageId: selected.id,
          delta: delta,
        );
        _constrainImageChildren(
          elements,
          parentId: selected.id,
          canvasSize: state.frame.canvasSize,
          zoom: state.canvasZoom,
        );
        emit(
          state.copyWith(
            frame: state.frame.copyWith(elements: elements),
            selectedElementId: selectedId,
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        selectedElementId: selectedId,
      ),
    );
  }

  void _onElementMoved(ViewerElementMoved event, Emitter<ViewerState> emit) {
    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == event.elementId);
    if (index == -1) return;

    final element = elements[index];
    if (element is ImageFrameComponent) {
      final movementBounds = _movementBoundsForImage(
        elements,
        element,
      );
      final movedComponent = ImageFrameComponentService.move(
        component: element,
        position: event.position,
        frameSize: state.frame.canvasSize,
        movementBounds: movementBounds,
        displayScale: state.canvasZoom,
      );
      final delta = movedComponent.position - element.position;
      elements[index] = movedComponent;

      if (delta != Offset.zero) {
        _translateImageDependents(
          elements,
          imageId: element.id,
          delta: delta,
        );
        _constrainImageChildren(
          elements,
          parentId: element.id,
          canvasSize: state.frame.canvasSize,
          zoom: state.canvasZoom,
        );
      }
    } else if (element is AnnotationElement) {
      final movementBounds = _movementBoundsForAnnotation(
        elements,
        element,
      );
      final clampedPosition = _clampPointToBounds(
        event.position,
        movementBounds,
      );
      final projected = _projectAnnotationForDisplay(
        elements,
        element,
      );
      final delta = clampedPosition - projected.position;
      final movedProjected = projected.copyWith(
        position: clampedPosition,
        points: projected.points
            .map((point) => point + delta)
            .toList(growable: false),
        endPosition: projected.endPosition == null
            ? null
            : projected.endPosition! + delta,
      );
      elements[index] = _storeProjectedAnnotation(
        elements,
        source: element,
        projected: movedProjected,
      );
    }

    emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
  }

  void _onImageContentMoved(
    ViewerImageContentMoved event,
    Emitter<ViewerState> emit,
  ) {
    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere(
      (element) => element.id == event.elementId,
    );
    if (index < 0) return;
    final element = elements[index];
    if (element is! ImageFrameComponent) return;

    final updated = ImageFrameComponentService.moveContent(
      component: element,
      proposedOffset: event.contentOffset,
    );
    elements[index] = updated;
    emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
  }

  void _onElementResized(
    ViewerElementResized event,
    Emitter<ViewerState> emit,
  ) {
    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == event.elementId);
    if (index == -1) return;

    final element = elements[index];
    final width = event.size.width.clamp(8, 8000).toDouble();
    final height = event.size.height.clamp(8, 8000).toDouble();

    if (element is ImageFrameComponent) {
      final movementBounds = _movementBoundsForImage(
        elements,
        element,
      );
      final resizedComponent = ImageFrameComponentService.resize(
        component: element,
        size: Size(width, height),
        position: event.position,
        frameSize: state.frame.canvasSize,
        movementBounds: movementBounds,
        displayScale: state.canvasZoom,
      );
      final delta = resizedComponent.position - element.position;
      elements[index] = resizedComponent;

      if (delta != Offset.zero) {
        _translateImageDependents(
          elements,
          imageId: element.id,
          delta: delta,
        );
      }
      _constrainImageChildren(
        elements,
        parentId: element.id,
        canvasSize: state.frame.canvasSize,
        zoom: state.canvasZoom,
      );
    } else if (element is AnnotationElement) {
      final projected = _projectAnnotationForDisplay(
        elements,
        element,
      );
      if (element.type == AnnotationType.text ||
          element.type == AnnotationType.commentBubble) {
        final oldBounds = ViewerCompositionHelper.annotationBounds(
          projected,
        );
        final ratio = oldBounds.width <= 1 ? 1.0 : width / oldBounds.width;
        final textSize = (element.textSize * ratio).clamp(10, 120).toDouble();
        elements[index] = element.copyWith(textSize: textSize);
      } else if (element.type == AnnotationType.pencil &&
          element.points.isNotEmpty) {
        final oldBounds = ViewerCompositionHelper.annotationBounds(projected);
        final sx = oldBounds.width <= 1 ? 1.0 : width / oldBounds.width;
        final sy = oldBounds.height <= 1 ? 1.0 : height / oldBounds.height;
        final transformed = projected.points
            .map(
              (point) => Offset(
                projected.position.dx + (point.dx - oldBounds.left) * sx,
                projected.position.dy + (point.dy - oldBounds.top) * sy,
              ),
            )
            .toList(growable: false);
        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            points: transformed,
            clearEndPosition: true,
          ),
        );
      } else {
        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            endPosition: projected.position + Offset(width, height),
          ),
        );
      }
    } else {
      return;
    }

    emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
  }

  void _onElementDeleted(
    ViewerElementDeleted event,
    Emitter<ViewerState> emit,
  ) {
    final target = state.frame.elements
        .where((element) => element.id == event.elementId)
        .firstOrNull;
    final elements = List<CanvasElement>.from(state.frame.elements)
      ..removeWhere((element) => element.id == event.elementId);

    if (target is ImageFrameComponent) {
      final descendantIds = _collectDescendantImageIds(
        state.frame.elements,
        target.id,
      );
      elements.removeWhere(
        (element) =>
            (element is AnnotationElement &&
                (element.attachedImageId == target.id ||
                    descendantIds.contains(element.attachedImageId))) ||
            (element is ImageFrameComponent &&
                descendantIds.contains(element.id)),
      );
    }

    _commitFrame(
      emit,
      frame: state.frame.copyWith(elements: _normalizeZ(elements)),
      pushUndo: true,
      undoSnapshot: state.frame,
      clearSelectedElement: state.selectedElementId == event.elementId,
    );
  }

  void _onElementZOrderChanged(
    ViewerElementZOrderChanged event,
    Emitter<ViewerState> emit,
  ) {
    final source = List<CanvasElement>.from(state.frame.elements);
    final target = source
        .where((element) => element.id == event.elementId)
        .firstOrNull;
    if (target == null) return;

    if (target is ImageFrameComponent) {
      final images = source.whereType<ImageFrameComponent>().toList(
        growable: false,
      )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final annotations = source.whereType<AnnotationElement>().toList(
        growable: false,
      )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final index = images.indexWhere((image) => image.id == target.id);
      if (index < 0) return;
      final nextIndex = event.isForward ? index + 1 : index - 1;
      if (nextIndex < 0 || nextIndex >= images.length) return;

      final mutable = List<ImageFrameComponent>.from(images);
      final moving = mutable.removeAt(index);
      mutable.insert(nextIndex, moving);

      final list = <CanvasElement>[...mutable, ...annotations];
      _commitFrame(
        emit,
        frame: state.frame.copyWith(elements: _normalizeZ(list)),
        pushUndo: true,
        undoSnapshot: state.frame,
        selectedElementId: event.elementId,
      );
      return;
    }

    if (target is AnnotationElement) {
      final images = source.whereType<ImageFrameComponent>().toList(
        growable: false,
      )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final annotations = source.whereType<AnnotationElement>().toList(
        growable: false,
      )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final index = annotations.indexWhere((item) => item.id == target.id);
      if (index < 0) return;
      final nextIndex = event.isForward ? index + 1 : index - 1;
      if (nextIndex < 0 || nextIndex >= annotations.length) return;

      final mutable = List<AnnotationElement>.from(annotations);
      final moving = mutable.removeAt(index);
      mutable.insert(nextIndex, moving);

      final list = <CanvasElement>[...images, ...mutable];
      _commitFrame(
        emit,
        frame: state.frame.copyWith(elements: _normalizeZ(list)),
        pushUndo: true,
        undoSnapshot: state.frame,
        selectedElementId: event.elementId,
      );
      return;
    }

    return;
  }

  void _onInteractionStarted(
    ViewerInteractionStarted event,
    Emitter<ViewerState> emit,
  ) {
    _interactionStartFrame ??= state.frame;
  }

  void _onInteractionFinished(
    ViewerInteractionFinished event,
    Emitter<ViewerState> emit,
  ) {
    final snapshot = _interactionStartFrame;
    _interactionStartFrame = null;
    if (snapshot == null || identical(snapshot, state.frame)) {
      return;
    }

    final undoStack = List<FrameState>.from(state.undoStack)..add(snapshot);
    emit(
      state.copyWith(
        undoStack: undoStack,
        redoStack: const [],
      ),
    );
    _scheduleAutoSave();
  }

  void _onUndoRequested(ViewerUndoRequested event, Emitter<ViewerState> emit) {
    if (state.undoStack.isEmpty) return;

    final previous = state.undoStack.last;
    final undoStack = List<FrameState>.from(state.undoStack)..removeLast();
    final redoStack = List<FrameState>.from(state.redoStack)..add(state.frame);
    emit(
      state.copyWith(
        frame: previous,
        undoStack: undoStack,
        redoStack: redoStack,
        clearSelectedElement: true,
      ),
    );
    _scheduleAutoSave();
  }

  void _onRedoRequested(ViewerRedoRequested event, Emitter<ViewerState> emit) {
    if (state.redoStack.isEmpty) return;

    final next = state.redoStack.last;
    final redoStack = List<FrameState>.from(state.redoStack)..removeLast();
    final undoStack = List<FrameState>.from(state.undoStack)..add(state.frame);
    emit(
      state.copyWith(
        frame: next,
        undoStack: undoStack,
        redoStack: redoStack,
        clearSelectedElement: true,
      ),
    );
    _scheduleAutoSave();
  }

  Future<void> _onRecentCapturesRequested(
    ViewerRecentCapturesRequested event,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final captures = await _fileSystemService.listJpgFiles(event.projectPath);
      emit(
        state.copyWith(
          recentCaptures: captures,
          recentProjectPath: event.projectPath,
        ),
      );
    } on Exception {
      // Keep previous list when refresh fails.
    }
  }

  void _onRecentCapturesReordered(
    ViewerRecentCapturesReordered event,
    Emitter<ViewerState> emit,
  ) {
    final list = List<String>.from(state.recentCaptures);
    if (event.oldIndex < 0 ||
        event.oldIndex >= list.length ||
        event.newIndex < 0 ||
        event.newIndex > list.length) {
      return;
    }

    var targetIndex = event.newIndex;
    if (targetIndex > event.oldIndex) {
      targetIndex -= 1;
    }
    final item = list.removeAt(event.oldIndex);
    list.insert(targetIndex, item);
    emit(state.copyWith(recentCaptures: list));
  }

  void _onSelectedElementTextUpdated(
    ViewerSelectedElementTextUpdated event,
    Emitter<ViewerState> emit,
  ) {
    final selectedId = state.selectedElementId;
    if (selectedId == null) return;

    final trimmed = event.text.trim();
    if (trimmed.isEmpty) return;

    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == selectedId);
    if (index == -1) return;

    final element = elements[index];
    if (element is! AnnotationElement) return;
    if (element.type != AnnotationType.text &&
        element.type != AnnotationType.commentBubble &&
        element.type != AnnotationType.stepMarker) {
      return;
    }

    elements[index] = element.copyWith(text: trimmed);
    _commitFrame(
      emit,
      frame: state.frame.copyWith(elements: elements),
      pushUndo: true,
      undoSnapshot: state.frame,
      selectedElementId: selectedId,
    );
  }

  void _onSelectedFrameStyleChanged(
    ViewerSelectedFrameStyleChanged event,
    Emitter<ViewerState> emit,
  ) {
    final selectedId = state.selectedElementId;
    if (selectedId == null) return;

    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((element) => element.id == selectedId);
    if (index < 0) return;

    final selected = elements[index];
    if (selected is! ImageFrameComponent) return;

    final selectedComponent = selected;
    var nextPadding = (event.framePadding ?? selectedComponent.style.padding)
        .clamp(
          0.0,
          300.0,
        );
    nextPadding = ImageFrameComponentService.clampPaddingToFrame(
      nextPadding,
      selectedComponent.size,
    );

    final styledComponent = selectedComponent.copyWith(
      style: selectedComponent.style.copyWith(
        backgroundColor:
            event.frameBackgroundColor ??
            selectedComponent.style.backgroundColor,
        backgroundOpacity:
            (event.frameBackgroundOpacity ??
                    selectedComponent.style.backgroundOpacity)
                .clamp(0.0, 1.0),
        borderColor:
            event.frameBorderColor ?? selectedComponent.style.borderColor,
        borderWidth:
            (event.frameBorderWidth ?? selectedComponent.style.borderWidth)
                .clamp(0.0, 20.0),
        padding: nextPadding,
      ),
    );
    elements[index] = ImageFrameComponentService.moveContent(
      component: styledComponent,
      proposedOffset: styledComponent.contentOffset,
    );
    _constrainImageChildren(
      elements,
      parentId: selectedId,
      canvasSize: state.frame.canvasSize,
      zoom: state.canvasZoom,
    );

    _commitFrame(
      emit,
      frame: state.frame.copyWith(elements: elements),
      pushUndo: true,
      undoSnapshot: state.frame,
      selectedElementId: selectedId,
    );
  }

  Future<void> _onExportRequested(
    ViewerExportRequested event,
    Emitter<ViewerState> emit,
  ) async {
    await _saveComposition(emit, forceRefreshRecent: true);
  }

  Future<void> _onCopyRequested(
    ViewerCopyRequested event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final bytes = await _generateCompositionBytes(state.frame);
      await _clipboardService.copyImageToClipboard(bytes);
      emit(state.copyWith(isLoading: false));
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error al copiar imagen: $e',
        ),
      );
    }
  }

  Future<void> _onShareRequested(
    ViewerShareRequested event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final bytes = await _generateCompositionBytes(state.frame);
      await _shareService.shareImageBytes(
        bytes,
        'qavision_composicion.jpg',
        text: 'Composicion generada por QAVision',
      );
      emit(state.copyWith(isLoading: false));
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error al compartir imagen: $e',
        ),
      );
    }
  }

  Future<void> _onAutoSaveRequested(
    ViewerAutoSaveRequested event,
    Emitter<ViewerState> emit,
  ) async {
    if (!_autoSaveEnabled) return;
    if (_autoSaveInProgress) {
      _autoSaveQueued = true;
      return;
    }
    _autoSaveInProgress = true;

    await _saveComposition(emit, forceRefreshRecent: false);

    _autoSaveInProgress = false;
    if (_autoSaveQueued && !isClosed) {
      _autoSaveQueued = false;
      add(const ViewerAutoSaveRequested());
    } else {
      _autoSaveQueued = false;
    }
  }

  void _commitFrame(
    Emitter<ViewerState> emit, {
    required FrameState frame,
    bool pushUndo = false,
    FrameState? undoSnapshot,
    String? selectedElementId,
    bool clearSelectedElement = false,
    bool isDrawing = false,
    bool? isLoading,
    AnnotationType? activeTool,
  }) {
    final undoStack = pushUndo
        ? (List<FrameState>.from(state.undoStack)
            ..add(undoSnapshot ?? state.frame))
        : state.undoStack;
    final redoStack = pushUndo ? const <FrameState>[] : state.redoStack;

    emit(
      state.copyWith(
        frame: frame,
        undoStack: undoStack,
        redoStack: redoStack,
        selectedElementId: selectedElementId,
        clearSelectedElement: clearSelectedElement,
        isDrawing: isDrawing,
        isLoading: isLoading,
        activeTool: activeTool,
      ),
    );

    _scheduleAutoSave();
  }

  void _scheduleAutoSave({bool immediate = false}) {
    _autoSaveTimer?.cancel();
    if (!_autoSaveEnabled) return;
    _autoSaveTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 280),
      () {
        if (!isClosed) {
          add(const ViewerAutoSaveRequested());
        }
      },
    );
  }

  Future<void> _saveComposition(
    Emitter<ViewerState> emit, {
    required bool forceRefreshRecent,
  }) async {
    final activeImagePath = _activeImagePath;
    if (activeImagePath == null || activeImagePath.isEmpty) return;

    _projectPath = io.File(activeImagePath).parent.path;
    final images = state.frame.elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    );
    final rootImages = images
        .where((image) => image.parentImageId == null)
        .toList(growable: false);
    final rootImageCount = rootImages.length;
    final focusImageId = rootImageCount == 1 ? rootImages.first.id : null;
    final saveAsComposite = rootImageCount > 1;
    final outputNoExt = saveAsComposite
        ? _composedOutputNoExt(activeImagePath)
        : _stripFileExtension(activeImagePath);
    final editableFrame = saveAsComposite
        ? state.frame
        : await _buildEditableFrameForSingleOutput(
            outputImagePath: '$outputNoExt.jpg',
            frame: state.frame,
          );

    emit(state.copyWith(isAutoSaving: true, clearErrorMessage: true));
    try {
      final bytes = await _generateCompositionBytes(
        state.frame,
        focusImageId: focusImageId,
      );
      final savedPath = await _fileSystemService.saveAsJpg(
        imageBytes: bytes,
        outputPath: outputNoExt,
        overwrite: true,
      );
      if (!saveAsComposite) {
        _activeImagePath = savedPath;
      }
      await _saveFrameSidecar(activeImagePath, editableFrame);
      if (saveAsComposite) {
        await _saveFrameSidecar(savedPath, state.frame);
      }

      List<String>? recent;
      if (forceRefreshRecent) {
        final sourceProjectPath =
            state.recentProjectPath ??
            _projectPath ??
            io.File(savedPath).parent.path;
        recent = await _fileSystemService.listJpgFiles(sourceProjectPath);
      }

      emit(
        state.copyWith(
          frame: editableFrame,
          isAutoSaving: false,
          autoSavePath: savedPath,
          recentProjectPath: state.recentProjectPath ?? _projectPath,
          recentCaptures: recent ?? state.recentCaptures,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isAutoSaving: false,
          errorMessage: 'Error al guardar composicion: $e',
        ),
      );
    }
  }

  Future<FrameState> _loadFrameForImage(
    String imagePath, {
    required _ImageFrameDefaults defaults,
  }) async {
    final newSidecarPath = _sidecarPathForImage(imagePath);
    final oldSidecarPath = '$imagePath.qav.json';

    var sidecarFile = io.File(newSidecarPath);

    // Si no existe en la carpeta nueva, buscamos en la vieja (Compatibilidad).
    if (!sidecarFile.existsSync()) {
      final oldFile = io.File(oldSidecarPath);
      if (oldFile.existsSync()) {
        try {
          // Intentamos migrarlo a la nueva carpeta inmediatamente
          await sidecarFile.parent.create(recursive: true);
          await oldFile.rename(newSidecarPath);
          sidecarFile = io.File(newSidecarPath);
        } on Object {
          // Si falla el rename, usamos el viejo como fallback
          sidecarFile = oldFile;
        }
      } else {
        return _buildDefaultFrame(imagePath, defaults: defaults);
      }
    }

    try {
      final raw = await sidecarFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _buildDefaultFrame(imagePath, defaults: defaults);
      }
      final parsed = await _parseFrameFromJson(
        decoded,
        fallbackImagePath: imagePath,
        defaults: defaults,
      );
      if (parsed.elements.isEmpty) {
        return _buildDefaultFrame(imagePath, defaults: defaults);
      }
      return parsed;
    } on Exception {
      return _buildDefaultFrame(imagePath, defaults: defaults);
    }
  }

  Future<FrameState> _buildDefaultFrame(
    String imagePath, {
    required _ImageFrameDefaults defaults,
  }) async {
    final image = await _loadImage(imagePath);
    const frameSize = Size(1500, 900);
    final workspaceRect = _workspaceRectForCanvas(frameSize);
    final rawSize = Size(image.width.toDouble(), image.height.toDouble());
    final visualSize = ImageFrameComponentService.fitImageInsideFrame(
      rawSize,
      workspaceRect.size,
      maxFillRatio: 0.84,
    );
    final centeredPosition = _centerPositionForSize(visualSize, workspaceRect);

    final baseImage = ImageFrameComponent(
      id: _uuid.v4(),
      position: centeredPosition,
      zIndex: 0,
      path: imagePath,
      contentSize: visualSize,
      style: ImageFrameStyle(
        backgroundColor: defaults.backgroundColor,
        backgroundOpacity: defaults.backgroundOpacity,
        borderColor: defaults.borderColor,
        borderWidth: defaults.borderWidth,
        padding: defaults.padding,
      ),
      transform: ImageFrameTransform(
        position: centeredPosition,
        size: visualSize,
      ),
      image: image,
      isLockedBase: true,
    );

    return FrameState(
      canvasSize: frameSize,
      elements: [baseImage],
    );
  }

  Future<FrameState> _parseFrameFromJson(
    Map<String, dynamic> json, {
    required String fallbackImagePath,
    required _ImageFrameDefaults defaults,
  }) async {
    final payloadVersion = (json['version'] as num?)?.toInt() ?? 1;
    final canvasRaw = json['canvasSize'];
    final canvasSize = canvasRaw is Map<String, dynamic>
        ? Size(
            (canvasRaw['width'] as num?)?.toDouble() ?? 1500,
            (canvasRaw['height'] as num?)?.toDouble() ?? 900,
          )
        : const Size(1500, 900);
    final backgroundColor = (json['backgroundColor'] as int?) ?? 0xFF111111;

    final elementsRaw = json['elements'];
    if (elementsRaw is! List) {
      return _buildDefaultFrame(fallbackImagePath, defaults: defaults);
    }

    final parsedElements = <CanvasElement>[];
    for (final raw in elementsRaw) {
      if (raw is! Map<String, dynamic>) continue;
      final kind = (raw['kind'] as String? ?? '').trim().toLowerCase();
      final id = (raw['id'] as String? ?? '').trim();
      if (id.isEmpty) continue;
      final zIndex = (raw['zIndex'] as int?) ?? parsedElements.length;
      final x = (raw['x'] as num?)?.toDouble() ?? 0;
      final y = (raw['y'] as num?)?.toDouble() ?? 0;

      if (kind == 'image') {
        final path = (raw['path'] as String? ?? '').trim();
        if (path.isEmpty) continue;
        final file = io.File(path);
        if (!file.existsSync()) continue;

        final width = (raw['width'] as num?)?.toDouble() ?? 0;
        final height = (raw['height'] as num?)?.toDouble() ?? 0;
        final image = await _loadImage(path);
        final targetWidth = width > 0 ? width : image.width.toDouble();
        final targetHeight = height > 0 ? height : image.height.toDouble();
        final contentWidth =
            (raw['contentWidth'] as num?)?.toDouble() ?? targetWidth;
        final contentHeight =
            (raw['contentHeight'] as num?)?.toDouble() ?? targetHeight;
        final contentOffsetX = (raw['contentOffsetX'] as num?)?.toDouble() ?? 0;
        final contentOffsetY = (raw['contentOffsetY'] as num?)?.toDouble() ?? 0;
        final parentImageId = (raw['parentImageId'] as String?)?.trim();

        parsedElements.add(
          ImageFrameComponent(
            id: id,
            position: Offset(x, y),
            zIndex: zIndex,
            path: path,
            contentSize: Size(contentWidth, contentHeight),
            style: ImageFrameStyle(
              backgroundColor:
                  (raw['frameBackgroundColor'] as int?) ??
                  defaults.backgroundColor,
              backgroundOpacity:
                  ((raw['frameBackgroundOpacity'] as num?)?.toDouble() ??
                          defaults.backgroundOpacity)
                      .clamp(0.0, 1.0),
              borderColor:
                  (raw['frameBorderColor'] as int?) ?? defaults.borderColor,
              borderWidth:
                  ((raw['frameBorderWidth'] as num?)?.toDouble() ??
                          defaults.borderWidth)
                      .clamp(0.0, 20.0),
              padding:
                  ((raw['framePadding'] as num?)?.toDouble() ??
                          defaults.padding)
                      .clamp(0.0, 300.0),
            ),
            transform: ImageFrameTransform(
              position: Offset(x, y),
              size: Size(targetWidth, targetHeight),
              contentOffset: Offset(contentOffsetX, contentOffsetY),
            ),
            image: image,
            parentImageId: parentImageId == null || parentImageId.isEmpty
                ? null
                : parentImageId,
            isLockedBase: (raw['isLockedBase'] as bool?) ?? false,
          ),
        );
        continue;
      }

      if (kind != 'annotation') continue;

      final typeName = (raw['type'] as String? ?? '').trim();
      final type = AnnotationType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => AnnotationType.rectangle,
      );
      final pointsRaw = raw['points'];
      final points = <Offset>[];
      if (pointsRaw is List) {
        for (final pointRaw in pointsRaw) {
          if (pointRaw is! Map<String, dynamic>) continue;
          points.add(
            Offset(
              (pointRaw['x'] as num?)?.toDouble() ?? 0,
              (pointRaw['y'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      final endX = (raw['endX'] as num?)?.toDouble();
      final endY = (raw['endY'] as num?)?.toDouble();
      final attachedImageId = (raw['attachedImageId'] as String?)?.trim();
      final coordinateSpaceName =
          (raw['coordinateSpace'] as String?)?.trim() ?? '';
      final coordinateSpace = AnnotationCoordinateSpace.values.firstWhere(
        (value) => value.name == coordinateSpaceName,
        orElse: () => AnnotationCoordinateSpace.workspace,
      );
      parsedElements.add(
        AnnotationElement(
          id: id,
          type: type,
          color: (raw['color'] as int?) ?? 0xFFE53935,
          strokeWidth: (raw['strokeWidth'] as num?)?.toDouble() ?? 4,
          textSize: (raw['textSize'] as num?)?.toDouble() ?? 20,
          opacity: (raw['opacity'] as num?)?.toDouble() ?? 1,
          text: (raw['text'] as String?) ?? '',
          position: Offset(x, y),
          endPosition: (endX != null && endY != null)
              ? Offset(endX, endY)
              : null,
          points: points,
          attachedImageId: attachedImageId == null || attachedImageId.isEmpty
              ? null
              : attachedImageId,
          coordinateSpace: coordinateSpace,
          zIndex: zIndex,
        ),
      );
    }

    if (parsedElements.isEmpty) {
      return _buildDefaultFrame(fallbackImagePath, defaults: defaults);
    }

    final frame = FrameState(
      canvasSize: canvasSize,
      backgroundColor: backgroundColor,
      elements: _normalizeZ(parsedElements),
    );
    final constrained = _constrainImagesToCanvas(frame);
    return payloadVersion >= 2
        ? constrained
        : _migrateLegacyAnnotationSpaces(constrained);
  }

  Future<void> _saveFrameSidecar(String imagePath, FrameState frame) async {
    final sidecarPath = _sidecarPathForImage(imagePath);
    final file = io.File(sidecarPath);

    final elements = <Map<String, dynamic>>[];
    for (final element in frame.elements) {
      if (element is ImageFrameComponent) {
        elements.add(<String, dynamic>{
          'kind': 'image',
          'id': element.id,
          'path': element.path,
          'x': element.position.dx,
          'y': element.position.dy,
          'width': element.size.width,
          'height': element.size.height,
          'contentWidth': element.contentSize.width,
          'contentHeight': element.contentSize.height,
          'contentOffsetX': element.contentOffset.dx,
          'contentOffsetY': element.contentOffset.dy,
          'parentImageId': element.parentImageId,
          'frameBackgroundColor': element.style.backgroundColor,
          'frameBackgroundOpacity': element.style.backgroundOpacity,
          'frameBorderColor': element.style.borderColor,
          'frameBorderWidth': element.style.borderWidth,
          'framePadding': element.style.padding,
          'zIndex': element.zIndex,
          'isLockedBase': element.isLockedBase,
        });
        continue;
      }
      if (element is AnnotationElement) {
        elements.add(<String, dynamic>{
          'kind': 'annotation',
          'id': element.id,
          'type': element.type.name,
          'color': element.color,
          'strokeWidth': element.strokeWidth,
          'textSize': element.textSize,
          'opacity': element.opacity,
          'text': element.text,
          'attachedImageId': element.attachedImageId,
          'coordinateSpace': element.coordinateSpace.name,
          'x': element.position.dx,
          'y': element.position.dy,
          'endX': element.endPosition?.dx,
          'endY': element.endPosition?.dy,
          'points': element.points
              .map((point) => <String, dynamic>{'x': point.dx, 'y': point.dy})
              .toList(growable: false),
          'zIndex': element.zIndex,
        });
      }
    }

    final payload = <String, dynamic>{
      'version': 2,
      'canvasSize': <String, dynamic>{
        'width': frame.canvasSize.width,
        'height': frame.canvasSize.height,
      },
      'backgroundColor': frame.backgroundColor,
      'elements': elements,
    };

    final encodedPayload = jsonEncode(payload);

    await file.parent.create(recursive: true);
    await file.writeAsString(encodedPayload, flush: true);
  }

  AnnotationCoordinateSpace _annotationCoordinateSpaceForAttachment(
    String? attachedImageId,
  ) {
    if (attachedImageId == null || attachedImageId.isEmpty) {
      return AnnotationCoordinateSpace.workspace;
    }
    return AnnotationCoordinateSpace.imageContent;
  }

  Offset _storeAnnotationPoint(
    List<CanvasElement> elements, {
    required String? attachedImageId,
    required AnnotationCoordinateSpace coordinateSpace,
    required Offset canvasPoint,
  }) {
    if (coordinateSpace != AnnotationCoordinateSpace.imageContent ||
        attachedImageId == null ||
        attachedImageId.isEmpty) {
      return canvasPoint;
    }

    final attachedImage = _findImageById(elements, attachedImageId);
    if (attachedImage == null) {
      return canvasPoint;
    }

    return ViewerCompositionHelper.canvasPointToImageContent(
      attachedImage,
      canvasPoint,
      imageZoom: state.canvasZoom,
    );
  }

  AnnotationElement _projectAnnotationForDisplay(
    List<CanvasElement> elements,
    AnnotationElement annotation, {
    double? imageZoom,
  }) {
    return ViewerCompositionHelper.projectAnnotation(
      elements,
      annotation,
      imageZoom: imageZoom ?? state.canvasZoom,
    );
  }

  AnnotationElement _storeProjectedAnnotation(
    List<CanvasElement> elements, {
    required AnnotationElement source,
    required AnnotationElement projected,
  }) {
    if (source.coordinateSpace != AnnotationCoordinateSpace.imageContent ||
        source.attachedImageId == null ||
        source.attachedImageId!.isEmpty) {
      return projected.copyWith(
        attachedImageId: source.attachedImageId,
        coordinateSpace: source.coordinateSpace,
      );
    }

    final attachedImage = _findImageById(elements, source.attachedImageId!);
    if (attachedImage == null) {
      return projected.copyWith(
        attachedImageId: source.attachedImageId,
        coordinateSpace: source.coordinateSpace,
      );
    }

    return source.copyWith(
      position: ViewerCompositionHelper.canvasPointToImageContent(
        attachedImage,
        projected.position,
        imageZoom: state.canvasZoom,
      ),
      endPosition: projected.endPosition == null
          ? null
          : ViewerCompositionHelper.canvasPointToImageContent(
              attachedImage,
              projected.endPosition!,
              imageZoom: state.canvasZoom,
            ),
      points: projected.points
          .map(
            (point) => ViewerCompositionHelper.canvasPointToImageContent(
              attachedImage,
              point,
              imageZoom: state.canvasZoom,
            ),
          )
          .toList(growable: false),
      coordinateSpace: source.coordinateSpace,
    );
  }

  String? _findTopImageIdAtPoint(
    List<CanvasElement> elements,
    Offset point, {
    required double imageZoom,
  }) {
    final images = elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final image in images) {
      final bounds = ViewerCompositionHelper.imageFrameRect(
        image,
        imageZoom: imageZoom,
      );
      if (bounds.contains(point)) {
        return image.id;
      }
    }
    return null;
  }

  ImageFrameComponent? _resolveInsertionParentImage(FrameState frame) {
    final selectedId = state.selectedElementId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    final selected = frame.elements
        .where((element) => element.id == selectedId)
        .firstOrNull;
    if (selected is ImageFrameComponent) {
      return selected;
    }
    if (selected is AnnotationElement && selected.attachedImageId != null) {
      return _findImageById(frame.elements, selected.attachedImageId!);
    }
    return null;
  }

  int _countNestedImages(FrameState frame) {
    final parent = _resolveInsertionParentImage(frame);
    if (parent == null) {
      return frame.elements.whereType<ImageFrameComponent>().length;
    }
    return frame.elements
        .whereType<ImageFrameComponent>()
        .where((image) => image.parentImageId == parent.id)
        .length;
  }

  ImageFrameComponent? _findImageById(
    List<CanvasElement> elements,
    String imageId,
  ) {
    for (final element in elements) {
      if (element is ImageFrameComponent && element.id == imageId) {
        return element;
      }
    }
    return null;
  }

  Rect _movementBoundsForNewImage({
    required FrameState frame,
    required ImageFrameComponent? parent,
  }) {
    if (parent == null) {
      return _workspaceRectForCanvas(frame.canvasSize);
    }
    return parent.contentViewportRect;
  }

  Rect _movementBoundsForImage(
    List<CanvasElement> elements,
    ImageFrameComponent image,
  ) {
    final parentId = image.parentImageId;
    if (parentId == null || parentId.isEmpty) {
      return _workspaceRectForCanvas(state.frame.canvasSize);
    }
    final parent = _findImageById(elements, parentId);
    return parent?.contentViewportRect ??
        _workspaceRectForCanvas(state.frame.canvasSize);
  }

  Rect _movementBoundsForAnnotation(
    List<CanvasElement> elements,
    AnnotationElement annotation,
  ) {
    final attachedId = annotation.attachedImageId;
    if (attachedId == null || attachedId.isEmpty) {
      return _workspaceRectForCanvas(state.frame.canvasSize);
    }
    final parent = _findImageById(elements, attachedId);
    return parent?.frameRect ??
        _workspaceRectForCanvas(state.frame.canvasSize);
  }

  Offset _clampPointToBounds(Offset point, Rect bounds) {
    final x = point.dx.clamp(bounds.left, bounds.right);
    final y = point.dy.clamp(bounds.top, bounds.bottom);
    return Offset(x, y);
  }

  void _translateImageDependents(
    List<CanvasElement> elements, {
    required String imageId,
    required Offset delta,
  }) {
    if (delta == Offset.zero) return;

    for (var i = 0; i < elements.length; i++) {
      final candidate = elements[i];
      if (candidate is AnnotationElement &&
          candidate.attachedImageId == imageId &&
          candidate.coordinateSpace == AnnotationCoordinateSpace.workspace) {
        elements[i] = _translateAnnotation(candidate, delta);
        continue;
      }
      if (candidate is ImageFrameComponent &&
          candidate.parentImageId == imageId) {
        final moved = candidate.copyWith(
          transform: candidate.transform.copyWith(
            position: candidate.position + delta,
          ),
        );
        elements[i] = moved;
        _translateImageDependents(
          elements,
          imageId: candidate.id,
          delta: delta,
        );
      }
    }
  }

  void _constrainImageChildren(
    List<CanvasElement> elements, {
    required String parentId,
    required Size canvasSize,
    required double zoom,
  }) {
    final parent = _findImageById(elements, parentId);
    if (parent == null) return;
    final movementBounds = parent.contentViewportRect;

    for (var i = 0; i < elements.length; i++) {
      final candidate = elements[i];
      if (candidate is! ImageFrameComponent ||
          candidate.parentImageId != parentId) {
        continue;
      }

      final constrained = ImageFrameComponentService.constrainToCanvas(
        component: candidate,
        frameSize: canvasSize,
        movementBounds: movementBounds,
        displayScale: zoom,
      );
      final delta = constrained.position - candidate.position;
      elements[i] = constrained;
      if (delta != Offset.zero) {
        _translateImageDependents(
          elements,
          imageId: candidate.id,
          delta: delta,
        );
      }
      _constrainImageChildren(
        elements,
        parentId: candidate.id,
        canvasSize: canvasSize,
        zoom: zoom,
      );
    }
  }

  Set<String> _collectDescendantImageIds(
    List<CanvasElement> elements,
    String imageId,
  ) {
    final descendants = <String>{};
    void visit(String parentId) {
      for (final element in elements.whereType<ImageFrameComponent>()) {
        if (element.parentImageId != parentId) continue;
        if (!descendants.add(element.id)) continue;
        visit(element.id);
      }
    }

    visit(imageId);
    return descendants;
  }

  FrameState _migrateLegacyAnnotationSpaces(FrameState frame) {
    final migrated = frame.elements.map((element) {
      if (element is! AnnotationElement) {
        return element;
      }
      if (element.attachedImageId == null || element.attachedImageId!.isEmpty) {
        return element;
      }
      if (element.coordinateSpace == AnnotationCoordinateSpace.imageContent) {
        return element;
      }

      final attachedImage = _findImageById(
        frame.elements,
        element.attachedImageId!,
      );
      if (attachedImage == null) {
        return element;
      }

      return element.copyWith(
        position: ViewerCompositionHelper.canvasPointToImageContent(
          attachedImage,
          element.position,
        ),
        endPosition: element.endPosition == null
            ? null
            : ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                element.endPosition!,
              ),
        points: element.points
            .map(
              (point) => ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                point,
              ),
            )
            .toList(growable: false),
        coordinateSpace: AnnotationCoordinateSpace.imageContent,
      );
    }).toList(growable: false);

    return frame.copyWith(elements: migrated);
  }

  AnnotationElement _translateAnnotation(
    AnnotationElement annotation,
    Offset delta,
  ) {
    if (delta == Offset.zero) {
      return annotation;
    }
    return annotation.copyWith(
      position: annotation.position + delta,
      endPosition: annotation.endPosition == null
          ? null
          : annotation.endPosition! + delta,
      points: annotation.points
          .map((point) => point + delta)
          .toList(growable: false),
    );
  }

  FrameState _constrainImagesToCanvas(FrameState frame, {double? zoom}) {
    final elements = List<CanvasElement>.from(frame.elements);
    final displayScale = zoom ?? state.canvasZoom;
    final rootImages = elements
        .whereType<ImageFrameComponent>()
        .where((image) => image.parentImageId == null)
        .toList(growable: false);

    for (final root in rootImages) {
      final index = elements.indexWhere((element) => element.id == root.id);
      if (index < 0) continue;
      final constrained = ImageFrameComponentService.constrainToCanvas(
        component: root,
        frameSize: frame.canvasSize,
        movementBounds: _workspaceRectForCanvas(frame.canvasSize),
        displayScale: displayScale,
      );
      final delta = constrained.position - root.position;
      elements[index] = constrained;
      if (delta != Offset.zero) {
        _translateImageDependents(
          elements,
          imageId: root.id,
          delta: delta,
        );
      }
      _constrainImageChildren(
        elements,
        parentId: root.id,
        canvasSize: frame.canvasSize,
        zoom: displayScale,
      );
    }

    return frame.copyWith(elements: elements);
  }

  Rect _workspaceRectForCanvas(Size canvasSize) {
    return ViewerWorkspaceLayout.resolve(canvasSize);
  }

  Offset _centerPositionForSize(
    Size size,
    Rect bounds, {
    double displayScale = 1,
  }) {
    return Offset(
      bounds.left + ((bounds.width - (size.width * displayScale)) / 2),
      bounds.top + ((bounds.height - (size.height * displayScale)) / 2),
    );
  }

  String _sidecarPathForImage(String imagePath) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}$name.qav.json';
  }

  String _editableAssetPathForImage(
    String imagePath, {
    required String elementId,
  }) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}assets'
        '${io.Platform.pathSeparator}$elementId-$name';
  }

  String _stripFileExtension(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return normalized;

    final slash = math.max(
      normalized.lastIndexOf('/'),
      normalized.lastIndexOf(io.Platform.pathSeparator),
    );
    final dot = normalized.lastIndexOf('.');
    if (dot <= slash) return normalized;
    return normalized.substring(0, dot);
  }

  String _composedOutputNoExt(String activeImagePath) {
    final base = _stripFileExtension(activeImagePath);
    if (base.toLowerCase().endsWith('_compuesto')) {
      return base;
    }
    return '${base}_compuesto';
  }

  Future<FrameState> _buildEditableFrameForSingleOutput({
    required String outputImagePath,
    required FrameState frame,
  }) async {
    final elements = <CanvasElement>[];

    for (final element in frame.elements) {
      if (element is! ImageFrameComponent) {
        elements.add(element);
        continue;
      }

      if (_samePath(element.path, outputImagePath)) {
        final editablePath = _editableAssetPathForImage(
          outputImagePath,
          elementId: element.id,
        );
        final editableFile = io.File(editablePath);
        if (!editableFile.existsSync()) {
          final sourceFile = io.File(outputImagePath);
          if (sourceFile.existsSync()) {
            await editableFile.parent.create(recursive: true);
            await sourceFile.copy(editablePath);
          }
        }
        elements.add(
          element.copyWith(path: editablePath),
        );
        continue;
      }

      elements.add(element);
    }

    return frame.copyWith(elements: elements);
  }

  bool _samePath(String left, String right) {
    String normalizePath(String path) {
      return path.trim().replaceAll(r'\', '/').toLowerCase();
    }

    return normalizePath(left) == normalizePath(right);
  }

  Future<ui.Image> _loadImage(String path) async {
    final bytes = await _fileSystemService.readFileAsBytes(path);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Future<Uint8List> _generateCompositionBytes(
    FrameState frame, {
    String? focusImageId,
  }) async {
    const pixelRatio =
        2.0; // Alta densidad para máxima nitidez en textos y flechas

    final exportRect = _snapExportRect(
      _resolveExportRect(
        frame,
        focusImageId: focusImageId,
      ),
      pixelRatio: pixelRatio,
    );
    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(
            recorder,
          )
          ..scale(pixelRatio)
          ..translate(-exportRect.left, -exportRect.top);

    ViewerCompositionHelper.paintFrame(canvas, frame, forExport: true);
    final picture = recorder.endRecording();

    final image = await picture.toImage(
      math.max(1, (exportRect.width * pixelRatio).ceil()),
      math.max(1, (exportRect.height * pixelRatio).ceil()),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('No se pudo generar bytes de composicion');
    }
    return bytes.buffer.asUint8List();
  }

  Rect _snapExportRect(Rect rect, {required double pixelRatio}) {
    if (rect.isEmpty) {
      return rect;
    }

    final left = (rect.left * pixelRatio).floor() / pixelRatio;
    final top = (rect.top * pixelRatio).floor() / pixelRatio;
    final right = (rect.right * pixelRatio).ceil() / pixelRatio;
    final bottom = (rect.bottom * pixelRatio).ceil() / pixelRatio;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _resolveExportRect(
    FrameState frame, {
    String? focusImageId,
  }) {
    if (frame.elements.isEmpty) {
      return Offset.zero & frame.canvasSize;
    }

    Rect exportRect;

    // Caso 1: exportar un unico componente de imagen enfocado
    // (con sus anotaciones).
    if (focusImageId != null && focusImageId.isNotEmpty) {
      final target = frame.elements
          .whereType<ImageFrameComponent>()
          .where((element) => element.id == focusImageId)
          .firstOrNull;

      if (target != null) {
        exportRect = ViewerCompositionHelper.imageFrameRect(target);
        final descendantIds = _collectDescendantImageIds(
          frame.elements,
          focusImageId,
        );
        final subtreeIds = <String>{focusImageId, ...descendantIds};
        for (final image in frame.elements.whereType<ImageFrameComponent>()) {
          if (!subtreeIds.contains(image.id)) continue;
          exportRect = exportRect.expandToInclude(
            ViewerCompositionHelper.imageFrameRect(image),
          );
        }
        // Expandir para incluir anotaciones adjuntas o solapadas.
        for (final element in frame.elements.whereType<AnnotationElement>()) {
          final bounds = ViewerCompositionHelper.annotationBounds(
            element,
            elements: frame.elements,
          );
          final isAttached = subtreeIds.contains(element.attachedImageId);
          final overlaps = bounds.overlaps(exportRect);
          if (isAttached || overlaps) {
            exportRect = exportRect.expandToInclude(bounds);
          }
        }
        return exportRect;
      }
    }

    // Caso 2: Exportar toda la composición (todas las imágenes y anotaciones).
    exportRect = ViewerCompositionHelper.elementBounds(
      frame.elements.first,
      elements: frame.elements,
    );
    for (var i = 1; i < frame.elements.length; i++) {
      exportRect = exportRect.expandToInclude(
        ViewerCompositionHelper.elementBounds(
          frame.elements[i],
          elements: frame.elements,
        ),
      );
    }

    // Retornamos el área exacta de los elementos con un pequeño margen,
    // ignorando el tamaño del "canvas" de trabajo que puede ser mucho mayor.
    return exportRect;
  }

  static int _nextZ(List<CanvasElement> elements) {
    if (elements.isEmpty) return 0;
    final top = elements.map((e) => e.zIndex).reduce(math.max);
    return top + 1;
  }

  static List<CanvasElement> _normalizeZ(List<CanvasElement> elements) {
    final images = elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final annotations = elements.whereType<AnnotationElement>().toList(
      growable: false,
    )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final normalizedSource = <CanvasElement>[...images, ...annotations];

    final normalized = <CanvasElement>[];
    for (var i = 0; i < normalizedSource.length; i++) {
      final element = normalizedSource[i];
      if (element is ImageFrameComponent) {
        normalized.add(element.copyWith(zIndex: i));
      } else if (element is AnnotationElement) {
        normalized.add(element.copyWith(zIndex: i));
      }
    }
    return normalized;
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    // Evita disposal durante guardado async para no invalidar ui.Image activas.
    return super.close();
  }

  void _disposeImageFrames(Iterable<FrameState> frames) {
    final disposedRefs = <int>{};
    for (final frame in frames) {
      for (final element in frame.elements.whereType<ImageFrameComponent>()) {
        final rawImage = element.image;
        if (rawImage is! ui.Image) continue;
        final ref = rawImage.hashCode;
        if (!disposedRefs.add(ref)) continue;
        rawImage.dispose();
      }
    }
  }
}

class _ImageFrameDefaults {
  const _ImageFrameDefaults({
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.padding,
  });

  final int backgroundColor;
  final double backgroundOpacity;
  final int borderColor;
  final double borderWidth;
  final double padding;
}
