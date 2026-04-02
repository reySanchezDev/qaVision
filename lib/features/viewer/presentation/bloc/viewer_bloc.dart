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
import 'package:qavision/features/viewer/data/services/viewer_document_persistence_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_image_frame_defaults.dart';
import 'package:qavision/features/viewer/domain/services/image_frame_component_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_image_insertion_service.dart';
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
    required ViewerDocumentPersistenceService documentPersistenceService,
  }) : _fileSystemService = fileSystemService,
       _clipboardService = clipboardService,
       _shareService = shareService,
       _documentPersistenceService = documentPersistenceService,
       super(const ViewerState()) {
    on<ViewerStarted>(_onStarted);
    on<ViewerToolChanged>(_onToolChanged);
    on<ViewerStepMarkerResetRequested>(_onStepMarkerResetRequested);
    on<ViewerPropertiesChanged>(_onPropertiesChanged);
    on<ViewerBackgroundColorChanged>(_onBackgroundColorChanged);
    on<ViewerCanvasResized>(_onCanvasResized);
    on<ViewerZoomChanged>(_onZoomChanged);
    on<ViewerAnnotationStarted>(_onAnnotationStarted);
    on<ViewerAnnotationUpdated>(_onAnnotationUpdated);
    on<ViewerAnnotationFinished>(_onAnnotationFinished);
    on<ViewerTextAdded>(_onTextAdded);
    on<ViewerRichTextPanelAdded>(_onRichTextPanelAdded);
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
    on<ViewerRecentCapturesCleared>(_onRecentCapturesCleared);
    on<ViewerRecentCapturesReordered>(_onRecentCapturesReordered);
    on<ViewerSelectedElementTextUpdated>(_onSelectedElementTextUpdated);
    on<ViewerSelectedElementRichTextUpdated>(_onSelectedElementRichTextUpdated);
    on<ViewerSelectedFrameStyleChanged>(_onSelectedFrameStyleChanged);
    on<ViewerExportRequested>(_onExportRequested);
    on<ViewerCopyRequested>(_onCopyRequested);
    on<ViewerShareRequested>(_onShareRequested);
    on<ViewerAutoSaveRequested>(_onAutoSaveRequested);
  }

  final FileSystemService _fileSystemService;
  final ClipboardService _clipboardService;
  final ShareService _shareService;
  final ViewerDocumentPersistenceService _documentPersistenceService;
  static const _uuid = Uuid();
  static const bool _autoSaveEnabled = true;
  static const int _defaultFrameBackgroundColor = 0xFFFFFFFF;
  static const double _defaultFrameBackgroundOpacity = 1;
  static const int _defaultFrameBorderColor = 0x33000000;
  static const double _defaultFrameBorderWidth = 1;
  static const double _defaultFramePadding = 0;

  Timer? _autoSaveTimer;
  bool _autoSaveInProgress = false;
  bool _autoSaveQueued = false;
  bool _hasPendingRecoveryDraft = false;
  FrameState? _drawingStartFrame;
  FrameState? _interactionStartFrame;
  String? _activeImagePath;
  String? _projectPath;

  ViewerImageFrameDefaults _resolveDefaultsFromStart(ViewerStarted event) {
    return ViewerImageFrameDefaults(
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

  ViewerImageFrameDefaults _resolveDefaultsFromInsert(ViewerImageAdded event) {
    return ViewerImageFrameDefaults(
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

      final loadResult = await _documentPersistenceService
          .loadFrameResultForImage(
            imagePath: event.imagePath,
            defaults: defaults,
          );
      final loadedFrame = _constrainImagesToCanvas(
        loadResult.frame,
        zoom: 1,
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
          canvasZoom: loadResult.canvasZoom,
          activeStepMarkerNext: _inferNextStepMarkerNumber(loadedFrame),
          activeTool: AnnotationType.selection,
          undoStack: const [],
          redoStack: const [],
          selectedElementId: selectedImageId,
          clearSelectedElement: selectedImageId == null,
          recentCaptures: recentCaptures,
          recentProjectPath: _projectPath,
          isLoading: false,
          clearAutoSavePath: true,
          recoveredSession: loadResult.recoveredFromDraft,
          clearErrorMessage: true,
        ),
      );
      _hasPendingRecoveryDraft = loadResult.recoveredFromDraft;
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
          fontFamily: event.fontFamily ?? annotation.fontFamily,
          isBold: event.isBold ?? annotation.isBold,
          isItalic: event.isItalic ?? annotation.isItalic,
          hasShadow: event.hasShadow ?? annotation.hasShadow,
          backgroundColor:
              event.panelBackgroundColor ?? annotation.backgroundColor,
          panelBorderColor:
              event.panelBorderColor ?? annotation.panelBorderColor,
          panelBorderWidth:
              event.panelBorderWidth ?? annotation.panelBorderWidth,
          panelAlignment: event.panelAlignment ?? annotation.panelAlignment,
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
            activeFontFamily: event.fontFamily ?? state.activeFontFamily,
            activeTextBold: event.isBold ?? state.activeTextBold,
            activeTextItalic: event.isItalic ?? state.activeTextItalic,
            activeTextShadow: event.hasShadow ?? state.activeTextShadow,
            activeTextPanelBackgroundColor:
                event.panelBackgroundColor ??
                state.activeTextPanelBackgroundColor,
            activeTextPanelBorderColor:
                event.panelBorderColor ?? state.activeTextPanelBorderColor,
            activeTextPanelBorderWidth:
                event.panelBorderWidth ?? state.activeTextPanelBorderWidth,
            activeTextHighlightColor:
                event.textHighlightColor ?? state.activeTextHighlightColor,
            activeTextPanelAlignment:
                event.panelAlignment ?? state.activeTextPanelAlignment,
            selectedElementId: selectedId,
            clearRecoveredSession: true,
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
        activeFontFamily: event.fontFamily ?? state.activeFontFamily,
        activeTextBold: event.isBold ?? state.activeTextBold,
        activeTextItalic: event.isItalic ?? state.activeTextItalic,
        activeTextShadow: event.hasShadow ?? state.activeTextShadow,
        activeTextPanelBackgroundColor:
            event.panelBackgroundColor ?? state.activeTextPanelBackgroundColor,
        activeTextPanelBorderColor:
            event.panelBorderColor ?? state.activeTextPanelBorderColor,
        activeTextPanelBorderWidth:
            event.panelBorderWidth ?? state.activeTextPanelBorderWidth,
        activeTextHighlightColor:
            event.textHighlightColor ?? state.activeTextHighlightColor,
        activeTextPanelAlignment:
            event.panelAlignment ?? state.activeTextPanelAlignment,
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
      zoom: 1,
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
        tool == AnnotationType.richTextPanel ||
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
          imageZoom: state.canvasZoom,
        ),
        text: '${state.activeStepMarkerNext}',
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
        activeStepMarkerNext: state.activeStepMarkerNext + 1,
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
        imageZoom: state.canvasZoom,
      ),
      endPosition: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: event.position,
        imageZoom: state.canvasZoom,
      ),
      points: [
        _storeAnnotationPoint(
          state.frame.elements,
          attachedImageId: attachedImageId,
          coordinateSpace: coordinateSpace,
          canvasPoint: event.position,
          imageZoom: state.canvasZoom,
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
            imageZoom: state.canvasZoom,
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
          imageZoom: state.canvasZoom,
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
        imageZoom: state.canvasZoom,
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

  void _onRichTextPanelAdded(
    ViewerRichTextPanelAdded event,
    Emitter<ViewerState> emit,
  ) {
    final attachedImageId = _findTopImageIdAtPoint(
      state.frame.elements,
      event.position,
      imageZoom: state.canvasZoom,
    );
    final coordinateSpace = attachedImageId == null || attachedImageId.isEmpty
        ? AnnotationCoordinateSpace.workspace
        : AnnotationCoordinateSpace.imageFrame;
    final placementBounds = _initialRichTextPanelBounds(attachedImageId);
    final panelRect = _initialRichTextPanelRect(
      event.position,
      bounds: placementBounds,
    );
    final annotation = AnnotationElement(
      id: _uuid.v4(),
      type: AnnotationType.richTextPanel,
      color: state.activeColor,
      strokeWidth: state.activeStrokeWidth,
      textSize: state.activeTextSize,
      position: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: panelRect.topLeft,
        imageZoom: state.canvasZoom,
      ),
      endPosition: _storeAnnotationPoint(
        state.frame.elements,
        attachedImageId: attachedImageId,
        coordinateSpace: coordinateSpace,
        canvasPoint: panelRect.bottomRight,
        imageZoom: state.canvasZoom,
      ),
      richTextDelta: _emptyRichTextDelta(),
      fontFamily: state.activeFontFamily,
      isBold: state.activeTextBold,
      isItalic: state.activeTextItalic,
      hasShadow: state.activeTextShadow,
      backgroundColor: state.activeTextPanelBackgroundColor,
      panelBorderColor: state.activeTextPanelBorderColor,
      panelBorderWidth: state.activeTextPanelBorderWidth,
      panelAlignment: state.activeTextPanelAlignment,
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
      final insertionPlan = ViewerImageInsertionService.plan(
        frame: state.frame,
        rawImageSize: rawSize,
        selectedElementId: state.selectedElementId,
        dropPoint: event.position,
        displayZoom: state.canvasZoom,
      );
      final added = ImageFrameComponentService.constrainToCanvas(
        component: ImageFrameComponent(
          id: _uuid.v4(),
          position: insertionPlan.position,
          zIndex: _nextZ(state.frame.elements),
          path: event.imagePath,
          contentSize: insertionPlan.fittedSize,
          style: ImageFrameStyle(
            backgroundColor: defaults.backgroundColor,
            backgroundOpacity: defaults.backgroundOpacity,
            borderColor: defaults.borderColor,
            borderWidth: defaults.borderWidth,
            padding: defaults.padding,
          ),
          transform: ImageFrameTransform(
            position: insertionPlan.position,
            size: insertionPlan.fittedSize,
          ),
          image: image,
          parentImageId: insertionPlan.parentImageId,
        ),
        frameSize: state.frame.canvasSize,
        movementBounds: insertionPlan.movementBounds,
        displayScale: insertionPlan.parentImageId == null
            ? state.canvasZoom
            : 1,
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
          displayScale: _displayScaleForImage(selected),
        ),
        frameSize: state.frame.canvasSize,
        movementBounds: workspaceRect,
        displayScale: _displayScaleForImage(selected),
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
        displayScale: _displayScaleForImage(element),
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
        imageZoom: state.canvasZoom,
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
        imageZoom: state.canvasZoom,
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
      final imageDisplaySnapshot = _captureImageContentDisplaySnapshot(
        elements,
        imageId: element.id,
      );
      final subtreeSnapshot = _captureSubtreeDisplaySnapshot(
        elements,
        parentId: element.id,
      );
      final annotationSnapshot = _captureAttachedAnnotationDisplaySnapshot(
        elements,
        subtreeRootId: element.id,
      );
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
        displayScale: _displayScaleForImage(element),
      );
      elements[index] = resizedComponent;
      _restoreImageContentDisplaySnapshot(
        elements,
        imageId: element.id,
        imageDisplaySnapshot: imageDisplaySnapshot,
      );
      _restoreSubtreeDisplaySnapshot(
        elements,
        parentId: element.id,
        snapshot: subtreeSnapshot,
        annotationSnapshot: annotationSnapshot,
      );
    } else if (element is AnnotationElement) {
      final projected = _projectAnnotationForDisplay(
        elements,
        element,
        imageZoom: state.canvasZoom,
      );
      final oldBounds = ViewerCompositionHelper.annotationBounds(projected);
      final nextRect = Rect.fromLTWH(
        event.position?.dx ?? oldBounds.left,
        event.position?.dy ?? oldBounds.top,
        width,
        height,
      );
      if (element.type == AnnotationType.text ||
          element.type == AnnotationType.commentBubble) {
        final ratio = oldBounds.width <= 1
            ? 1.0
            : nextRect.width / oldBounds.width;
        final textSize = (element.textSize * ratio).clamp(10, 120).toDouble();
        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            position: nextRect.topLeft,
            textSize: textSize,
          ),
          imageZoom: state.canvasZoom,
        );
      } else if (element.type == AnnotationType.stepMarker) {
        final ratio = oldBounds.width <= 1
            ? 1.0
            : nextRect.width / oldBounds.width;
        final textSize = (element.textSize * ratio).clamp(12, 96).toDouble();
        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            position: nextRect.center,
            textSize: textSize,
          ),
          imageZoom: state.canvasZoom,
        );
      } else if (element.type == AnnotationType.pencil &&
          element.points.isNotEmpty) {
        final sx = oldBounds.width <= 1
            ? 1.0
            : nextRect.width / oldBounds.width;
        final sy = oldBounds.height <= 1
            ? 1.0
            : nextRect.height / oldBounds.height;
        final transformed = projected.points
            .map(
              (point) => Offset(
                nextRect.left + (point.dx - oldBounds.left) * sx,
                nextRect.top + (point.dy - oldBounds.top) * sy,
              ),
            )
            .toList(growable: false);
        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            position: transformed.first,
            points: transformed,
            clearEndPosition: true,
          ),
          imageZoom: state.canvasZoom,
        );
      } else {
        Offset remapPoint(Offset point) {
          final widthFactor = oldBounds.width <= 1
              ? 0.0
              : (point.dx - oldBounds.left) / oldBounds.width;
          final heightFactor = oldBounds.height <= 1
              ? 0.0
              : (point.dy - oldBounds.top) / oldBounds.height;
          return Offset(
            nextRect.left + (nextRect.width * widthFactor),
            nextRect.top + (nextRect.height * heightFactor),
          );
        }

        elements[index] = _storeProjectedAnnotation(
          elements,
          source: element,
          projected: projected.copyWith(
            position: remapPoint(projected.position),
            endPosition: projected.endPosition == null
                ? null
                : remapPoint(projected.endPosition!),
          ),
          imageZoom: state.canvasZoom,
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
        clearRecoveredSession: true,
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
        activeStepMarkerNext: _inferNextStepMarkerNumber(previous),
        undoStack: undoStack,
        redoStack: redoStack,
        clearSelectedElement: true,
        clearRecoveredSession: true,
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
        activeStepMarkerNext: _inferNextStepMarkerNumber(next),
        undoStack: undoStack,
        redoStack: redoStack,
        clearSelectedElement: true,
        clearRecoveredSession: true,
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

  void _onRecentCapturesCleared(
    ViewerRecentCapturesCleared event,
    Emitter<ViewerState> emit,
  ) {
    emit(
      state.copyWith(
        recentCaptures: const [],
        clearRecentProjectPath: true,
      ),
    );
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

    final sanitized = event.text.replaceAll('\r\n', '\n');
    if (sanitized.trim().isEmpty) return;

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

    elements[index] = element.copyWith(text: sanitized);
    _commitFrame(
      emit,
      frame: state.frame.copyWith(elements: elements),
      pushUndo: true,
      undoSnapshot: state.frame,
      selectedElementId: selectedId,
    );
  }

  void _onSelectedElementRichTextUpdated(
    ViewerSelectedElementRichTextUpdated event,
    Emitter<ViewerState> emit,
  ) {
    final selectedId = state.selectedElementId;
    if (selectedId == null) return;

    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == selectedId);
    if (index == -1) return;

    final element = elements[index];
    if (element is! AnnotationElement ||
        element.type != AnnotationType.richTextPanel) {
      return;
    }

    final sanitizedPlain = event.plainText.replaceAll('\r\n', '\n').trimRight();
    elements[index] = element.copyWith(
      text: sanitizedPlain,
      richTextDelta: event.deltaJson,
    );
    emit(
      state.copyWith(
        frame: state.frame.copyWith(elements: elements),
        selectedElementId: selectedId,
        clearRecoveredSession: true,
      ),
    );
    _scheduleAutoSave();
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
    final activeImagePath = _activeImagePath;
    if (activeImagePath == null || activeImagePath.isEmpty) return;
    if (_autoSaveInProgress) {
      _autoSaveQueued = true;
      return;
    }
    _autoSaveInProgress = true;
    emit(state.copyWith(isAutoSaving: true, clearErrorMessage: true));
    try {
      await _documentPersistenceService.saveRecoveryDraft(
        imagePath: activeImagePath,
        frame: state.frame,
        canvasZoom: state.canvasZoom,
      );
      _hasPendingRecoveryDraft = true;
      emit(
        state.copyWith(
          isAutoSaving: false,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isAutoSaving: false,
          errorMessage: 'Error al guardar borrador: $e',
        ),
      );
    }

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
    int? activeStepMarkerNext,
  }) {
    final undoStack = pushUndo
        ? (List<FrameState>.from(state.undoStack)
            ..add(undoSnapshot ?? state.frame))
        : state.undoStack;
    final redoStack = pushUndo ? const <FrameState>[] : state.redoStack;

    emit(
      state.copyWith(
        frame: frame,
        activeStepMarkerNext:
            activeStepMarkerNext ?? state.activeStepMarkerNext,
        undoStack: undoStack,
        redoStack: redoStack,
        selectedElementId: selectedElementId,
        clearSelectedElement: clearSelectedElement,
        clearRecoveredSession: true,
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
    _hasPendingRecoveryDraft = true;
    _autoSaveTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 280),
      () {
        if (!isClosed) {
          add(const ViewerAutoSaveRequested());
        }
      },
    );
  }

  void _onStepMarkerResetRequested(
    ViewerStepMarkerResetRequested event,
    Emitter<ViewerState> emit,
  ) {
    emit(
      state.copyWith(
        activeStepMarkerNext: 1,
        clearRecoveredSession: true,
      ),
    );
  }

  int _inferNextStepMarkerNumber(FrameState frame) {
    var maxStep = 0;
    for (final element in frame.elements.whereType<AnnotationElement>()) {
      if (element.type != AnnotationType.stepMarker) continue;
      final parsed = int.tryParse(element.text.trim());
      if (parsed != null && parsed > maxStep) {
        maxStep = parsed;
      }
    }
    return maxStep + 1;
  }

  Future<void> _saveComposition(
    Emitter<ViewerState> emit, {
    required bool forceRefreshRecent,
  }) async {
    final activeImagePath = _activeImagePath;
    if (activeImagePath == null || activeImagePath.isEmpty) return;

    _projectPath = io.File(activeImagePath).parent.path;
    final savePlan = await _documentPersistenceService.prepareSavePlan(
      activeImagePath: activeImagePath,
      frame: state.frame,
    );

    emit(
      state.copyWith(
        isAutoSaving: true,
        clearErrorMessage: true,
        clearAutoSavePath: true,
      ),
    );
    try {
      final bytes = await _generateCompositionBytes(
        state.frame,
        focusImageId: savePlan.focusImageId,
      );
      final savedPath = await _fileSystemService.saveAsJpg(
        imageBytes: bytes,
        outputPath: savePlan.outputPathWithoutExtension,
        overwrite: true,
      );
      if (!savePlan.saveAsComposite) {
        _activeImagePath = savedPath;
      }
      await _documentPersistenceService.saveEditableFrame(
        imagePath: activeImagePath,
        frame: savePlan.editableFrame,
        canvasZoom: state.canvasZoom,
      );
      if (savePlan.saveAsComposite) {
        await _documentPersistenceService.saveEditableFrame(
          imagePath: savedPath,
          frame: state.frame,
          canvasZoom: state.canvasZoom,
        );
      }
      await _documentPersistenceService.clearRecoveryDraft(
        imagePath: activeImagePath,
      );
      _hasPendingRecoveryDraft = false;

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
          frame: savePlan.editableFrame,
          isAutoSaving: false,
          autoSavePath: savedPath,
          recentProjectPath: state.recentProjectPath ?? _projectPath,
          recentCaptures: recent ?? state.recentCaptures,
          clearRecoveredSession: true,
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
    double imageZoom = 1,
  }) {
    if (attachedImageId == null || attachedImageId.isEmpty) {
      return canvasPoint;
    }

    final attachedImage = _findImageById(elements, attachedImageId);
    if (attachedImage == null) {
      return canvasPoint;
    }

    if (coordinateSpace == AnnotationCoordinateSpace.imageFrame) {
      return ViewerCompositionHelper.canvasPointToImageFrame(
        attachedImage,
        canvasPoint,
        elements: elements,
        imageZoom: imageZoom,
      );
    }

    if (coordinateSpace == AnnotationCoordinateSpace.imageContent) {
      return ViewerCompositionHelper.canvasPointToImageContent(
        attachedImage,
        canvasPoint,
        elements: elements,
        imageZoom: imageZoom,
      );
    }

    return canvasPoint;
  }

  AnnotationElement _projectAnnotationForDisplay(
    List<CanvasElement> elements,
    AnnotationElement annotation, {
    double? imageZoom,
  }) {
    return ViewerCompositionHelper.projectAnnotation(
      elements,
      annotation,
      imageZoom: imageZoom ?? 1,
    );
  }

  AnnotationElement _storeProjectedAnnotation(
    List<CanvasElement> elements, {
    required AnnotationElement source,
    required AnnotationElement projected,
    double imageZoom = 1,
  }) {
    if (source.type == AnnotationType.richTextPanel &&
        source.coordinateSpace == AnnotationCoordinateSpace.workspace) {
      final scale = imageZoom.clamp(0.1, 10.0);
      final projectedRect = projected.endPosition == null
          ? Rect.fromLTWH(
              projected.position.dx,
              projected.position.dy,
              360,
              220,
            )
          : Rect.fromLTRB(
              math.min(projected.position.dx, projected.endPosition!.dx),
              math.min(projected.position.dy, projected.endPosition!.dy),
              math.max(projected.position.dx, projected.endPosition!.dx),
              math.max(projected.position.dy, projected.endPosition!.dy),
            );
      final logicalRect = Rect.fromLTWH(
        projectedRect.left,
        projectedRect.top,
        projectedRect.width / scale,
        projectedRect.height / scale,
      );
      return source.copyWith(
        position: logicalRect.topLeft,
        endPosition: logicalRect.bottomRight,
      );
    }

    if (source.attachedImageId == null || source.attachedImageId!.isEmpty) {
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

    if (source.coordinateSpace == AnnotationCoordinateSpace.imageFrame) {
      return source.copyWith(
        position: ViewerCompositionHelper.canvasPointToImageFrame(
          attachedImage,
          projected.position,
          elements: elements,
          imageZoom: imageZoom,
        ),
        endPosition: projected.endPosition == null
            ? null
            : ViewerCompositionHelper.canvasPointToImageFrame(
                attachedImage,
                projected.endPosition!,
                elements: elements,
                imageZoom: imageZoom,
              ),
        points: projected.points
            .map(
              (point) => ViewerCompositionHelper.canvasPointToImageFrame(
                attachedImage,
                point,
                elements: elements,
                imageZoom: imageZoom,
              ),
            )
            .toList(growable: false),
        coordinateSpace: source.coordinateSpace,
      );
    }

    if (source.coordinateSpace == AnnotationCoordinateSpace.imageContent) {
      return source.copyWith(
        position: ViewerCompositionHelper.canvasPointToImageContent(
          attachedImage,
          projected.position,
          elements: elements,
          imageZoom: imageZoom,
        ),
        endPosition: projected.endPosition == null
            ? null
            : ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                projected.endPosition!,
                elements: elements,
                imageZoom: imageZoom,
              ),
        points: projected.points
            .map(
              (point) => ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                point,
                elements: elements,
                imageZoom: imageZoom,
              ),
            )
            .toList(growable: false),
        coordinateSpace: source.coordinateSpace,
      );
    }

    return projected.copyWith(
      attachedImageId: source.attachedImageId,
      coordinateSpace: source.coordinateSpace,
    );
  }

  String? _findTopImageIdAtPoint(
    List<CanvasElement> elements,
    Offset point, {
    required double imageZoom,
  }) {
    final document = ViewerDocumentGraphService.build(
      state.frame.copyWith(elements: elements),
    );
    return ViewerDocumentGraphService.topImageAtPoint(
      document,
      point,
      imageZoom: imageZoom,
    )?.id;
  }

  ImageFrameComponent? _findImageById(
    List<CanvasElement> elements,
    String imageId,
  ) {
    return ViewerDocumentGraphService.build(
      state.frame.copyWith(elements: elements),
    ).imageById(imageId);
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
    if (parent == null) {
      return _workspaceRectForCanvas(state.frame.canvasSize);
    }
    return ViewerCompositionHelper.imageContentViewportRect(
      parent,
      elements: elements,
      imageZoom: state.canvasZoom,
    );
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

  Rect? _captureImageContentDisplaySnapshot(
    List<CanvasElement> elements, {
    required String imageId,
  }) {
    final image = _findImageById(elements, imageId);
    if (image == null) {
      return null;
    }
    return ViewerCompositionHelper.imageDrawRect(
      image,
      elements: elements,
      imageZoom: state.canvasZoom,
    );
  }

  void _restoreImageContentDisplaySnapshot(
    List<CanvasElement> elements, {
    required String imageId,
    required Rect? imageDisplaySnapshot,
  }) {
    if (imageDisplaySnapshot == null) {
      return;
    }
    final index = elements.indexWhere(
      (candidate) =>
          candidate is ImageFrameComponent && candidate.id == imageId,
    );
    if (index < 0) {
      return;
    }
    final image = elements[index] as ImageFrameComponent;
    final projectedViewport = ViewerCompositionHelper.imageContentViewportRect(
      image,
      elements: elements,
      imageZoom: state.canvasZoom,
    );
    final scale = state.canvasZoom.clamp(0.1, 10.0);
    final proposedOffset = Offset(
      (imageDisplaySnapshot.left - projectedViewport.left) / scale,
      (imageDisplaySnapshot.top - projectedViewport.top) / scale,
    );
    elements[index] = image.copyWith(
      transform: image.transform.copyWith(
        contentOffset: image.clampContentOffset(proposedOffset),
      ),
    );
  }

  Map<String, Rect> _captureSubtreeDisplaySnapshot(
    List<CanvasElement> elements, {
      required String parentId,
  }) {
    final snapshot = <String, Rect>{};
    final descendantIds = _collectDescendantImageIds(elements, parentId);
    for (final candidate in elements) {
      if (candidate is ImageFrameComponent &&
          descendantIds.contains(candidate.id)) {
        snapshot[candidate.id] = ViewerCompositionHelper.imageFrameRect(
          candidate,
          elements: elements,
          imageZoom: state.canvasZoom,
        );
      }
    }
    return snapshot;
  }

  void _restoreSubtreeDisplaySnapshot(
    List<CanvasElement> elements, {
    required String parentId,
    required Map<String, Rect> snapshot,
    required Map<String, AnnotationElement> annotationSnapshot,
  }) {
    if (snapshot.isEmpty && annotationSnapshot.isEmpty) return;

    _restoreImageDescendantDisplaySnapshot(
      elements,
      parentId: parentId,
      snapshot: snapshot,
    );
    _restoreAttachedAnnotationDisplaySnapshot(
      elements,
      annotationSnapshot: annotationSnapshot,
    );
  }

  void _restoreImageDescendantDisplaySnapshot(
    List<CanvasElement> elements, {
    required String parentId,
    required Map<String, Rect> snapshot,
  }) {
    for (var i = 0; i < elements.length; i++) {
      final candidate = elements[i];
      if (candidate is! ImageFrameComponent ||
          candidate.parentImageId != parentId) {
        continue;
      }

      final oldDisplayRect = snapshot[candidate.id];
      if (oldDisplayRect != null) {
        final logicalTopLeft =
            ViewerCompositionHelper.logicalFrameTopLeftFromDisplayTopLeft(
              displayTopLeft: oldDisplayRect.topLeft,
              parentImageId: candidate.parentImageId,
              elements: elements,
              imageZoom: state.canvasZoom,
            );
        elements[i] = candidate.copyWith(
          transform: candidate.transform.copyWith(
            position: logicalTopLeft,
          ),
        );
      }

      _restoreImageDescendantDisplaySnapshot(
        elements,
        parentId: candidate.id,
        snapshot: snapshot,
      );
    }
  }

  Map<String, AnnotationElement> _captureAttachedAnnotationDisplaySnapshot(
    List<CanvasElement> elements, {
    required String subtreeRootId,
  }) {
    final descendantIds = {
      subtreeRootId,
      ..._collectDescendantImageIds(elements, subtreeRootId),
    };
    final projectedById = <String, AnnotationElement>{};

    for (final candidate in elements.whereType<AnnotationElement>()) {
      final attachedId = candidate.attachedImageId;
      if (attachedId == null || !descendantIds.contains(attachedId)) {
        continue;
      }
      projectedById[candidate.id] = _projectAnnotationForDisplay(
        elements,
        candidate,
        imageZoom: state.canvasZoom,
      );
    }

    return projectedById;
  }

  void _restoreAttachedAnnotationDisplaySnapshot(
    List<CanvasElement> elements, {
    required Map<String, AnnotationElement> annotationSnapshot,
  }) {
    if (annotationSnapshot.isEmpty) return;
    for (var i = 0; i < elements.length; i++) {
      final candidate = elements[i];
      if (candidate is! AnnotationElement) continue;
      final projected = annotationSnapshot[candidate.id];
      if (projected == null) continue;
      elements[i] = _storeProjectedAnnotation(
        elements,
        source: candidate,
        projected: projected,
        imageZoom: state.canvasZoom,
      );
    }
  }

  void _constrainImageChildren(
    List<CanvasElement> elements, {
    required String parentId,
    required Size canvasSize,
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
      );
    }
  }

  Set<String> _collectDescendantImageIds(
    List<CanvasElement> elements,
    String imageId,
  ) {
    return ViewerDocumentGraphService.descendantImageIds(
      ViewerDocumentGraphService.build(
        state.frame.copyWith(elements: elements),
      ),
      imageId,
    );
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
    final displayScale = zoom ?? 1.0;
    final rootImages = elements
        .whereType<ImageFrameComponent>()
        .where((image) => image.parentImageId == null)
        .toList(growable: false);

    for (final root in rootImages) {
      final index = elements.indexWhere((element) => element.id == root.id);
      if (index < 0) continue;
      final subtreeSnapshot = _captureSubtreeDisplaySnapshot(
        elements,
        parentId: root.id,
      );
      final annotationSnapshot = _captureAttachedAnnotationDisplaySnapshot(
        elements,
        subtreeRootId: root.id,
      );
      final constrained = ImageFrameComponentService.constrainToCanvas(
        component: root,
        frameSize: frame.canvasSize,
        movementBounds: _workspaceRectForCanvas(frame.canvasSize),
        displayScale: displayScale,
      );
      elements[index] = constrained;
      _restoreSubtreeDisplaySnapshot(
        elements,
        parentId: root.id,
        snapshot: subtreeSnapshot,
        annotationSnapshot: annotationSnapshot,
      );
    }

    return frame.copyWith(elements: elements);
  }

  Rect _workspaceRectForCanvas(Size canvasSize) {
    return ViewerWorkspaceLayout.resolve(canvasSize);
  }

  Rect _initialRichTextPanelBounds(String? attachedImageId) {
    if (attachedImageId == null || attachedImageId.isEmpty) {
      return _workspaceRectForCanvas(state.frame.canvasSize);
    }
    final parent = _findImageById(state.frame.elements, attachedImageId);
    if (parent == null) {
      return _workspaceRectForCanvas(state.frame.canvasSize);
    }
    return ViewerCompositionHelper.imageContentViewportRect(
      parent,
      elements: state.frame.elements,
      imageZoom: state.canvasZoom,
    );
  }

  Rect _initialRichTextPanelRect(
    Offset point, {
    required Rect bounds,
  }) {
    const desiredWidth = 380.0;
    const desiredHeight = 220.0;
    final left = point.dx.clamp(bounds.left, bounds.right - desiredWidth);
    final top = point.dy.clamp(bounds.top, bounds.bottom - desiredHeight);
    return Rect.fromLTWH(
      left,
      top,
      desiredWidth.clamp(220.0, bounds.width),
      desiredHeight.clamp(140.0, bounds.height),
    );
  }

  String _emptyRichTextDelta() {
    return jsonEncode([
      {'insert': '\n'},
    ]);
  }

  double _displayScaleForImage(ImageFrameComponent image) {
    final parentId = image.parentImageId;
    // Solo el frame raiz se limita usando su tamano visible bajo zoom.
    // Las subimagenes ya viven dentro del viewport logico del padre y si se
    // les aplicara tambien el zoom aqui, el espacio util se encogería otra vez.
    if (parentId == null || parentId.isEmpty) {
      return state.canvasZoom;
    }
    return 1;
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
      ViewerDocumentGraphService.resolveExportRect(
        ViewerDocumentGraphService.build(frame),
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

  // Fallback temporal mientras termina de migrarse toda la exportacion al
  // arbol de documento en la fase 2 del visor.
  // ignore: unused_element
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
  Future<void> close() async {
    _autoSaveTimer?.cancel();
    final activeImagePath = _activeImagePath;
    if (_autoSaveEnabled &&
        _hasPendingRecoveryDraft &&
        activeImagePath != null &&
        activeImagePath.isNotEmpty &&
        state.frame.elements.isNotEmpty) {
      try {
        await _documentPersistenceService.saveRecoveryDraft(
          imagePath: activeImagePath,
          frame: state.frame,
          canvasZoom: state.canvasZoom,
        );
      } on Exception {
        // Evitamos fallar el cierre por un problema de persistencia del draft.
      }
    }
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
