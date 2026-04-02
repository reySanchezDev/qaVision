import 'package:equatable/equatable.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Viewer/editor state.
class ViewerState extends Equatable {
  /// Creates [ViewerState].
  const ViewerState({
    this.frame = const FrameState(),
    this.canvasZoom = 1,
    this.activeTool = AnnotationType.selection,
    this.activeStepMarkerNext = 1,
    this.activeColor = 0xFFE53935,
    this.activeStrokeWidth = 4,
    this.activeTextSize = 20,
    this.activeOpacity = 0.28,
    this.activeFontFamily = 'Segoe UI',
    this.activeTextBold = false,
    this.activeTextItalic = false,
    this.activeTextShadow = false,
    this.activeTextPanelBackgroundColor = 0xF6FFFFFF,
    this.activeTextPanelBorderColor = 0x61E53935,
    this.activeTextPanelBorderWidth = 1.2,
    this.activeTextHighlightColor = 0xFFFFF59D,
    this.activeTextPanelAlignment = ViewerTextPanelAlignment.justify,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isDrawing = false,
    this.isLoading = false,
    this.isAutoSaving = false,
    this.recentCaptures = const [],
    this.recentProjectPath,
    this.selectedElementId,
    this.autoSavePath,
    this.recoveredSession = false,
    this.errorMessage,
  });

  /// Current frame snapshot.
  final FrameState frame;

  /// Zoom visual aplicado al contenido mostrado en el workspace.
  final double canvasZoom;

  /// Active drawing tool.
  final AnnotationType activeTool;

  /// Next number for the step marker tool.
  final int activeStepMarkerNext;

  /// Active color.
  final int activeColor;

  /// Active stroke width.
  final double activeStrokeWidth;

  /// Active text size.
  final double activeTextSize;

  /// Active opacity for tools that support transparency.
  final double activeOpacity;

  /// Active font family for rich text blocks.
  final String activeFontFamily;

  /// Active bold state for rich text blocks.
  final bool activeTextBold;

  /// Active italic state for rich text blocks.
  final bool activeTextItalic;

  /// Active shadow state for rich text blocks.
  final bool activeTextShadow;

  /// Active background color for rich text blocks.
  final int activeTextPanelBackgroundColor;

  /// Active border color for rich text blocks.
  final int activeTextPanelBorderColor;

  /// Active border width for rich text blocks.
  final double activeTextPanelBorderWidth;

  /// Active highlight color for rich text selections.
  final int activeTextHighlightColor;

  /// Active paragraph alignment for rich text blocks.
  final ViewerTextPanelAlignment activeTextPanelAlignment;

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

  /// `true` cuando el visor reabre una sesion desde borrador de recuperación.
  final bool recoveredSession;

  /// Last user-facing error.
  final String? errorMessage;

  /// True when any element is selected.
  bool get hasSelection => selectedElementId != null;

  /// Creates a copy with optional changes.
  ViewerState copyWith({
    FrameState? frame,
    double? canvasZoom,
    AnnotationType? activeTool,
    int? activeStepMarkerNext,
    int? activeColor,
    double? activeStrokeWidth,
    double? activeTextSize,
    double? activeOpacity,
    String? activeFontFamily,
    bool? activeTextBold,
    bool? activeTextItalic,
    bool? activeTextShadow,
    int? activeTextPanelBackgroundColor,
    int? activeTextPanelBorderColor,
    double? activeTextPanelBorderWidth,
    int? activeTextHighlightColor,
    ViewerTextPanelAlignment? activeTextPanelAlignment,
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
    bool? recoveredSession,
    bool clearRecoveredSession = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ViewerState(
      frame: frame ?? this.frame,
      canvasZoom: canvasZoom ?? this.canvasZoom,
      activeTool: activeTool ?? this.activeTool,
      activeStepMarkerNext: activeStepMarkerNext ?? this.activeStepMarkerNext,
      activeColor: activeColor ?? this.activeColor,
      activeStrokeWidth: activeStrokeWidth ?? this.activeStrokeWidth,
      activeTextSize: activeTextSize ?? this.activeTextSize,
      activeOpacity: activeOpacity ?? this.activeOpacity,
      activeFontFamily: activeFontFamily ?? this.activeFontFamily,
      activeTextBold: activeTextBold ?? this.activeTextBold,
      activeTextItalic: activeTextItalic ?? this.activeTextItalic,
      activeTextShadow: activeTextShadow ?? this.activeTextShadow,
      activeTextPanelBackgroundColor:
          activeTextPanelBackgroundColor ?? this.activeTextPanelBackgroundColor,
      activeTextPanelBorderColor:
          activeTextPanelBorderColor ?? this.activeTextPanelBorderColor,
      activeTextPanelBorderWidth:
          activeTextPanelBorderWidth ?? this.activeTextPanelBorderWidth,
      activeTextHighlightColor:
          activeTextHighlightColor ?? this.activeTextHighlightColor,
      activeTextPanelAlignment:
          activeTextPanelAlignment ?? this.activeTextPanelAlignment,
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
      recoveredSession: clearRecoveredSession
          ? const ViewerState().recoveredSession
          : (recoveredSession ?? this.recoveredSession),
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
    activeStepMarkerNext,
    activeColor,
    activeStrokeWidth,
    activeTextSize,
    activeOpacity,
    activeFontFamily,
    activeTextBold,
    activeTextItalic,
    activeTextShadow,
    activeTextPanelBackgroundColor,
    activeTextPanelBorderColor,
    activeTextPanelBorderWidth,
    activeTextHighlightColor,
    activeTextPanelAlignment,
    undoStack,
    redoStack,
    isDrawing,
    isLoading,
    isAutoSaving,
    recentCaptures,
    recentProjectPath,
    selectedElementId,
    autoSavePath,
    recoveredSession,
    errorMessage,
  ];
}
