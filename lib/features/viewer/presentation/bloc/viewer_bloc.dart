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
    // Anadimos un pequeno margen de cortesia para facilitar
    // la interaccion con los bordes.
    final width = (event.size.width + 200).clamp(320, 12000).toDouble();
    final height = (event.size.height + 200).clamp(220, 12000).toDouble();
    final resizedFrame = state.frame.copyWith(canvasSize: Size(width, height));
    final constrainedFrame = _constrainImagesToCanvas(resizedFrame);
    emit(
      state.copyWith(
        frame: constrainedFrame,
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
        position: event.position,
        text: '${counter + 1}',
        attachedImageId: attachedImageId,
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
      opacity: tool == AnnotationType.highlighter ? state.activeOpacity : 1,
      position: event.position,
      endPosition: event.position,
      points: [event.position],
      attachedImageId: attachedImageId,
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
      updated = last.copyWith(points: [...last.points, event.position]);
    } else {
      updated = last.copyWith(endPosition: event.position);
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
      position: event.position,
      text: text,
      attachedImageId: attachedImageId,
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
      final fittedSize = ImageFrameComponentService.fitImageInsideFrame(
        rawSize,
        state.frame.canvasSize,
      );
      final proposedPosition =
          event.position ??
          Offset(
            40 + 24.0 * state.frame.elements.length,
            40 + 24.0 * state.frame.elements.length,
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
        ),
        frameSize: state.frame.canvasSize,
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
      final centeredComponent = ImageFrameComponentService.move(
        component: selected,
        position: Offset(
          (state.frame.canvasSize.width - selected.size.width) / 2,
          (state.frame.canvasSize.height - selected.size.height) / 2,
        ),
        frameSize: state.frame.canvasSize,
      );
      final delta = centeredComponent.position - selected.position;
      if (delta != Offset.zero) {
        elements[index] = centeredComponent;
        for (var i = 0; i < elements.length; i++) {
          final candidate = elements[i];
          if (candidate is! AnnotationElement) continue;
          if (candidate.attachedImageId != selected.id) continue;
          elements[i] = _translateAnnotation(candidate, delta);
        }
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
      final movedComponent = ImageFrameComponentService.move(
        component: element,
        position: event.position,
        frameSize: state.frame.canvasSize,
      );
      final delta = movedComponent.position - element.position;
      elements[index] = movedComponent;

      if (delta != Offset.zero) {
        for (var i = 0; i < elements.length; i++) {
          final candidate = elements[i];
          if (candidate is! AnnotationElement) continue;
          if (candidate.attachedImageId != element.id) continue;
          elements[i] = _translateAnnotation(candidate, delta);
        }
      }
    } else if (element is AnnotationElement) {
      final clampedPosition = _clampPointToCanvas(
        event.position,
        state.frame.canvasSize,
      );
      final delta = clampedPosition - element.position;
      final points = element.points
          .map((point) => point + delta)
          .toList(growable: false);
      final endPosition = element.endPosition == null
          ? null
          : element.endPosition! + delta;
      elements[index] = element.copyWith(
        position: clampedPosition,
        points: points,
        endPosition: endPosition,
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
      final resizedComponent = ImageFrameComponentService.resize(
        component: element,
        size: Size(width, height),
        position: event.position,
        frameSize: state.frame.canvasSize,
      );
      final delta = resizedComponent.position - element.position;
      elements[index] = resizedComponent;

      if (delta != Offset.zero) {
        for (var i = 0; i < elements.length; i++) {
          final candidate = elements[i];
          if (candidate is! AnnotationElement) continue;
          if (candidate.attachedImageId != element.id) continue;
          elements[i] = _translateAnnotation(candidate, delta);
        }
      }
    } else if (element is AnnotationElement) {
      if (element.type == AnnotationType.text ||
          element.type == AnnotationType.commentBubble) {
        final oldBounds = ViewerCompositionHelper.annotationBounds(element);
        final ratio = oldBounds.width <= 1 ? 1.0 : width / oldBounds.width;
        final textSize = (element.textSize * ratio).clamp(10, 120).toDouble();
        elements[index] = element.copyWith(textSize: textSize);
      } else if (element.type == AnnotationType.pencil &&
          element.points.isNotEmpty) {
        final oldBounds = ViewerCompositionHelper.annotationBounds(element);
        final sx = oldBounds.width <= 1 ? 1.0 : width / oldBounds.width;
        final sy = oldBounds.height <= 1 ? 1.0 : height / oldBounds.height;
        final transformed = element.points
            .map(
              (point) => Offset(
                element.position.dx + (point.dx - oldBounds.left) * sx,
                element.position.dy + (point.dy - oldBounds.top) * sy,
              ),
            )
            .toList(growable: false);
        elements[index] = element.copyWith(
          points: transformed,
          clearEndPosition: true,
        );
      } else {
        elements[index] = element.copyWith(
          endPosition: element.position + Offset(width, height),
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
      elements.removeWhere(
        (element) =>
            element is AnnotationElement &&
            element.attachedImageId == target.id,
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
    final imageCount = images.length;
    final focusImageId = imageCount == 1 ? images.first.id : null;
    final saveAsComposite = imageCount > 1;
    final outputNoExt = saveAsComposite
        ? _composedOutputNoExt(activeImagePath)
        : _stripFileExtension(activeImagePath);

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
      await _saveFrameSidecar(activeImagePath, state.frame);
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
    final rawSize = Size(image.width.toDouble(), image.height.toDouble());
    final visualSize = ImageFrameComponentService.fitImageInsideFrame(
      rawSize,
      frameSize,
      maxFillRatio: 0.84,
    );
    final centeredPosition = Offset(
      ((frameSize.width - visualSize.width) / 2)
          .clamp(0, frameSize.width)
          .toDouble(),
      ((frameSize.height - visualSize.height) / 2)
          .clamp(0, frameSize.height)
          .toDouble(),
    );

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
    return _constrainImagesToCanvas(frame);
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
      'version': 1,
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

  String? _findTopImageIdAtPoint(List<CanvasElement> elements, Offset point) {
    final images = elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final image in images) {
      final bounds = image.position & image.size;
      if (bounds.contains(point)) {
        return image.id;
      }
    }
    return null;
  }

  Offset _clampPointToCanvas(Offset point, Size frameSize) {
    final x = point.dx.clamp(0, frameSize.width).toDouble();
    final y = point.dy.clamp(0, frameSize.height).toDouble();
    return Offset(x, y);
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

  FrameState _constrainImagesToCanvas(FrameState frame) {
    final elements = List<CanvasElement>.from(frame.elements);
    final imageDeltas = <String, Offset>{};

    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      if (element is! ImageFrameComponent) continue;

      final constrained = ImageFrameComponentService.constrainToCanvas(
        component: element,
        frameSize: frame.canvasSize,
      );
      imageDeltas[element.id] = constrained.position - element.position;
      elements[i] = constrained;
    }

    if (imageDeltas.isNotEmpty) {
      for (var i = 0; i < elements.length; i++) {
        final element = elements[i];
        if (element is! AnnotationElement) continue;

        final attachedId = element.attachedImageId;
        if (attachedId == null) continue;
        final delta = imageDeltas[attachedId];
        if (delta == null || delta == Offset.zero) continue;
        elements[i] = _translateAnnotation(element, delta);
      }
    }

    return frame.copyWith(elements: elements);
  }

  String _sidecarPathForImage(String imagePath) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}$name.qav.json';
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

    final exportRect = _resolveExportRect(
      frame,
      focusImageId: focusImageId,
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
        // Expandir para incluir anotaciones adjuntas o solapadas.
        for (final element in frame.elements.whereType<AnnotationElement>()) {
          final bounds = ViewerCompositionHelper.annotationBounds(element);
          final isAttached = element.attachedImageId == focusImageId;
          final overlaps = bounds.overlaps(exportRect);
          if (isAttached || overlaps) {
            exportRect = exportRect.expandToInclude(bounds);
          }
        }
        return exportRect.inflate(2);
      }
    }

    // Caso 2: Exportar toda la composición (todas las imágenes y anotaciones).
    exportRect = ViewerCompositionHelper.elementBounds(frame.elements.first);
    for (var i = 1; i < frame.elements.length; i++) {
      exportRect = exportRect.expandToInclude(
        ViewerCompositionHelper.elementBounds(frame.elements[i]),
      );
    }

    // Retornamos el área exacta de los elementos con un pequeño margen,
    // ignorando el tamaño del "canvas" de trabajo que puede ser mucho mayor.
    return exportRect.inflate(4);
  }

  static int _nextZ(List<CanvasElement> elements) {
    if (elements.isEmpty) return 0;
    final top = elements.map((e) => e.zIndex).reduce(math.max);
    return top + 1;
  }

  static List<CanvasElement> _normalizeZ(List<CanvasElement> elements) {
    final images = elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => b.zIndex.compareTo(a.zIndex));
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
