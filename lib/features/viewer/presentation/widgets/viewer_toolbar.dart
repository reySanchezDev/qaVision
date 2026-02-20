import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';

/// Barra de herramientas lateral para el visor (§9.4).
class ViewerToolbar extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbar].
  const ViewerToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      color: Colors.grey[900],
      child: BlocBuilder<ViewerBloc, ViewerState>(
        builder: (context, state) {
          return Column(
            children: [
              const SizedBox(height: 16),
              _ToolButton(
                icon: Icons.mouse,
                isSelected: state.activeTool == AnnotationType.selection,
                onPressed: () => _setTool(context, AnnotationType.selection),
                tooltip: 'Seleccionar (§9.4)',
              ),
              const Divider(color: Colors.white12),
              _ToolButton(
                icon: Icons.arrow_right_alt,
                isSelected: state.activeTool == AnnotationType.arrow,
                onPressed: () => _setTool(context, AnnotationType.arrow),
                tooltip: 'Flecha',
              ),
              _ToolButton(
                icon: Icons.rectangle_outlined,
                isSelected: state.activeTool == AnnotationType.rectangle,
                onPressed: () => _setTool(context, AnnotationType.rectangle),
                tooltip: 'Rectángulo',
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                isSelected: state.activeTool == AnnotationType.circle,
                onPressed: () => _setTool(context, AnnotationType.circle),
                tooltip: 'Círculo',
              ),
              _ToolButton(
                icon: Icons.edit,
                isSelected: state.activeTool == AnnotationType.pencil,
                onPressed: () => _setTool(context, AnnotationType.pencil),
                tooltip: 'Lápiz',
              ),
              _ToolButton(
                icon: Icons.text_fields,
                isSelected: state.activeTool == AnnotationType.text,
                onPressed: () => _setTool(context, AnnotationType.text),
                tooltip: 'Texto',
              ),
              _ToolButton(
                icon: Icons.blur_on,
                isSelected: state.activeTool == AnnotationType.blur,
                onPressed: () => _setTool(context, AnnotationType.blur),
                tooltip: 'Censurar (Blur)',
              ),
              _ToolButton(
                icon: Icons.looks_one,
                isSelected: state.activeTool == AnnotationType.stepMarker,
                onPressed: () => _setTool(context, AnnotationType.stepMarker),
                tooltip: 'Paso (1, 2, 3...)',
              ),
              const Spacer(),
              _ToolButton(
                icon: Icons.undo,
                isSelected: false,
                onPressed: () =>
                    context.read<ViewerBloc>().add(const ViewerUndoRequested()),
                tooltip: 'Deshacer',
              ),
              _ToolButton(
                icon: Icons.redo,
                isSelected: false,
                onPressed: () =>
                    context.read<ViewerBloc>().add(const ViewerRedoRequested()),
                tooltip: 'Rehacer',
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  void _setTool(BuildContext context, AnnotationType tool) {
    context.read<ViewerBloc>().add(ViewerToolChanged(tool));
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
