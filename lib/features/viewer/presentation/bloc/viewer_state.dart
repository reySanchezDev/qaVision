import 'package:equatable/equatable.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Estados del BLoC del Visor.
class ViewerState extends Equatable {
  /// Crea un [ViewerState].
  const ViewerState({
    this.frame = const FrameState(),
    this.activeTool = AnnotationType.rectangle,
    this.activeColor = 0xFFFF0000, // Rojo por defecto (§9.5)
    this.activeStrokeWidth = 4.0,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isDrawing = false,
    this.isLoading = false,
    this.recentCaptures = const [],
    this.selectedElementId,
    this.errorMessage,
  });

  /// Estado actual del lienzo (imágenes y anotaciones).
  final FrameState frame;

  /// Herramienta seleccionada actualmente.
  final AnnotationType activeTool;

  /// Color activo para nuevas anotaciones.
  final int activeColor;

  /// Grosor activo para nuevas anotaciones.
  final double activeStrokeWidth;

  /// Historial para deshacer (§9.4).
  final List<FrameState> undoStack;

  /// Historial para rehacer (§9.4).
  final List<FrameState> redoStack;

  /// Indica si hay un trazo en curso.
  final bool isDrawing;

  /// Indica si se está cargando/componiendo la imagen.
  final bool isLoading;

  /// Lista de rutas de capturas recientes (§12.1).
  final List<String> recentCaptures;

  /// ID del elemento seleccionado actualmente (§7.0).
  final String? selectedElementId;

  /// Mensaje de error para mostrar al usuario.
  final String? errorMessage;

  /// Crea una copia de este estado con los campos dados cambiados.
  ViewerState copyWith({
    FrameState? frame,
    AnnotationType? activeTool,
    int? activeColor,
    double? activeStrokeWidth,
    List<FrameState>? undoStack,
    List<FrameState>? redoStack,
    bool? isDrawing,
    bool? isLoading,
    List<String>? recentCaptures,
    String? selectedElementId,
    String? errorMessage,
  }) {
    return ViewerState(
      frame: frame ?? this.frame,
      activeTool: activeTool ?? this.activeTool,
      activeColor: activeColor ?? this.activeColor,
      activeStrokeWidth: activeStrokeWidth ?? this.activeStrokeWidth,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isDrawing: isDrawing ?? this.isDrawing,
      isLoading: isLoading ?? this.isLoading,
      recentCaptures: recentCaptures ?? this.recentCaptures,
      selectedElementId: selectedElementId ?? this.selectedElementId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    frame,
    activeTool,
    activeColor,
    activeStrokeWidth,
    undoStack,
    redoStack,
    isDrawing,
    isLoading,
    recentCaptures,
    selectedElementId,
    errorMessage,
  ];
}
