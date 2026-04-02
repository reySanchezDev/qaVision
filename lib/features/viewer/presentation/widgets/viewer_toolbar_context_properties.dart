import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_rich_text_panel_runtime.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_text_dialog.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_primitives.dart';

final List<Color> _viewerRecentAnnotationColors = <Color>[];
final List<Color> _viewerRecentFrameColors = <Color>[];
final List<Color> _viewerRecentHighlightColors = <Color>[];

/// Propiedades contextuales de la barra del visor.
class ViewerToolbarContextProperties extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarContextProperties].
  const ViewerToolbarContextProperties({
    required this.state,
    required this.selectedImage,
    required this.selectedAnnotation,
    required this.richTextRuntime,
    required this.frameDefaultsResolver,
    this.showLeadingSeparator = true,
    super.key,
  });

  /// Estado actual del visor.
  final ViewerState state;

  /// Imagen seleccionada actual (si aplica).
  final ImageFrameComponent? selectedImage;

  /// Anotación seleccionada actual (si aplica).
  final AnnotationElement? selectedAnnotation;

  /// Runtime activo del editor inline del panel enriquecido.
  final ViewerRichTextPanelRuntime? richTextRuntime;

  /// Callback para obtener defaults de frame desde configuración.
  final ViewerFrameDefaults Function(BuildContext context)
  frameDefaultsResolver;

  /// Indica si se muestra el separador visual al inicio.
  final bool showLeadingSeparator;

  @override
  Widget build(BuildContext context) {
    final widgets = _buildContextualProperties(context);
    if (widgets.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  List<Widget> _buildContextualProperties(BuildContext context) {
    if (selectedImage != null) {
      return _buildImageProperties(context, selectedImage!);
    }

    var activeForProperties = state.activeTool;
    if (activeForProperties == AnnotationType.selection &&
        selectedAnnotation != null) {
      activeForProperties = selectedAnnotation!.type;
    }

    final isTextTool =
        activeForProperties == AnnotationType.text ||
        activeForProperties == AnnotationType.richTextPanel ||
        activeForProperties == AnnotationType.commentBubble ||
        activeForProperties == AnnotationType.stepMarker;
    final isRichTextPanelTool =
        activeForProperties == AnnotationType.richTextPanel;
    final isStepMarkerTool = activeForProperties == AnnotationType.stepMarker;
    final isShapeTool =
        activeForProperties == AnnotationType.arrow ||
        activeForProperties == AnnotationType.rectangle ||
        activeForProperties == AnnotationType.circle;
    final isPencilTool = activeForProperties == AnnotationType.pencil;
    final isOpacityTool =
        activeForProperties == AnnotationType.highlighter ||
        activeForProperties == AnnotationType.blur;
    final isColorTool =
        isTextTool || isShapeTool || isPencilTool || isOpacityTool;
    final isEraserTool = activeForProperties == AnnotationType.eraser;
    final effectiveColor = selectedAnnotation?.color ?? state.activeColor;
    final effectiveStrokeWidth =
        selectedAnnotation?.strokeWidth ?? state.activeStrokeWidth;
    final effectiveTextSize = selectedAnnotation?.textSize ?? state.activeTextSize;
    final effectiveOpacity = selectedAnnotation?.opacity ?? state.activeOpacity;
    final effectiveFontFamily =
        selectedAnnotation?.fontFamily ?? state.activeFontFamily;
    final effectiveIsBold = selectedAnnotation?.isBold ?? state.activeTextBold;
    final effectiveIsItalic =
        selectedAnnotation?.isItalic ?? state.activeTextItalic;
    final effectiveHasShadow =
        selectedAnnotation?.hasShadow ?? state.activeTextShadow;
    final effectivePanelBackgroundColor =
        selectedAnnotation?.backgroundColor ??
        state.activeTextPanelBackgroundColor;
    final effectivePanelBorderColor =
        selectedAnnotation?.panelBorderColor ??
        state.activeTextPanelBorderColor;
    final effectivePanelBorderWidth =
        selectedAnnotation?.panelBorderWidth ??
        state.activeTextPanelBorderWidth;
    final effectiveHighlightColor = state.activeTextHighlightColor;
    final effectivePanelAlignment =
        richTextRuntime?.currentAlignment ??
        selectedAnnotation?.panelAlignment ??
        state.activeTextPanelAlignment;

    if (!isColorTool) {
      if (selectedImage == null && selectedAnnotation == null) {
        if (isEraserTool) {
          return const [
            ViewerToolbarGroupSeparator(),
            Text(
              'Borrador: haz clic en una anotacion para eliminarla',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ];
        }
        return const <Widget>[];
      }
      return const <Widget>[];
    }

    final widgets = <Widget>[
      if (showLeadingSeparator) const ViewerToolbarGroupSeparator(),
      ViewerToolbarColorField(
        label: isRichTextPanelTool ? null : 'Color',
        icon: isRichTextPanelTool
            ? Icons.format_color_text
            : Icons.palette_outlined,
        selectedColor: isRichTextPanelTool &&
                richTextRuntime?.selectedTextColor != null
            ? richTextRuntime!.selectedTextColor!
            : effectiveColor,
        swatches: _strokeColorOptions,
        dialogTitle: isRichTextPanelTool
            ? 'Color del texto'
            : 'Selecciona el color de la herramienta',
        recentColors: _viewerRecentAnnotationColors,
        onColorSelected: (color) {
          if (isRichTextPanelTool &&
              richTextRuntime != null &&
              richTextRuntime!.hasSelection) {
            richTextRuntime!.requestFocus();
            richTextRuntime!.applyTextColor(color);
            context.read<ViewerBloc>().add(
              ViewerPropertiesChanged(color: color),
            );
            return;
          }
          _applyAnnotationColor(context, color);
        },
      ),
    ];

    if (isShapeTool || isPencilTool) {
      widgets.addAll([
        SizedBox(
          width: 126,
          child: ViewerToolbarLabeledSlider(
            label: 'Grosor ${state.activeStrokeWidth.toStringAsFixed(0)}',
            min: 1,
            max: 20,
            divisions: 19,
            value: effectiveStrokeWidth.clamp(1, 20).toDouble(),
            onChanged: (value) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(strokeWidth: value),
              );
            },
          ),
        ),
      ]);
    }

    if (isOpacityTool) {
      widgets.addAll([
        SizedBox(
          width: 126,
          child: ViewerToolbarLabeledSlider(
            label: 'Opacidad ${(state.activeOpacity * 100).round()}%',
            min: 0.1,
            max: 1,
            divisions: 18,
            value: effectiveOpacity.clamp(0.1, 1).toDouble(),
            onChanged: (value) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(opacity: value),
              );
            },
          ),
        ),
      ]);
    }

    if (isTextTool) {
      widgets.addAll([
        SizedBox(
          width: 88,
          child: ViewerToolbarLabeledSlider(
            label: 'Tam. ${effectiveTextSize.toStringAsFixed(0)}',
            min: 10,
            max: 56,
            divisions: 23,
            value: effectiveTextSize.clamp(10, 56).toDouble(),
            onChanged: (value) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(textSize: value),
              );
            },
          ),
        ),
      ]);

      if (isStepMarkerTool) {
        widgets.addAll([
          ViewerToolbarActionCluster(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                  'Siguiente ${state.activeStepMarkerNext}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ViewerToolbarToolButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Reiniciar numeracion',
                selected: false,
                framed: false,
                label: 'Reset',
                onPressed: () {
                  context.read<ViewerBloc>().add(
                    const ViewerStepMarkerResetRequested(),
                  );
                },
              ),
            ],
          ),
        ]);
      }

      if (selectedAnnotation != null &&
          (selectedAnnotation!.type == AnnotationType.text ||
              selectedAnnotation!.type == AnnotationType.commentBubble ||
              selectedAnnotation!.type == AnnotationType.stepMarker)) {
        widgets.addAll([
          ViewerToolbarToolButton(
            icon: Icons.edit_note,
            tooltip: 'Editar texto',
            selected: false,
            label: 'Editar',
            onPressed: () async {
              final updated = await ViewerTextDialog.prompt(
                context,
                initialValue: selectedAnnotation!.text,
                title: 'Editar texto',
              );
              if (!context.mounted ||
                  updated == null ||
                  updated.trim().isEmpty) {
                return;
              }
              context.read<ViewerBloc>().add(
                ViewerSelectedElementTextUpdated(updated.trim()),
              );
            },
          ),
        ]);
      }

      if (isRichTextPanelTool) {
        final runtime = richTextRuntime;
        final canFormatSelection = runtime?.hasSelection ?? false;
        widgets.addAll([
          _ViewerToolbarCompactMenuButton<String>(
            label: effectiveFontFamily,
            tooltip: 'Tipo de letra',
            items: _fontFamilyOptions
                .map(
                  (family) => PopupMenuItem<String>(
                    value: family,
                    child: Text(family),
                  ),
                )
                .toList(growable: false),
            onSelected: (family) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(fontFamily: family),
              );
            },
          ),
          ViewerToolbarActionCluster(
            children: [
              ViewerToolbarToolButton(
                icon: Icons.format_bold,
                tooltip: 'Negrita',
                selected: canFormatSelection
                    ? runtime!.boldActive
                    : effectiveIsBold,
                framed: false,
                onPressed: canFormatSelection
                    ? () {
                        runtime!.requestFocus();
                        runtime.toggleBold();
                      }
                    : () {
                        context.read<ViewerBloc>().add(
                          ViewerPropertiesChanged(isBold: !effectiveIsBold),
                        );
                      },
              ),
              ViewerToolbarToolButton(
                icon: Icons.format_italic,
                tooltip: 'Cursiva',
                selected: canFormatSelection
                    ? runtime!.italicActive
                    : effectiveIsItalic,
                framed: false,
                onPressed: canFormatSelection
                    ? () {
                        runtime!.requestFocus();
                        runtime.toggleItalic();
                      }
                    : () {
                        context.read<ViewerBloc>().add(
                          ViewerPropertiesChanged(isItalic: !effectiveIsItalic),
                        );
                      },
              ),
              ViewerToolbarColorField(
                icon: Icons.format_color_fill,
                label: null,
                selectedColor: canFormatSelection &&
                        runtime!.selectedHighlightColor != null
                    ? runtime.selectedHighlightColor!
                    : effectiveHighlightColor,
                swatches: _highlightColorOptions,
                dialogTitle: 'Color del resaltado',
                recentColors: _viewerRecentHighlightColors,
                tooltip: 'Color del resaltado',
                clearActionLabel: canFormatSelection &&
                        (runtime!.highlightActive)
                    ? 'Quitar resaltado'
                    : null,
                onClearSelected: canFormatSelection && runtime!.highlightActive
                    ? () {
                        runtime.requestFocus();
                        runtime.clearHighlight();
                      }
                    : null,
                onColorSelected: (color) {
                  context.read<ViewerBloc>().add(
                    ViewerPropertiesChanged(textHighlightColor: color),
                  );
                  if (canFormatSelection) {
                    runtime!.requestFocus();
                    runtime.applyHighlightColor(color);
                  }
                },
              ),
              ViewerToolbarToolButton(
                icon: Icons.layers_clear_outlined,
                tooltip: 'Sombreado del panel',
                selected: effectiveHasShadow,
                framed: false,
                onPressed: () {
                  context.read<ViewerBloc>().add(
                    ViewerPropertiesChanged(hasShadow: !effectiveHasShadow),
                  );
                },
              ),
            ],
          ),
          ViewerToolbarActionCluster(
            children: ViewerTextPanelAlignment.values
                .map(
                  (alignment) => ViewerToolbarToolButton(
                    icon: _alignmentIcon(alignment),
                    tooltip: _alignmentLabel(alignment),
                    selected: effectivePanelAlignment == alignment,
                    framed: false,
                    onPressed: () {
                      if (runtime != null) {
                        runtime.requestFocus();
                        runtime.applyAlignment(alignment);
                      } else {
                        context.read<ViewerBloc>().add(
                          ViewerPropertiesChanged(panelAlignment: alignment),
                        );
                      }
                    },
                  ),
                )
                .toList(growable: false),
          ),
          _ViewerToolbarPanelStyleButton(
            backgroundColor: effectivePanelBackgroundColor,
            borderColor: effectivePanelBorderColor,
            borderWidth: effectivePanelBorderWidth,
            backgroundSwatches: _textPanelBackgroundOptions,
            borderSwatches: _strokeColorOptions,
            recentColors: _viewerRecentFrameColors,
            onBackgroundColorSelected: (color) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(panelBackgroundColor: color),
              );
            },
            onBorderColorSelected: (color) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(panelBorderColor: color),
              );
            },
            onBorderWidthChanged: (value) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(panelBorderWidth: value),
              );
            },
          ),
        ]);
      }
    }

    return widgets;
  }

  void _applyAnnotationColor(BuildContext context, int color) {
    context.read<ViewerBloc>().add(
      ViewerPropertiesChanged(color: color),
    );
  }

  void _applyFrameBackgroundColor(BuildContext context, int color) {
    context.read<ViewerBloc>().add(
      ViewerSelectedFrameStyleChanged(frameBackgroundColor: color),
    );
  }

  List<Widget> _buildImageProperties(
    BuildContext context,
    ImageFrameComponent image,
  ) {
    return [
      if (showLeadingSeparator) const ViewerToolbarGroupSeparator(),
      ViewerToolbarColorField(
        label: null,
        icon: Icons.crop_square_rounded,
        selectedColor: image.style.backgroundColor,
        swatches: _frameBackgroundOptions,
        dialogTitle: 'Selecciona el color del frame',
        recentColors: _viewerRecentFrameColors,
        tooltip: 'Color del frame',
        onColorSelected: (color) => _applyFrameBackgroundColor(context, color),
      ),
      SizedBox(
        width: 126,
        child: ViewerToolbarLabeledSlider(
          label: 'Opacidad ${(image.style.backgroundOpacity * 100).round()}%',
          min: 0,
          max: 1,
          divisions: 20,
          value: image.style.backgroundOpacity.clamp(0, 1).toDouble(),
          onChanged: (value) {
            context.read<ViewerBloc>().add(
              ViewerSelectedFrameStyleChanged(frameBackgroundOpacity: value),
            );
          },
        ),
      ),
      SizedBox(
        width: 126,
        child: ViewerToolbarLabeledSlider(
          label: 'Padding ${image.style.padding.toStringAsFixed(0)}',
          min: 0,
          max: 80,
          divisions: 40,
          value: image.style.padding.clamp(0, 80).toDouble(),
          onChanged: (value) {
            context.read<ViewerBloc>().add(
              ViewerSelectedFrameStyleChanged(framePadding: value),
            );
          },
        ),
      ),
      ViewerToolbarToolButton(
        icon: Icons.flip_to_back,
        tooltip: 'Enviar atras',
        selected: false,
        onPressed: () {
          context.read<ViewerBloc>().add(
            ViewerElementZOrderChanged(
              elementId: image.id,
              isForward: false,
            ),
          );
        },
      ),
      ViewerToolbarToolButton(
        icon: Icons.flip_to_front,
        tooltip: 'Traer al frente',
        selected: false,
        onPressed: () {
          context.read<ViewerBloc>().add(
            ViewerElementZOrderChanged(
              elementId: image.id,
              isForward: true,
            ),
          );
        },
      ),
      TextButton(
        onPressed: () {
          final defaults = frameDefaultsResolver(context);
          context.read<ViewerBloc>().add(
            ViewerSelectedFrameStyleChanged(
              frameBackgroundColor: defaults.backgroundColor,
              frameBackgroundOpacity: defaults.backgroundOpacity,
              frameBorderColor: defaults.borderColor,
              frameBorderWidth: defaults.borderWidth,
              framePadding: defaults.padding,
            ),
          );
        },
        child: const Text('Default'),
      ),
    ];
  }

  static const List<int> _strokeColorOptions = [
    0xFFE53935,
    0xFFFF9800,
    0xFF43A047,
    0xFF1E88E5,
    0xFF7B61FF,
    0xFFFDD835,
    0xFFFFFFFF,
    0xFF212121,
  ];

  static const List<int> _frameBackgroundOptions = [
    0xFFFFFFFF,
    0xFFF5F5F5,
    0xFFE3F2FD,
    0xFFE8F5E9,
    0xFFFFF3E0,
    0xFFFFEBEE,
    0xFFEDE7F6,
    0x00000000,
  ];

  static const List<String> _fontFamilyOptions = [
    'Segoe UI',
    'Georgia',
    'Verdana',
    'Consolas',
  ];

  static const List<int> _textPanelBackgroundOptions = [
    0xF6FFFFFF,
    0xF7FFF8E1,
    0xF7E8F0FE,
    0xF6E8F5E9,
    0xF7FFF3E0,
    0x00000000,
  ];

  static const List<int> _highlightColorOptions = [
    0xFFFFF59D,
    0xFFFFCC80,
    0xFFA5D6A7,
    0xFF90CAF9,
    0xFFCE93D8,
    0xFFFFAB91,
  ];

  static IconData _alignmentIcon(ViewerTextPanelAlignment alignment) {
    return switch (alignment) {
      ViewerTextPanelAlignment.left => Icons.format_align_left,
      ViewerTextPanelAlignment.center => Icons.format_align_center,
      ViewerTextPanelAlignment.right => Icons.format_align_right,
      ViewerTextPanelAlignment.justify => Icons.format_align_justify,
    };
  }

  static String _alignmentLabel(ViewerTextPanelAlignment alignment) {
    return switch (alignment) {
      ViewerTextPanelAlignment.left => 'Alinear a la izquierda',
      ViewerTextPanelAlignment.center => 'Centrar',
      ViewerTextPanelAlignment.right => 'Alinear a la derecha',
      ViewerTextPanelAlignment.justify => 'Justificar',
    };
  }
}

class _ViewerToolbarPanelStyleButton extends StatelessWidget {
  const _ViewerToolbarPanelStyleButton({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.backgroundSwatches,
    required this.borderSwatches,
    required this.recentColors,
    required this.onBackgroundColorSelected,
    required this.onBorderColorSelected,
    required this.onBorderWidthChanged,
  });

  final int backgroundColor;
  final int borderColor;
  final double borderWidth;
  final List<int> backgroundSwatches;
  final List<int> borderSwatches;
  final List<Color> recentColors;
  final ValueChanged<int> onBackgroundColorSelected;
  final ValueChanged<int> onBorderColorSelected;
  final ValueChanged<double> onBorderWidthChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Never>(
      tooltip: 'Estilo del panel',
      color: const Color(0xFF1C1D21),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<Never>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 288,
            child: _ViewerToolbarPanelStyleMenu(
              backgroundColor: backgroundColor,
              borderColor: borderColor,
              borderWidth: borderWidth,
              backgroundSwatches: backgroundSwatches,
              borderSwatches: borderSwatches,
              recentColors: recentColors,
              onBackgroundColorSelected: onBackgroundColorSelected,
              onBorderColorSelected: onBorderColorSelected,
              onBorderWidthChanged: onBorderWidthChanged,
            ),
          ),
        ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D21),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.dashboard_customize_outlined,
              size: 18,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            const Text(
              'Panel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(backgroundColor),
                shape: BoxShape.circle,
                border: Border.all(color: Color(borderColor), width: 1.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              borderWidth.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerToolbarPanelStyleMenu extends StatefulWidget {
  const _ViewerToolbarPanelStyleMenu({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.backgroundSwatches,
    required this.borderSwatches,
    required this.recentColors,
    required this.onBackgroundColorSelected,
    required this.onBorderColorSelected,
    required this.onBorderWidthChanged,
  });

  final int backgroundColor;
  final int borderColor;
  final double borderWidth;
  final List<int> backgroundSwatches;
  final List<int> borderSwatches;
  final List<Color> recentColors;
  final ValueChanged<int> onBackgroundColorSelected;
  final ValueChanged<int> onBorderColorSelected;
  final ValueChanged<double> onBorderWidthChanged;

  @override
  State<_ViewerToolbarPanelStyleMenu> createState() =>
      _ViewerToolbarPanelStyleMenuState();
}

class _ViewerToolbarPanelStyleMenuState
    extends State<_ViewerToolbarPanelStyleMenu> {
  late int _backgroundColor;
  late int _borderColor;
  late double _borderWidth;

  @override
  void initState() {
    super.initState();
    _backgroundColor = widget.backgroundColor;
    _borderColor = widget.borderColor;
    _borderWidth = widget.borderWidth;
  }

  Future<void> _pickAdvancedColor({
    required Color currentColor,
    required ValueChanged<int> onSelected,
  }) async {
    final selectedColor = await showColorPickerDialog(
      context,
      currentColor,
      title: const Text('Selecciona un color'),
      showColorCode: true,
      showRecentColors: true,
      recentColors: List<Color>.from(widget.recentColors),
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.both: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      wheelSubheading: const Text('Rueda'),
      recentColorsSubheading: const Text('Recientes'),
    );

    if (!mounted) return;
    final argb = selectedColor.toARGB32();
    widget.recentColors
      ..removeWhere((color) => color.toARGB32() == argb)
      ..insert(0, selectedColor);
    if (widget.recentColors.length > 8) {
      widget.recentColors.removeRange(8, widget.recentColors.length);
    }
    onSelected(argb);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estilo del panel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Fondo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.backgroundSwatches.map(
                (color) => ViewerToolbarColorSwatch(
                  color: color,
                  selected: _backgroundColor == color,
                  onTap: () {
                    setState(() => _backgroundColor = color);
                    widget.onBackgroundColorSelected(color);
                  },
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: Colors.white12),
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1C1D21),
                ),
                onPressed: () => _pickAdvancedColor(
                  currentColor: Color(_backgroundColor),
                  onSelected: (color) {
                    setState(() => _backgroundColor = color);
                    widget.onBackgroundColorSelected(color);
                  },
                ),
                icon: const Icon(Icons.palette_outlined, size: 16),
                label: const Text('Personalizar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Borde',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.borderSwatches.map(
                (color) => ViewerToolbarColorSwatch(
                  color: color,
                  selected: _borderColor == color,
                  onTap: () {
                    setState(() => _borderColor = color);
                    widget.onBorderColorSelected(color);
                  },
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: Colors.white12),
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1C1D21),
                ),
                onPressed: () => _pickAdvancedColor(
                  currentColor: Color(_borderColor),
                  onSelected: (color) {
                    setState(() => _borderColor = color);
                    widget.onBorderColorSelected(color);
                  },
                ),
                icon: const Icon(Icons.palette_outlined, size: 16),
                label: const Text('Personalizar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Grosor ${_borderWidth.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            min: 0,
            max: 8,
            divisions: 16,
            value: _borderWidth.clamp(0, 8),
            onChanged: (value) {
              setState(() => _borderWidth = value);
              widget.onBorderWidthChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _ViewerToolbarCompactMenuButton<T> extends StatelessWidget {
  const _ViewerToolbarCompactMenuButton({
    required this.label,
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D21),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}
