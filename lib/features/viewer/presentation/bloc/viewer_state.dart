import 'package:equatable/equatable.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Viewer/editor state.
class ViewerState extends Equatable {
  /// Creates [ViewerState].
  const ViewerState({
    this.frame = const FrameState(),
    this.canvasZoom = 1,
    this.activeTool = AnnotationType.selection,
    this.activeColor = 0xFFE53935,
    this.activeStrokeWidth = 4,
    this.activeTextSize = 20,
    this.activeOpacity = 0.28,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isDrawing = false,
    this.isLoading = false,
    this.isAutoSaving = false,
    this.recentCaptures = const [],
    this.recentProjectPath,
    this.selectedElementId,
    this.autoSavePath,
    this.errorMessage,
  });

  /// Current frame snapshot.
  final FrameState frame;

  /// Zoom visual aplicado al contenido mostrado en el workspace.
  final double canvasZoom;

  /// Active drawing tool.
  final AnnotationType activeTool;

  /// Active color.
  final int activeColor;

  /// Active stroke width.
  final double activeStrokeWidth;

  /// Active text size.
  final double activeTextSize;

  /// Active opacity for tools that support transparency.
  final double activeOpacity;

  /// Undo history.
  final List<FrameState> undoStack;

  /// Redo history.
  final List<FrameState> redoStack;

  /// True while creating an annotation by drag gesture.
  final bool isDrawing;

  /// True while loading image data or doing heavy ops.
  final bool isLoading;

  /// True while autosave is writing composition to disk.
  final bool isAutoSaving;

  /// Recent capture paths.
  final List<String> recentCaptures;

  /// Project folder currently used by the recent captures strip.
  final String? recentProjectPath;

  /// Selected element id (null means no selection).
  final String? selectedElementId;

  /// Current autosave output path.
  final String? autoSavePath;

  /// Last user-facing error.
  final String? errorMessage;

  /// True when any element is selected.
  bool get hasSelection => selectedElementId != null;

  /// Creates a copy with optional changes.
  ViewerState copyWith({
    FrameState? frame,
    double? canvasZoom,
    AnnotationType? activeTool,
    int? activeColor,
    double? activeStrokeWidth,
    double? activeTextSize,
    double? activeOpacity,
    List<FrameState>? undoStack,
    List<FrameState>? redoStack,
    bool? isDrawing,
    bool? isLoading,
    bool? isAutoSaving,
    List<String>? recentCaptures,
    String? recentProjectPath,
    bool clearRecentProjectPath = false,
    String? selectedElementId,
    bool clearSelectedElement = false,
    String? autoSavePath,
    bool clearAutoSavePath = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ViewerState(
      frame: frame ?? this.frame,
      canvasZoom: canvasZoom ?? this.canvasZoom,
      activeTool: activeTool ?? this.activeTool,
      activeColor: activeColor ?? this.activeColor,
      activeStrokeWidth: activeStrokeWidth ?? this.activeStrokeWidth,
      activeTextSize: activeTextSize ?? this.activeTextSize,
      activeOpacity: activeOpacity ?? this.activeOpacity,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isDrawing: isDrawing ?? this.isDrawing,
      isLoading: isLoading ?? this.isLoading,
      isAutoSaving: isAutoSaving ?? this.isAutoSaving,
      recentCaptures: recentCaptures ?? this.recentCaptures,
      recentProjectPath: clearRecentProjectPath
          ? null
          : (recentProjectPath ?? this.recentProjectPath),
      selectedElementId: clearSelectedElement
          ? null
          : (selectedElementId ?? this.selectedElementId),
      autoSavePath: clearAutoSavePath
          ? null
          : (autoSavePath ?? this.autoSavePath),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    frame,
    canvasZoom,
    activeTool,
    activeColor,
    activeStrokeWidth,
    activeTextSize,
    activeOpacity,
    undoStack,
    redoStack,
    isDrawing,
    isLoading,
    isAutoSaving,
    recentCaptures,
    recentProjectPath,
    selectedElementId,
    autoSavePath,
    errorMessage,
  ];
}
