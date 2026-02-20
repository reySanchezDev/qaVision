import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_routes.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Widget del Botón Flotante Draggable (§9.0).
///
/// Debe estar envuelto en un [Stack] o [Overlay] global.
class FloatingButtonWidget extends StatelessWidget {
  /// Crea una instancia de [FloatingButtonWidget].
  const FloatingButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FloatingButtonBloc, FloatingButtonState>(
      builder: (context, state) {
        if (!state.isVisible) return const SizedBox.shrink();

        return Positioned(
          left: state.position.dx,
          top: state.position.dy,
          child: Draggable(
            feedback: _ButtonBody(state: state, isDragging: true),
            childWhenDragging: const SizedBox.shrink(),
            onDragEnd: (details) {
              context.read<FloatingButtonBloc>().add(
                FloatingButtonDragged(details.offset),
              );
            },
            child: _ButtonBody(state: state),
          ),
        );
      },
    );
  }
}

class _ButtonBody extends StatelessWidget {
  const _ButtonBody({required this.state, this.isDragging = false});

  final FloatingButtonState state;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final project = state.activeProject;
    final color = project != null ? Color(project.color) : Colors.blue;
    final alias = project?.alias ?? 'QA';

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón principal (§9.0)
          GestureDetector(
            onTap: () {
              context.read<FloatingButtonBloc>().add(
                const FloatingButtonToggled(),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AppText(
                  alias,
                  variant: TextVariant.titleMedium,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Panel lateral (§9.1)
          if (state.isExpanded && !isDragging) ...[
            const SizedBox(width: 8),
            _FloatingPanel(state: state),
          ],
        ],
      ),
    );
  }
}

class _FloatingPanel extends StatelessWidget {
  const _FloatingPanel({required this.state});

  final FloatingButtonState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botones de acción rápida (§9.2)
          _ActionIcon(
            icon: Icons.camera_alt,
            onPressed: () {
              context.read<FloatingButtonBloc>().add(
                const FloatingButtonCaptureRequested(),
              );
            },
          ),
          _ActionIcon(
            icon: Icons.crop_free,
            onPressed: () {
              context.read<FloatingButtonBloc>().add(
                const FloatingButtonCaptureRequested(captureRegion: true),
              );
            },
          ),
          _ActionIcon(
            icon: Icons.grid_view_rounded,
            onPressed: () {
              unawaited(Navigator.pushNamed(context, AppRoutes.viewer));
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: VerticalDivider(width: 1),
          ),
          // Selector de proyecto rápido
          ...state.projects
              .take(3)
              .map(
                (p) => _ProjectBubble(
                  project: p,
                  isSelected: p.id == state.activeProject?.id,
                ),
              ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      iconSize: 24,
    );
  }
}

class _ProjectBubble extends StatelessWidget {
  const _ProjectBubble({required this.project, required this.isSelected});

  final ProjectEntity project;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<FloatingButtonBloc>().add(
          FloatingButtonProjectChanged(project),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(project.color),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Center(
          child: AppText(
            project.alias,
            variant: TextVariant.labelSmall,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
