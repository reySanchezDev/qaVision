import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/pages/viewer_page_intents.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_viewport_transform_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_canvas_resize_policy.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_captures_strip.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_strip/recent_strip_save_indicator.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas_drop_target.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_empty_state_overlay.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_layers_panel.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_rich_text_panel_runtime.dart';
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
  bool _showLayersPanel = false;
  final ViewerLayersDockSide _layersDockSide = ViewerLayersDockSide.right;
  fq.QuillController? _richTextController;
  FocusNode? _richTextFocusNode;
  ScrollController? _richTextScrollController;
  String? _activeRichTextPanelId;
  String? _lastRichTextDeltaJson;
  bool _syncingRichTextController = false;
  bool _pendingRichTextFocus = false;
  bool _isRichTextEditing = false;

  @override
  void dispose() {
    _disposeRichTextEditor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showRecentStrip = _resolveShowRecentStrip(context);
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
          ViewerUndoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyY, control: true):
          ViewerRedoIntent(),
    };
    if (!_shouldHandleDeleteAsTextInput()) {
      shortcuts.addAll(const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.delete): ViewerDeleteIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): ViewerDeleteIntent(),
      });
    }

    return Shortcuts(
      shortcuts: shortcuts,
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
              if (_shouldHandleDeleteAsTextInput()) {
                return null;
              }
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
            body: BlocConsumer<ViewerBloc, ViewerState>(
              listener: (context, state) {
                _syncRichTextEditor(state);
              },
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
                        builder: (_) => ViewerToolbar(
                          showLayersPanel: _showLayersPanel,
                          layersDockSide: _layersDockSide,
                          onToggleLayersPanel: _toggleLayersPanel,
                          richTextRuntime: _buildRichTextRuntime(state),
                        ),
                      ),
                      Expanded(
                        child: ViewerSectionBoundary(
                          sectionName: 'canvas',
                          builder: (_) => LayoutBuilder(
                            builder: (context, canvasConstraints) {
                              return Stack(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ColoredBox(
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
                                                  currentSize:
                                                      state.frame.canvasSize,
                                                );
                                                final maxZoom =
                                                    _maxZoomForState(state);
                                                final effectiveZoom =
                                                    state.canvasZoom.clamp(
                                                  ViewerViewportTransformService
                                                      .defaultViewMinZoom,
                                                  maxZoom,
                                                );

                                                return ClipRect(
                                                  child: Center(
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color:
                                                                Colors.black38,
                                                            blurRadius: 20,
                                                          ),
                                                        ],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child:
                                                          ViewerCanvasDropTarget(
                                                        child: SizedBox(
                                                          width: state
                                                              .frame
                                                              .canvasSize
                                                              .width,
                                                          height: state
                                                              .frame
                                                              .canvasSize
                                                              .height,
                                                          child: Stack(
                                                            children: [
                                                              ViewerCanvas(
                                                                contentZoom:
                                                                    effectiveZoom,
                                                                onRichTextPanelEditRequested:
                                                                    _beginRichTextEditing,
                                                                hiddenElementId:
                                                                    _isRichTextEditing
                                                                    ? _activeRichTextPanelId
                                                                    : null,
                                                              ),
                                                              ..._buildInlineRichTextOverlays(
                                                                state,
                                                                effectiveZoom,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!state.isLoading &&
                                      state.frame.elements.isEmpty)
                                    const ViewerEmptyStateOverlay(),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (showRecentStrip)
                        ViewerSectionBoundary(
                          sectionName: 'recent_strip',
                          fallbackHeight: 176,
                          builder: (_) => RecentCapturesStrip(
                            utilityPane: _buildBottomUtilityPane(state),
                          ),
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

  List<Widget> _buildInlineRichTextOverlays(
    ViewerState state,
    double effectiveZoom,
  ) {
    if (!_isRichTextEditing) {
      return const <Widget>[];
    }
    final panel = _selectedRichTextPanel(state);
    final controller = _richTextController;
    final focusNode = _richTextFocusNode;
    final scrollController = _richTextScrollController;
    if (panel == null ||
        controller == null ||
        focusNode == null ||
        scrollController == null) {
      return const <Widget>[];
    }

    final displayRect = ViewerCompositionHelper.richTextPanelRect(
      panel,
      elements: state.frame.elements,
      imageZoom: effectiveZoom,
    );
    final panelScale = _richTextPanelScale(panel, displayRect);
    final padding = _richTextPanelPadding(panelScale);
    final borderRadius = (18 * panelScale).clamp(8, 24).toDouble();
    final borderWidth =
        (panel.panelBorderWidth * panelScale).clamp(0, 8).toDouble();
    final innerRect = Rect.fromLTWH(
      displayRect.left + padding.left,
      displayRect.top + padding.top,
      math.max(32, displayRect.width - padding.horizontal),
      math.max(40, displayRect.height - padding.vertical),
    );

    if (innerRect.width <= 0 || innerRect.height <= 0) {
      return const <Widget>[];
    }

    final baseStyle = _richTextPanelBaseStyle(panel, panelScale);
    if (_pendingRichTextFocus && focusNode.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _activeRichTextPanelId != panel.id) return;
        focusNode.requestFocus();
        _pendingRichTextFocus = false;
      });
    }

    return <Widget>[
      Positioned.fromRect(
        rect: displayRect,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(panel.backgroundColor),
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderWidth > 0
                  ? Border.all(
                      color: Color(panel.panelBorderColor),
                      width: borderWidth,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: padding,
                child: fq.QuillEditor.basic(
                  key: ValueKey('rich-text-inline-${panel.id}'),
                  controller: controller,
                  focusNode: focusNode,
                  scrollController: scrollController,
                  config: fq.QuillEditorConfig(
                    autoFocus: false,
                    padding: EdgeInsets.zero,
                    scrollable: true,
                    expands: true,
                    enableSelectionToolbar: false,
                    showCursor: true,
                    customStyles: _buildQuillStyles(baseStyle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  AnnotationElement? _selectedRichTextPanel(ViewerState state) {
    final selectedId = state.selectedElementId;
    if (selectedId == null) {
      return null;
    }

    for (final element in state.frame.elements) {
      if (element is AnnotationElement &&
          element.id == selectedId &&
          element.type == AnnotationType.richTextPanel) {
        return element;
      }
    }
    return null;
  }

  void _syncRichTextEditor(ViewerState state) {
    final panel = _selectedRichTextPanel(state);
    if (panel == null) {
      _disposeRichTextEditor();
      return;
    }

    final nextDelta = _normalizeRichTextDelta(
      panel.richTextDelta,
      fallbackPlainText: panel.text,
    );

    if (_activeRichTextPanelId != panel.id || _richTextController == null) {
      _disposeRichTextEditor();
      final controller = fq.QuillController(
        document: _documentFromDeltaJson(nextDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
      controller.addListener(_handleRichTextControllerChanged);
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (!mounted) {
          return;
        }
        if (!focusNode.hasFocus) {
          _flushRichTextControllerToState(force: true);
          if (_isRichTextEditing) {
            _isRichTextEditing = false;
          }
        }
        if (mounted) {
          setState(() {});
        }
      });
      _richTextController = controller;
      _richTextFocusNode = focusNode;
      _richTextScrollController = ScrollController();
      _activeRichTextPanelId = panel.id;
      _lastRichTextDeltaJson = nextDelta;
      _pendingRichTextFocus = state.activeTool == AnnotationType.richTextPanel;
      _isRichTextEditing = _pendingRichTextFocus;
      setState(() {});
      return;
    }

    if (_lastRichTextDeltaJson != nextDelta && !_syncingRichTextController) {
      _syncingRichTextController = true;
      _richTextController!
        ..document = _documentFromDeltaJson(nextDelta)
        ..updateSelection(
          const TextSelection.collapsed(offset: 0),
          fq.ChangeSource.local,
        );
      _lastRichTextDeltaJson = nextDelta;
      _syncingRichTextController = false;
      setState(() {});
      return;
    }
  }

  void _disposeRichTextEditor() {
    _richTextController?.removeListener(_handleRichTextControllerChanged);
    _richTextController?.dispose();
    _richTextController = null;
    _richTextFocusNode?.dispose();
    _richTextFocusNode = null;
    _richTextScrollController?.dispose();
    _richTextScrollController = null;
    _activeRichTextPanelId = null;
    _lastRichTextDeltaJson = null;
    _pendingRichTextFocus = false;
    _isRichTextEditing = false;
    if (mounted) {
      setState(() {});
    }
  }

  bool _shouldHandleDeleteAsTextInput() {
    if (_richTextFocusNode?.hasFocus ?? false) {
      return true;
    }

    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  void _handleRichTextControllerChanged() {
    final controller = _richTextController;
    if (!mounted || controller == null) {
      return;
    }
    if (_syncingRichTextController) {
      setState(() {});
      return;
    }

    final deltaJson = jsonEncode(controller.document.toDelta().toJson());
    if (deltaJson == _lastRichTextDeltaJson) {
      setState(() {});
      return;
    }
    _lastRichTextDeltaJson = deltaJson;
    context.read<ViewerBloc>().add(
      ViewerSelectedElementRichTextUpdated(
        plainText: _plainTextFromDocument(controller.document),
        deltaJson: deltaJson,
      ),
    );
    setState(() {});
  }

  void _flushRichTextControllerToState({bool force = false}) {
    final controller = _richTextController;
    final panelId = _activeRichTextPanelId;
    if (!mounted || controller == null || panelId == null || panelId.isEmpty) {
      return;
    }

    final deltaJson = jsonEncode(controller.document.toDelta().toJson());
    if (!force && deltaJson == _lastRichTextDeltaJson) {
      return;
    }
    _lastRichTextDeltaJson = deltaJson;
    context.read<ViewerBloc>().add(
      ViewerSelectedElementRichTextUpdated(
        plainText: _plainTextFromDocument(controller.document),
        deltaJson: deltaJson,
      ),
    );
  }

  ViewerRichTextPanelRuntime? _buildRichTextRuntime(ViewerState state) {
    final controller = _richTextController;
    final focusNode = _richTextFocusNode;
    if (controller == null || focusNode == null) {
      return null;
    }
    final hasExpandedSelection =
        controller.selection.isValid && !controller.selection.isCollapsed;
    final style = controller.getSelectionStyle().attributes;
    final selectedTextColor = _parseQuillHexColor(
      style[fq.Attribute.color.key]?.value,
    );
    final selectedHighlightColor = _parseQuillHexColor(
      style[fq.Attribute.background.key]?.value,
    );
    final currentAlignment = _panelAlignmentFromQuillValue(
      style[fq.Attribute.align.key]?.value as String?,
    );
    return ViewerRichTextPanelRuntime(
      hasSelection: hasExpandedSelection,
      boldActive: style.containsKey(fq.Attribute.bold.key),
      italicActive: style.containsKey(fq.Attribute.italic.key),
      highlightActive: selectedHighlightColor != null,
      currentAlignment: currentAlignment,
      selectedTextColor: selectedTextColor,
      selectedHighlightColor: selectedHighlightColor,
      requestFocus: () => _beginRichTextEditing(_activeRichTextPanelId),
      applyTextColor: _applyRichTextColor,
      applyHighlightColor: _applyRichTextHighlightColor,
      applyAlignment: _applyRichTextAlignment,
      clearHighlight: _clearRichTextHighlight,
      toggleBold: _toggleRichTextBold,
      toggleItalic: _toggleRichTextItalic,
    );
  }

  void _beginRichTextEditing(String? panelId) {
    if (!mounted || panelId == null || panelId.isEmpty) {
      return;
    }
    if (_activeRichTextPanelId != panelId || _richTextFocusNode == null) {
      _pendingRichTextFocus = true;
      _isRichTextEditing = true;
      setState(() {});
      return;
    }
    _pendingRichTextFocus = true;
    _isRichTextEditing = true;
    setState(() {});
  }

  void _applyRichTextColor(int color) {
    final controller = _richTextController;
    if (controller == null) return;
    controller.formatSelection(
      fq.Attribute.clone(
        fq.Attribute.color,
        '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      ),
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  void _applyRichTextHighlightColor(int color) {
    final controller = _richTextController;
    if (controller == null) return;
    controller.formatSelection(
      fq.Attribute.clone(
        fq.Attribute.background,
        '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      ),
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  void _clearRichTextHighlight() {
    final controller = _richTextController;
    if (controller == null) return;
    controller.formatSelection(
      fq.Attribute.clone(fq.Attribute.background, null),
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  void _toggleRichTextBold() {
    final controller = _richTextController;
    if (controller == null) return;
    final hasBold = controller
        .getSelectionStyle()
        .attributes
        .containsKey(fq.Attribute.bold.key);
    controller.formatSelection(
      hasBold ? fq.Attribute.clone(fq.Attribute.bold, null) : fq.Attribute.bold,
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  void _toggleRichTextItalic() {
    final controller = _richTextController;
    if (controller == null) return;
    final hasItalic = controller
        .getSelectionStyle()
        .attributes
        .containsKey(fq.Attribute.italic.key);
    controller.formatSelection(
      hasItalic
          ? fq.Attribute.clone(fq.Attribute.italic, null)
          : fq.Attribute.italic,
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  void _applyRichTextAlignment(ViewerTextPanelAlignment alignment) {
    final controller = _richTextController;
    if (controller == null) return;
    controller.formatSelection(
      fq.Attribute.clone(
        fq.Attribute.align,
        _quillAlignmentValue(alignment),
      ),
    );
    _flushRichTextControllerToState(force: true);
    _richTextFocusNode?.requestFocus();
  }

  fq.DefaultStyles _buildQuillStyles(TextStyle baseStyle) {
    final paragraph = fq.DefaultTextBlockStyle(
      baseStyle.copyWith(height: 1.35),
      fq.HorizontalSpacing.zero,
      fq.VerticalSpacing.zero,
      fq.VerticalSpacing.zero,
      null,
    );
    return fq.DefaultStyles(
      paragraph: paragraph,
      placeHolder: paragraph,
      bold: baseStyle.copyWith(fontWeight: FontWeight.w700),
      italic: baseStyle.copyWith(fontStyle: FontStyle.italic),
      color: baseStyle.color,
    );
  }

  TextStyle _richTextPanelBaseStyle(
    AnnotationElement panel,
    double panelScale,
  ) {
    return TextStyle(
      color: Color(panel.color),
      fontSize: math.max(8, panel.textSize * panelScale),
      fontFamily: panel.fontFamily,
      fontWeight: panel.isBold ? FontWeight.w700 : FontWeight.w500,
      fontStyle: panel.isItalic ? FontStyle.italic : FontStyle.normal,
      height: 1.35,
    );
  }

  EdgeInsets _richTextPanelPadding(double panelScale) {
    final horizontal = (18 * panelScale).clamp(8, 30).toDouble();
    final top = (16 * panelScale).clamp(8, 24).toDouble();
    final bottom = (18 * panelScale).clamp(8, 30).toDouble();
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  double _richTextPanelScale(
    AnnotationElement panel,
    Rect displayRect,
  ) {
    final logicalRect = panel.endPosition == null
        ? Rect.fromLTWH(panel.position.dx, panel.position.dy, 360, 220)
        : Rect.fromLTRB(
            math.min(panel.position.dx, panel.endPosition!.dx),
            math.min(panel.position.dy, panel.endPosition!.dy),
            math.max(panel.position.dx, panel.endPosition!.dx),
            math.max(panel.position.dy, panel.endPosition!.dy),
          );
    if (logicalRect.width <= 0.001) {
      return 1;
    }
    return (displayRect.width / logicalRect.width).clamp(0.25, 4.0);
  }

  fq.Document _documentFromDeltaJson(String deltaJson) {
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is List) {
        return fq.Document.fromJson(decoded);
      }
    } on FormatException {
      // Fallback below.
    }
    return fq.Document.fromJson(
      jsonDecode(_normalizeRichTextDelta(null, fallbackPlainText: '')) as List,
    );
  }

  String _normalizeRichTextDelta(
    String? serialized, {
    required String fallbackPlainText,
  }) {
    final trimmed = serialized?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final plain = fallbackPlainText.trimRight();
    return jsonEncode(<Map<String, dynamic>>[
      {'insert': plain.isEmpty ? '\n' : '$plain\n'},
    ]);
  }

  String _plainTextFromDocument(fq.Document document) {
    return document.toPlainText().replaceFirst(RegExp(r'\n$'), '');
  }

  String _quillAlignmentValue(ViewerTextPanelAlignment alignment) {
    return switch (alignment) {
      ViewerTextPanelAlignment.left => 'left',
      ViewerTextPanelAlignment.center => 'center',
      ViewerTextPanelAlignment.right => 'right',
      ViewerTextPanelAlignment.justify => 'justify',
    };
  }

  ViewerTextPanelAlignment? _panelAlignmentFromQuillValue(String? value) {
    return switch (value) {
      'left' => ViewerTextPanelAlignment.left,
      'center' => ViewerTextPanelAlignment.center,
      'right' => ViewerTextPanelAlignment.right,
      'justify' => ViewerTextPanelAlignment.justify,
      _ => null,
    };
  }

  int? _parseQuillHexColor(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final normalized = raw.trim().replaceFirst('#', '');
    if (normalized.length == 6) {
      return int.tryParse('FF$normalized', radix: 16);
    }
    if (normalized.length == 8) {
      return int.tryParse(normalized, radix: 16);
    }
    return null;
  }

  Widget _buildBottomUtilityPane(ViewerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecentStripSaveIndicator(
          isAutoSaving: state.isAutoSaving,
          hasFinalSave: (state.autoSavePath ?? '').trim().isNotEmpty,
          recoveredSession: state.recoveredSession,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: const Text(
            'Vista y zoom',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ViewerZoomControls(
          zoom: state.canvasZoom.clamp(
            ViewerViewportTransformService.defaultViewMinZoom,
            _maxZoomForState(state),
          ),
          fitZoom: _fitZoomForState(
            state,
            _lastViewportSize,
          ),
          minEditableZoom:
              ViewerViewportTransformService.defaultEditableMinZoom,
          canZoomOut:
              state.canvasZoom >
              ViewerViewportTransformService.defaultEditableMinZoom + 0.001,
          onFitToScreen: () => _fitToScreen(state),
          onActualSize: () => _setActualSize(state),
          onZoomIn: () => _zoomIn(state),
          onZoomOut: () => _zoomOut(state),
        ),
        const Spacer(),
      ],
    );
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
        1.0.clamp(
          ViewerViewportTransformService.defaultEditableMinZoom,
          maxZoom,
        ),
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
    if (_handleRichTextPointerScroll(event, state)) {
      return;
    }
    if (event.scrollDelta.dy > 0) {
      _zoomOut(state);
      return;
    }
    if (event.scrollDelta.dy < 0) {
      _zoomIn(state);
    }
  }

  bool _handleRichTextPointerScroll(
    PointerScrollEvent event,
    ViewerState state,
  ) {
    if (!_isRichTextEditing) {
      return false;
    }
    final panel = _selectedRichTextPanel(state);
    final scrollController = _richTextScrollController;
    if (panel == null ||
        scrollController == null ||
        !scrollController.hasClients) {
      return false;
    }

    final effectiveZoom = state.canvasZoom.clamp(
      ViewerViewportTransformService.defaultViewMinZoom,
      _maxZoomForState(state),
    );
    final displayRect = ViewerCompositionHelper.richTextPanelRect(
      panel,
      elements: state.frame.elements,
      imageZoom: effectiveZoom,
    );
    if (!displayRect.contains(event.localPosition)) {
      return false;
    }

    final position = scrollController.position;
    final nextOffset = (position.pixels + event.scrollDelta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((nextOffset - position.pixels).abs() < 0.1) {
      return true;
    }
    scrollController.jumpTo(nextOffset);
    return true;
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
}
