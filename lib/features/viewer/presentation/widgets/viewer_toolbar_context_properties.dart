import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_primitives.dart';

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
    final isStrokeTool =
        activeForProperties == AnnotationType.arrow ||
        activeForProperties == AnnotationType.rectangle ||
        activeForProperties == AnnotationType.circle;

    if (!isTextTool && !isStrokeTool) {
      if (selectedImage == null && selectedAnnotation == null) {
        return [
          const ViewerToolbarGroupSeparator(),
          const Text(
            'Fondo Lienzo',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          ..._canvasBackgroundOptions.map(
            (color) => ViewerToolbarColorSwatch(
              color: color,
              selected: state.frame.backgroundColor == color,
              onTap: () {
                context.read<ViewerBloc>().add(
                  ViewerBackgroundColorChanged(color),
                );
              },
            ),
          ),
        ];
      }
      return const <Widget>[];
    }

    final widgets = <Widget>[
      const ViewerToolbarGroupSeparator(),
      const Text(
        'Trazo',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(width: 8),
      ..._strokeColorOptions.map(
        (color) => ViewerToolbarColorSwatch(
          color: color,
          selected: color == state.activeColor,
          onTap: () {
            context.read<ViewerBloc>().add(
              ViewerPropertiesChanged(color: color),
            );
          },
        ),
      ),
    ];

    if (isStrokeTool) {
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
    }

    return widgets;
  }

  List<Widget> _buildImageProperties(
    BuildContext context,
    ImageFrameComponent image,
  ) {
    return [
      const ViewerToolbarGroupSeparator(),
      const Text(
        'Frame',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(width: 8),
      ..._frameBackgroundOptions.map(
        (color) => ViewerToolbarColorSwatch(
          color: color,
          selected: image.style.backgroundColor == color,
          onTap: () {
            context.read<ViewerBloc>().add(
              ViewerSelectedFrameStyleChanged(frameBackgroundColor: color),
            );
          },
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
    0x00000000,
  ];

  static const List<int> _canvasBackgroundOptions = [
    0xFF181818,
    0xFF2D2D2D,
    0xFF404040,
    0xFFE53935,
    0xFF1E88E5,
    0xFF43A047,
    0xFFFFFFFF,
  ];
}
