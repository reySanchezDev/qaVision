import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart'; // Added missing import for ShareService
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:uuid/uuid.dart';

/// Gestión de estado del Visor / Editor de capturas (§9).
class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  /// Crea una instancia del [ViewerBloc].
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
    on<ViewerAnnotationStarted>(_onAnnotationStarted);
    on<ViewerAnnotationUpdated>(_onAnnotationUpdated);
    on<ViewerAnnotationFinished>(_onAnnotationFinished);
    on<ViewerUndoRequested>(_onUndoRequested);
    on<ViewerRedoRequested>(_onRedoRequested);
    on<ViewerExportRequested>(_onExportRequested);
    on<ViewerCopyRequested>(_onCopyRequested);
    on<ViewerShareRequested>(_onShareRequested);
    on<ViewerRecentCapturesRequested>(_onRecentCapturesRequested);
    on<ViewerImageAdded>(_onImageAdded);
    on<ViewerElementSelected>(_onElementSelected);
    on<ViewerElementMoved>(_onElementMoved);
    on<ViewerElementDeleted>(_onElementDeleted);
    on<ViewerElementZOrderChanged>(_onElementZOrderChanged);
    on<ViewerBackgroundColorChanged>(_onBackgroundColorChanged);
  }

  final FileSystemService _fileSystemService;
  final ClipboardService _clipboardService;
  final ShareService _shareService;
  static const _uuid = Uuid();

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final image = await _loadImage(event.imagePath);

      final canvasSize = ui.Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final imageElement = ImageElement(
        id: _uuid.v4(),
        path: event.imagePath,
        position: ui.Offset.zero,
        size: canvasSize,
        zIndex: 0,
        image: image,
      );

      final projectPath = io.File(event.imagePath).parent.path;
      final recentCaptures = await _fileSystemService.listJpgFiles(projectPath);

      emit(
        state.copyWith(
          frame: FrameState(
            canvasSize: canvasSize,
            elements: [imageElement],
          ),
          recentCaptures: recentCaptures,
          isLoading: false,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error al cargar imagen: $e',
        ),
      );
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final bytes = await _fileSystemService.readFileAsBytes(path);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _onToolChanged(ViewerToolChanged event, Emitter<ViewerState> emit) {
    emit(state.copyWith(activeTool: event.tool));
  }

  void _onPropertiesChanged(
    ViewerPropertiesChanged event,
    Emitter<ViewerState> emit,
  ) {
    emit(
      state.copyWith(
        activeColor: event.color ?? state.activeColor,
        activeStrokeWidth: event.strokeWidth ?? state.activeStrokeWidth,
      ),
    );
  }

  void _onAnnotationStarted(
    ViewerAnnotationStarted event,
    Emitter<ViewerState> emit,
  ) {
    var text = '';
    if (state.activeTool == AnnotationType.stepMarker) {
      final markerCount = state.frame.elements
          .whereType<AnnotationElement>()
          .where((e) => e.type == AnnotationType.stepMarker)
          .length;
      text = (markerCount + 1).toString();
    }

    final newAnnotation = AnnotationElement(
      id: _uuid.v4(),
      type: state.activeTool,
      color: state.activeColor,
      strokeWidth: state.activeStrokeWidth,
      position: event.position,
      zIndex: state.frame.elements.length + 1,
      points: [event.position],
      text: text,
    );

    final newElements = List<CanvasElement>.from(state.frame.elements)
      ..add(newAnnotation);

    emit(
      state.copyWith(
        frame: state.frame.copyWith(elements: newElements),
        isDrawing: true,
      ),
    );
  }

  void _onAnnotationUpdated(
    ViewerAnnotationUpdated event,
    Emitter<ViewerState> emit,
  ) {
    if (!state.isDrawing) return;

    final elements = List<CanvasElement>.from(state.frame.elements);
    final lastIndex = elements.length - 1;
    final lastElement = elements[lastIndex];

    if (lastElement is AnnotationElement) {
      AnnotationElement updated;
      if (lastElement.type == AnnotationType.pencil) {
        updated = lastElement.copyWith(
          points: List<ui.Offset>.from(lastElement.points)..add(event.position),
        );
      } else if (lastElement.type == AnnotationType.stepMarker) {
        updated = lastElement.copyWith(position: event.position);
      } else {
        updated = lastElement.copyWith(endPosition: event.position);
      }
      elements[lastIndex] = updated;
      emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
    }
  }

  void _onAnnotationFinished(
    ViewerAnnotationFinished event,
    Emitter<ViewerState> emit,
  ) {
    if (!state.isDrawing) return;

    final newUndoStack = List<FrameState>.from(state.undoStack)
      ..add(state.frame);

    emit(
      state.copyWith(
        undoStack: newUndoStack,
        redoStack: const [],
        isDrawing: false,
      ),
    );
  }

  void _onUndoRequested(ViewerUndoRequested event, Emitter<ViewerState> emit) {
    if (state.undoStack.isEmpty) return;

    final currentFrame = state.frame;
    final previousFrame = state.undoStack.last;

    final newUndoStack = List<FrameState>.from(state.undoStack)..removeLast();
    final newRedoStack = List<FrameState>.from(state.redoStack)
      ..add(currentFrame);

    emit(
      state.copyWith(
        frame: previousFrame,
        undoStack: newUndoStack,
        redoStack: newRedoStack,
      ),
    );
  }

  void _onRedoRequested(ViewerRedoRequested event, Emitter<ViewerState> emit) {
    if (state.redoStack.isEmpty) return;

    final currentFrame = state.frame;
    final nextFrame = state.redoStack.last;

    final newRedoStack = List<FrameState>.from(state.redoStack)..removeLast();
    final newUndoStack = List<FrameState>.from(state.undoStack)
      ..add(currentFrame);

    emit(
      state.copyWith(
        frame: nextFrame,
        undoStack: newUndoStack,
        redoStack: newRedoStack,
      ),
    );
  }

  Future<void> _onExportRequested(
    ViewerExportRequested event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final bytes = await _generateCompositionBytes();

      // Obtener la ruta base del primer ImageElement (la captura original)
      final mainImage = state.frame.elements
          .whereType<ImageElement>()
          .firstOrNull;
      if (mainImage == null) throw Exception('No se encontró imagen base');

      // Quitar la extensión del path original para saveAsJpg
      final outputPath = mainImage.path.replaceAll('.jpg', '');

      await _fileSystemService.saveAsJpg(
        imageBytes: bytes,
        outputPath: outputPath,
      );

      // Refrescar tira de capturas
      final projectPath = io.File(mainImage.path).parent.path;
      final recentCaptures = await _fileSystemService.listJpgFiles(projectPath);

      emit(state.copyWith(isLoading: false, recentCaptures: recentCaptures));
    } on Exception catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: 'Error al exportar: $e'),
      );
    }
  }

  Future<void> _onCopyRequested(
    ViewerCopyRequested event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final bytes = await _generateCompositionBytes();
      await _clipboardService.copyImageToClipboard(bytes);
      emit(state.copyWith(isLoading: false));
    } on Exception catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: 'Error al copiar: $e'),
      );
    }
  }

  Future<void> _onShareRequested(
    ViewerShareRequested event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final bytes = await _generateCompositionBytes();
      await _shareService.shareImageBytes(
        bytes,
        'qavision_capture.jpg',
        text: 'Captura compartida desde QAVision',
      );
      emit(state.copyWith(isLoading: false));
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error al compartir: $e',
        ),
      );
    }
  }

  Future<Uint8List> _generateCompositionBytes() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    ViewerCompositionHelper.paintFrame(canvas, state.frame);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      state.frame.canvasSize.width.toInt(),
      state.frame.canvasSize.height.toInt(),
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Error al generar bytes de imagen');

    return byteData.buffer.asUint8List();
  }

  Future<void> _onRecentCapturesRequested(
    ViewerRecentCapturesRequested event,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final files = await _fileSystemService.listJpgFiles(event.projectPath);
      emit(state.copyWith(recentCaptures: files));
    } on Exception catch (_) {
      // Silencioso o manejar error de listado
    }
  }

  Future<void> _onImageAdded(
    ViewerImageAdded event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final image = await _loadImage(event.imagePath);
      final canvasSize = ui.Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final elementCount = state.frame.elements.length;
      final newImage = ImageElement(
        id: _uuid.v4(),
        path: event.imagePath,
        position: ui.Offset(
          20.0 * elementCount,
          20.0 * elementCount,
        ), // Escalonado para visibilidad
        size: canvasSize,
        zIndex: elementCount,
        image: image,
      );

      final newElements = List<CanvasElement>.from(state.frame.elements)
        ..add(newImage);

      emit(
        state.copyWith(
          frame: state.frame.copyWith(elements: newElements),
          isLoading: false,
        ),
      );
    } on Exception catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onElementSelected(
    ViewerElementSelected event,
    Emitter<ViewerState> emit,
  ) {
    emit(state.copyWith(selectedElementId: event.elementId));
  }

  void _onElementMoved(
    ViewerElementMoved event,
    Emitter<ViewerState> emit,
  ) {
    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == event.elementId);

    if (index != -1) {
      final element = elements[index];
      CanvasElement updated;

      if (element is ImageElement) {
        updated = element.copyWith(position: event.position);
      } else if (element is AnnotationElement) {
        updated = element.copyWith(position: event.position);
      } else {
        return;
      }

      elements[index] = updated;
      emit(state.copyWith(frame: state.frame.copyWith(elements: elements)));
    }
  }

  void _onElementDeleted(
    ViewerElementDeleted event,
    Emitter<ViewerState> emit,
  ) {
    final elements = List<CanvasElement>.from(state.frame.elements)
      ..removeWhere((e) => e.id == event.elementId);

    emit(
      state.copyWith(
        frame: state.frame.copyWith(elements: elements),
        selectedElementId: state.selectedElementId == event.elementId
            ? null
            : state.selectedElementId,
      ),
    );
  }

  void _onElementZOrderChanged(
    ViewerElementZOrderChanged event,
    Emitter<ViewerState> emit,
  ) {
    final elements = List<CanvasElement>.from(state.frame.elements);
    final index = elements.indexWhere((e) => e.id == event.elementId);

    if (index != -1) {
      final element = elements.removeAt(index);
      if (event.isForward) {
        elements.add(element);
      } else {
        elements.insert(0, element);
      }

      // Re-asignar z-indices basados en la nueva posición en la lista
      final updatedElements = <CanvasElement>[];
      for (var i = 0; i < elements.length; i++) {
        final e = elements[i];
        if (e is ImageElement) {
          updatedElements.add(e.copyWith(zIndex: i));
        } else if (e is AnnotationElement) {
          updatedElements.add(e.copyWith(zIndex: i));
        }
      }

      emit(
        state.copyWith(frame: state.frame.copyWith(elements: updatedElements)),
      );
    }
  }

  void _onBackgroundColorChanged(
    ViewerBackgroundColorChanged event,
    Emitter<ViewerState> emit,
  ) {
    emit(
      state.copyWith(
        frame: state.frame.copyWith(backgroundColor: event.color),
      ),
    );
  }

  @override
  Future<void> close() {
    // Liberar recursos de imagen (§9.0)
    for (final element in state.frame.elements) {
      if (element is ImageElement && element.image is ui.Image) {
        (element.image as ui.Image).dispose();
      }
    }
    for (final frame in state.undoStack) {
      for (final element in frame.elements) {
        if (element is ImageElement && element.image is ui.Image) {
          (element.image as ui.Image).dispose();
        }
      }
    }
    for (final frame in state.redoStack) {
      for (final element in frame.elements) {
        if (element is ImageElement && element.image is ui.Image) {
          (element.image as ui.Image).dispose();
        }
      }
    }
    return super.close();
  }
}
