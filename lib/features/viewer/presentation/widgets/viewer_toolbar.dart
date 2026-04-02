import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_layers_panel.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_rich_text_panel_runtime.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_context_properties.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_primitives.dart';

/// Top toolbar with grouped tools and contextual properties.
class ViewerToolbar extends StatelessWidget {
  /// Creates [ViewerToolbar].
  const ViewerToolbar({
    required this.showLayersPanel,
    required this.layersDockSide,
    required this.onToggleLayersPanel,
    this.richTextRuntime,
    super.key,
  });

  /// Indica si el panel de capas esta visible.
  final bool showLayersPanel;

  /// Lado de acople actual del panel de capas.
  final ViewerLayersDockSide layersDockSide;

  /// Alterna la visibilidad del panel de capas.
  final VoidCallback onToggleLayersPanel;

  /// Bridge activo cuando un panel de texto enriquecido esta seleccionado.
  final ViewerRichTextPanelRuntime? richTextRuntime;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: BlocBuilder<ViewerBloc, ViewerState>(
        builder: (context, state) {
          final selectedElement = _selectedElement(state);
          final selectedImage = selectedElement is ImageFrameComponent
              ? selectedElement
              : null;
          final selectedAnnotation = selectedElement is AnnotationElement
              ? selectedElement
              : null;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._buildToolGroups(context, state),
                const SizedBox(width: 4),
                ViewerToolbarContextProperties(
                  state: state,
                  selectedImage: selectedImage,
                  selectedAnnotation: selectedAnnotation,
                  richTextRuntime: richTextRuntime,
                  frameDefaultsResolver: _frameDefaults,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildToolGroups(BuildContext context, ViewerState state) {
    return [
      ViewerToolbarToolButton(
        icon: Icons.near_me,
        tooltip: 'Cursor',
        selected: state.activeTool == AnnotationType.selection,
        label: 'Cursor',
        onPressed: () => _setTool(context, AnnotationType.selection),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarMenuButton<AnnotationType>(
        icon: _shapeToolIcon(state.activeTool),
        label: 'Formas',
        tooltip: 'Formas',
        selected: _isShapeTool(state.activeTool),
        onSelected: (tool) => _setTool(context, tool),
        items: const [
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.arrow,
            child: _ViewerToolbarMenuItem(
              icon: Icons.arrow_right_alt,
              label: 'Flecha',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.rectangle,
            child: _ViewerToolbarMenuItem(
              icon: Icons.rectangle_outlined,
              label: 'Rectangulo',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.circle,
            child: _ViewerToolbarMenuItem(
              icon: Icons.circle_outlined,
              label: 'Circulo',
            ),
          ),
        ],
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarMenuButton<AnnotationType>(
        icon: _commentToolIcon(state.activeTool),
        label: 'Comentarios',
        tooltip: 'Comentarios',
        selected: _isCommentTool(state.activeTool),
        onSelected: (tool) => _setTool(context, tool),
        items: const [
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.text,
            child: _ViewerToolbarMenuItem(
              icon: Icons.text_fields,
              label: 'Texto',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.richTextPanel,
            child: _ViewerToolbarMenuItem(
              icon: Icons.notes_rounded,
              label: 'Panel texto',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.commentBubble,
            child: _ViewerToolbarMenuItem(
              icon: Icons.mode_comment_outlined,
              label: 'Burbuja',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.stepMarker,
            child: _ViewerToolbarMenuItem(
              icon: Icons.format_list_numbered_rounded,
              label: 'Numerador',
            ),
          ),
        ],
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarMenuButton<AnnotationType>(
        icon: _markupToolIcon(state.activeTool),
        label: 'Marcado',
        tooltip: 'Marcado',
        selected: _isMarkupTool(state.activeTool),
        onSelected: (tool) => _setTool(context, tool),
        items: const [
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.highlighter,
            child: _ViewerToolbarMenuItem(
              icon: Icons.highlight_alt_outlined,
              label: 'Highlighter',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.pencil,
            child: _ViewerToolbarMenuItem(
              icon: Icons.edit_outlined,
              label: 'Lapiz',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.blur,
            child: _ViewerToolbarMenuItem(
              icon: Icons.blur_on_outlined,
              label: 'Blur',
            ),
          ),
          PopupMenuItem<AnnotationType>(
            value: AnnotationType.eraser,
            child: _ViewerToolbarMenuItem(
              icon: Icons.cleaning_services_outlined,
              label: 'Borrador',
            ),
          ),
        ],
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarActionCluster(
        children: [
          ViewerToolbarToolButton(
            icon: Icons.undo,
            tooltip: 'Deshacer (Ctrl+Z)',
            selected: false,
            framed: false,
            onPressed: () => context.read<ViewerBloc>().add(
              const ViewerUndoRequested(),
            ),
          ),
          ViewerToolbarToolButton(
            icon: Icons.redo,
            tooltip: 'Rehacer (Ctrl+Y)',
            selected: false,
            framed: false,
            onPressed: () => context.read<ViewerBloc>().add(
              const ViewerRedoRequested(),
            ),
          ),
        ],
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.add_photo_alternate_outlined,
        tooltip: 'Agregar imagen',
        selected: false,
        label: 'Imagen',
        onPressed: () => _pickAndAddImage(context, state),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarActionCluster(
        children: [
          ViewerToolbarToolButton(
            icon: Icons.copy,
            tooltip: 'Copiar al portapapeles',
            selected: false,
            framed: false,
            onPressed: () => context.read<ViewerBloc>().add(
              const ViewerCopyRequested(),
            ),
          ),
          ViewerToolbarToolButton(
            icon: Icons.share,
            tooltip: 'Compartir',
            selected: false,
            framed: false,
            onPressed: () => context.read<ViewerBloc>().add(
              const ViewerShareRequested(),
            ),
          ),
        ],
      ),
      const ViewerToolbarGroupSeparator(),
      Tooltip(
        message:
            'Guardar imagen final. '
            'Este paso actualiza el archivo visible fuera del visor.',
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => context.read<ViewerBloc>().add(
              const ViewerExportRequested(),
            ),
            icon: const Icon(Icons.save, size: 16),
            label: const Text(
              'Guardar final',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ];
  }

  /// Obtiene el elemento seleccionado actualmente en el estado.
  CanvasElement? _selectedElement(ViewerState state) {
    final selectedId = state.selectedElementId;
    if (selectedId == null) return null;
    for (final element in state.frame.elements) {
      if (element.id == selectedId) return element;
    }
    return null;
  }

  void _setTool(BuildContext context, AnnotationType tool) {
    context.read<ViewerBloc>().add(ViewerToolChanged(tool));
    if (tool != AnnotationType.selection) {
      context.read<ViewerBloc>().add(const ViewerElementSelected());
    }
  }

  bool _isShapeTool(AnnotationType tool) {
    return tool == AnnotationType.arrow ||
        tool == AnnotationType.rectangle ||
        tool == AnnotationType.circle;
  }

  bool _isCommentTool(AnnotationType tool) {
    return tool == AnnotationType.text ||
        tool == AnnotationType.richTextPanel ||
        tool == AnnotationType.commentBubble ||
        tool == AnnotationType.stepMarker;
  }

  bool _isMarkupTool(AnnotationType tool) {
    return tool == AnnotationType.highlighter ||
        tool == AnnotationType.pencil ||
        tool == AnnotationType.blur ||
        tool == AnnotationType.eraser;
  }

  IconData _shapeToolIcon(AnnotationType tool) {
    return switch (tool) {
      AnnotationType.arrow => Icons.arrow_right_alt,
      AnnotationType.circle => Icons.circle_outlined,
      _ => Icons.rectangle_outlined,
    };
  }

  IconData _commentToolIcon(AnnotationType tool) {
    return switch (tool) {
      AnnotationType.richTextPanel => Icons.notes_rounded,
      AnnotationType.commentBubble => Icons.mode_comment_outlined,
      AnnotationType.stepMarker => Icons.format_list_numbered_rounded,
      _ => Icons.text_fields,
    };
  }

  IconData _markupToolIcon(AnnotationType tool) {
    return switch (tool) {
      AnnotationType.highlighter => Icons.highlight_alt_outlined,
      AnnotationType.pencil => Icons.edit_outlined,
      AnnotationType.eraser => Icons.cleaning_services_outlined,
      _ => Icons.blur_on_outlined,
    };
  }

  /// Inicia el flujo de selección de imagen para agregar al frame.
  Future<void> _pickAndAddImage(BuildContext context, ViewerState state) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (!context.mounted || path == null || path.isEmpty) return;

    final defaults = _frameDefaults(context);
    final projectPath = _resolveProjectPath(state, path);
    context.read<ViewerBloc>().add(
      ViewerImageAdded(
        imagePath: path,
        projectPath: projectPath,
        defaultFrameBackgroundColor: defaults.backgroundColor,
        defaultFrameBackgroundOpacity: defaults.backgroundOpacity,
        defaultFrameBorderColor: defaults.borderColor,
        defaultFrameBorderWidth: defaults.borderWidth,
        defaultFramePadding: defaults.padding,
      ),
    );
  }

  /// Resuelve la ruta del proyecto basándose en elementos actuales.
  String _resolveProjectPath(ViewerState state, String fallbackImagePath) {
    final baseImagePath = state.frame.elements
        .whereType<ImageFrameComponent>()
        .firstOrNull
        ?.path;
    if (baseImagePath != null && baseImagePath.isNotEmpty) {
      return File(baseImagePath).parent.path;
    }
    return File(fallbackImagePath).parent.path;
  }

  /// Resuelve los valores por defecto para frames nuevos.
  ViewerFrameDefaults _frameDefaults(BuildContext context) {
    return const ViewerFrameDefaults(
      backgroundColor: kDefaultViewerFrameBackgroundColor,
      backgroundOpacity: kDefaultViewerFrameBackgroundOpacity,
      borderColor: kDefaultViewerFrameBorderColor,
      borderWidth: kDefaultViewerFrameBorderWidth,
      padding: kDefaultViewerFramePadding,
    );
  }
}

/// Elemento interno para los items de menu desplegable.
class _ViewerToolbarMenuItem extends StatelessWidget {
  const _ViewerToolbarMenuItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
