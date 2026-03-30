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
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_context_properties.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar_primitives.dart';

/// Top toolbar with grouped tools and contextual properties.
class ViewerToolbar extends StatelessWidget {
  /// Creates [ViewerToolbar].
  const ViewerToolbar({super.key});

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
        onPressed: () => _setTool(context, AnnotationType.selection),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.arrow_right_alt,
        tooltip: 'Flecha',
        selected: state.activeTool == AnnotationType.arrow,
        onPressed: () => _setTool(context, AnnotationType.arrow),
      ),
      ViewerToolbarToolButton(
        icon: Icons.rectangle_outlined,
        tooltip: 'Rectangulo',
        selected: state.activeTool == AnnotationType.rectangle,
        onPressed: () => _setTool(context, AnnotationType.rectangle),
      ),
      ViewerToolbarToolButton(
        icon: Icons.circle_outlined,
        tooltip: 'Circulo',
        selected: state.activeTool == AnnotationType.circle,
        onPressed: () => _setTool(context, AnnotationType.circle),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.text_fields,
        tooltip: 'Texto',
        selected: state.activeTool == AnnotationType.text,
        onPressed: () => _setTool(context, AnnotationType.text),
      ),
      ViewerToolbarToolButton(
        icon: Icons.mode_comment_outlined,
        tooltip: 'Burbuja',
        selected: state.activeTool == AnnotationType.commentBubble,
        onPressed: () => _setTool(context, AnnotationType.commentBubble),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.format_list_numbered_rounded,
        tooltip: 'Numerador',
        selected: state.activeTool == AnnotationType.stepMarker,
        onPressed: () => _setTool(context, AnnotationType.stepMarker),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.blur_on_outlined,
        tooltip: 'Blur',
        selected: state.activeTool == AnnotationType.blur,
        onPressed: () => _setTool(context, AnnotationType.blur),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.undo,
        tooltip: 'Deshacer (Ctrl+Z)',
        selected: false,
        onPressed: () => context.read<ViewerBloc>().add(
          const ViewerUndoRequested(),
        ),
      ),
      ViewerToolbarToolButton(
        icon: Icons.redo,
        tooltip: 'Rehacer (Ctrl+Y)',
        selected: false,
        onPressed: () => context.read<ViewerBloc>().add(
          const ViewerRedoRequested(),
        ),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.add_photo_alternate_outlined,
        tooltip: 'Agregar imagen',
        selected: false,
        onPressed: () => _pickAndAddImage(context, state),
      ),
      const ViewerToolbarGroupSeparator(),
      ViewerToolbarToolButton(
        icon: Icons.copy,
        tooltip: 'Copiar al portapapeles',
        selected: false,
        onPressed: () => context.read<ViewerBloc>().add(
          const ViewerCopyRequested(),
        ),
      ),
      ViewerToolbarToolButton(
        icon: Icons.share,
        tooltip: 'Compartir',
        selected: false,
        onPressed: () => context.read<ViewerBloc>().add(
          const ViewerShareRequested(),
        ),
      ),
      const ViewerToolbarGroupSeparator(),
      Tooltip(
        message: 'Guardar manualmente',
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
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ];
  }

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
