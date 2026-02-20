import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';

/// Panel superior para configurar propiedades de la herramienta (§9.5).
class ViewerPropertiesPanel extends StatelessWidget {
  /// Crea una instancia de [ViewerPropertiesPanel].
  const ViewerPropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: const Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: BlocBuilder<ViewerBloc, ViewerState>(
        builder: (context, state) {
          return Row(
            children: [
              const Text(
                'Propiedades:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 16),
              _ColorOption(
                color: 0xFFFF0000,
                isSelected: state.activeColor == 0xFFFF0000,
                onPressed: () => _setColor(context, 0xFFFF0000),
              ),
              _ColorOption(
                color: 0xFF00FF00,
                isSelected: state.activeColor == 0xFF00FF00,
                onPressed: () => _setColor(context, 0xFF00FF00),
              ),
              _ColorOption(
                color: 0xFF0000FF,
                isSelected: state.activeColor == 0xFF0000FF,
                onPressed: () => _setColor(context, 0xFF0000FF),
              ),
              _ColorOption(
                color: 0xFFFFFF00,
                isSelected: state.activeColor == 0xFFFFFF00,
                onPressed: () => _setColor(context, 0xFFFFFF00),
              ),
              _ColorOption(
                color: 0xFF000000,
                isSelected: state.activeColor == 0xFF000000,
                onPressed: () => _setColor(context, 0xFF000000),
              ),
              const VerticalDivider(
                color: Colors.white12,
                indent: 10,
                endIndent: 10,
              ),
              const SizedBox(width: 8),
              const Text(
                'Grosor:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              _StrokeOption(
                width: 2,
                isSelected: state.activeStrokeWidth == 2,
                onPressed: () => _setStroke(context, 2),
              ),
              _StrokeOption(
                width: 4,
                isSelected: state.activeStrokeWidth == 4,
                onPressed: () => _setStroke(context, 4),
              ),
              _StrokeOption(
                width: 8,
                isSelected: state.activeStrokeWidth == 8,
                onPressed: () => _setStroke(context, 8),
              ),
              if (state.selectedElementId != null) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  color: Colors.white70,
                  onPressed: () =>
                      _changeZOrder(context, state.selectedElementId!, true),
                  tooltip: 'Traer al frente',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  color: Colors.white70,
                  onPressed: () =>
                      _changeZOrder(context, state.selectedElementId!, false),
                  tooltip: 'Enviar al fondo',
                ),
                const VerticalDivider(
                  color: Colors.white12,
                  indent: 10,
                  endIndent: 10,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () =>
                      _deleteElement(context, state.selectedElementId!),
                  tooltip: 'Eliminar elemento',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _deleteElement(BuildContext context, String elementId) {
    context.read<ViewerBloc>().add(ViewerElementDeleted(elementId: elementId));
  }

  void _changeZOrder(BuildContext context, String elementId, bool isForward) {
    context.read<ViewerBloc>().add(
      ViewerElementZOrderChanged(elementId: elementId, isForward: isForward),
    );
  }

  void _setColor(BuildContext context, int color) {
    context.read<ViewerBloc>().add(ViewerPropertiesChanged(color: color));
  }

  void _setStroke(BuildContext context, double width) {
    context.read<ViewerBloc>().add(ViewerPropertiesChanged(strokeWidth: width));
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final int color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }
}

class _StrokeOption extends StatelessWidget {
  const _StrokeOption({
    required this.width,
    required this.isSelected,
    required this.onPressed,
  });

  final double width;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: 20,
          height: width,
          color: Colors.white,
        ),
      ),
    );
  }
}
