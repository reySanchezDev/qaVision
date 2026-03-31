import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_text_dialog.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_primitives.dart';

final List<Color> _viewerRecentAnnotationColors = <Color>[];
final List<Color> _viewerRecentFrameColors = <Color>[];

/// Propiedades contextuales de la barra del visor.
class ViewerToolbarContextProperties extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarContextProperties].
  const ViewerToolbarContextProperties({
    required this.state,
    required this.selectedImage,
    required this.selectedAnnotation,
    required this.frameDefaultsResolver,
    super.key,
  });

  /// Estado actual del visor.
  final ViewerState state;

  /// Imagen seleccionada actual (si aplica).
  final ImageFrameComponent? selectedImage;

  /// Anotación seleccionada actual (si aplica).
  final AnnotationElement? selectedAnnotation;

  /// Callback para obtener defaults de frame desde configuración.
  final ViewerFrameDefaults Function(BuildContext context)
  frameDefaultsResolver;

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
        activeForProperties == AnnotationType.commentBubble ||
        activeForProperties == AnnotationType.stepMarker;
    final isShapeTool =
        activeForProperties == AnnotationType.arrow ||
        activeForProperties == AnnotationType.rectangle ||
        activeForProperties == AnnotationType.circle;
    final isPencilTool = activeForProperties == AnnotationType.pencil;
    final isOpacityTool =
        activeForProperties == AnnotationType.highlighter ||
        activeForProperties == AnnotationType.blur;
    final isColorTool =
        isTextTool ||
        isShapeTool ||
        isPencilTool ||
        isOpacityTool;
    final isEraserTool = activeForProperties == AnnotationType.eraser;

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
        return [
          const ViewerToolbarGroupSeparator(),
          const Text(
            'Espacio lateral',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          const Text(
            'Fijo en negro para delimitar el area real de trabajo',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(width: 10),
          const Text(
            'Selecciona una captura para editar su frame',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ];
      }
      return const <Widget>[];
    }

    final widgets = <Widget>[
      const ViewerToolbarGroupSeparator(),
      const Text(
        'Color',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(width: 8),
      ..._buildQuickColorSwatches(
        colors: _strokeColorOptions,
        selectedColor: state.activeColor,
        onSelected: (color) => _applyAnnotationColor(context, color),
      ),
      const SizedBox(width: 8),
      _ViewerAdvancedColorButton(
        currentColor: Color(state.activeColor),
        dialogTitle: 'Selecciona el color de la herramienta',
        recentColors: _viewerRecentAnnotationColors,
        onColorSelected: (color) => _applyAnnotationColor(
          context,
          color.toARGB32(),
        ),
      ),
    ];

    if (isShapeTool || isPencilTool) {
      widgets.addAll([
        const SizedBox(width: 8),
        SizedBox(
          width: 126,
          child: ViewerToolbarLabeledSlider(
            label: 'Grosor ${state.activeStrokeWidth.toStringAsFixed(0)}',
            min: 1,
            max: 20,
            divisions: 19,
            value: state.activeStrokeWidth.clamp(1, 20).toDouble(),
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
        const SizedBox(width: 8),
        SizedBox(
          width: 126,
          child: ViewerToolbarLabeledSlider(
            label: 'Opacidad ${(state.activeOpacity * 100).round()}%',
            min: 0.1,
            max: 1,
            divisions: 18,
            value: state.activeOpacity.clamp(0.1, 1).toDouble(),
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
        const SizedBox(width: 8),
        SizedBox(
          width: 126,
          child: ViewerToolbarLabeledSlider(
            label: 'Tam. texto ${state.activeTextSize.toStringAsFixed(0)}',
            min: 10,
            max: 56,
            divisions: 23,
            value: state.activeTextSize.clamp(10, 56).toDouble(),
            onChanged: (value) {
              context.read<ViewerBloc>().add(
                ViewerPropertiesChanged(textSize: value),
              );
            },
          ),
        ),
      ]);

      if (selectedAnnotation != null &&
          (selectedAnnotation!.type == AnnotationType.text ||
              selectedAnnotation!.type == AnnotationType.commentBubble ||
              selectedAnnotation!.type == AnnotationType.stepMarker)) {
        widgets.addAll([
          const SizedBox(width: 8),
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

  List<Widget> _buildQuickColorSwatches({
    required List<int> colors,
    required int selectedColor,
    required ValueChanged<int> onSelected,
  }) {
    return colors.map(
      (color) => ViewerToolbarColorSwatch(
        color: color,
        selected: selectedColor == color,
        onTap: () => onSelected(color),
      ),
    ).toList();
  }

  List<Widget> _buildImageProperties(
    BuildContext context,
    ImageFrameComponent image,
  ) {
    return [
      const ViewerToolbarGroupSeparator(),
      const Text(
        'Frame seleccionado',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(width: 8),
      ..._buildQuickColorSwatches(
        colors: _frameBackgroundOptions,
        selectedColor: image.style.backgroundColor,
        onSelected: (color) => _applyFrameBackgroundColor(
          context,
          color,
        ),
      ),
      const SizedBox(width: 8),
      _ViewerAdvancedColorButton(
        currentColor: Color(image.style.backgroundColor),
        dialogTitle: 'Selecciona el color del frame',
        recentColors: _viewerRecentFrameColors,
        onColorSelected: (color) => _applyFrameBackgroundColor(
          context,
          color.toARGB32(),
        ),
      ),
      const SizedBox(width: 10),
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
      const SizedBox(width: 8),
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
      const SizedBox(width: 6),
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

}

class _ViewerAdvancedColorButton extends StatefulWidget {
  const _ViewerAdvancedColorButton({
    required this.currentColor,
    required this.dialogTitle,
    required this.recentColors,
    required this.onColorSelected,
  });

  final Color currentColor;
  final String dialogTitle;
  final List<Color> recentColors;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_ViewerAdvancedColorButton> createState() =>
      _ViewerAdvancedColorButtonState();
}

class _ViewerAdvancedColorButtonState
    extends State<_ViewerAdvancedColorButton> {
  Future<void> _showAdvancedPicker() async {
    final selectedColor = await showColorPickerDialog(
      context,
      widget.currentColor,
      title: Text(widget.dialogTitle),
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

    _rememberRecentColor(selectedColor);
    widget.onColorSelected(selectedColor);
  }

  void _rememberRecentColor(Color color) {
    widget.recentColors
      ..removeWhere((current) => current.toARGB32() == color.toARGB32())
      ..insert(0, color);
    if (widget.recentColors.length > 8) {
      widget.recentColors.removeRange(
        8,
        widget.recentColors.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Selector avanzado de color',
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: Colors.white12),
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF1C1D21),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onPressed: _showAdvancedPicker,
        icon: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: widget.currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
        label: const Text(
          'Personalizar',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
