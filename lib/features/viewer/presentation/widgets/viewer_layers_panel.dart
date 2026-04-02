import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_layer_entry.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_selection_service.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';

/// Lados permitidos para acoplar el panel de capas.
enum ViewerLayersDockSide {
  /// Acoplado al borde izquierdo del workspace.
  left,

  /// Acoplado al borde derecho del workspace.
  right,
}

/// Panel de capas integrado al layout del visor.
class ViewerLayersPanel extends StatelessWidget {
  /// Crea una instancia de [ViewerLayersPanel].
  const ViewerLayersPanel({
    required this.dockSide,
    required this.onToggleVisibility,
    this.onHeaderDragStart,
    this.onHeaderDragUpdate,
    this.onHeaderDragEnd,
    super.key,
  });

  /// Ancho fijo del panel dockeado.
  static const double dockedWidth = 312;

  /// Lado en el que queda acoplado.
  final ViewerLayersDockSide dockSide;

  /// Alterna la visibilidad del panel.
  final VoidCallback onToggleVisibility;

  /// Inicia un arrastre del encabezado.
  final GestureDragStartCallback? onHeaderDragStart;

  /// Actualiza el arrastre del encabezado.
  final GestureDragUpdateCallback? onHeaderDragUpdate;

  /// Finaliza el arrastre del encabezado.
  final GestureDragEndCallback? onHeaderDragEnd;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (previous, current) =>
          previous.frame != current.frame ||
          previous.selectedElementId != current.selectedElementId,
      builder: (context, state) {
        final document = ViewerDocumentGraphService.build(state.frame);
        final entries = ViewerDocumentSelectionService.buildLayerEntries(
          document,
          selectedId: state.selectedElementId,
        );
        final entryById = <String, ViewerLayerEntry>{
          for (final entry in entries) entry.id: entry,
        };
        final selectionPath = ViewerDocumentSelectionService.selectionPath(
          document,
          state.selectedElementId,
        );

        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        final separatorBorder = dockSide == ViewerLayersDockSide.left
            ? const Border(
                right: BorderSide(color: Colors.white10),
              )
            : const Border(
                left: BorderSide(color: Colors.white10),
              );

        return Container(
          width: dockedWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF171A1F),
            border: separatorBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LayersHeader(
                dockSide: dockSide,
                entryCount: entries.length,
                onToggleVisibility: onToggleVisibility,
                onHeaderDragStart: onHeaderDragStart,
                onHeaderDragUpdate: onHeaderDragUpdate,
                onHeaderDragEnd: onHeaderDragEnd,
              ),
              if (selectionPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectionPath
                        .map(
                          (node) => _SelectionChip(
                            label: entryById[node.id]?.label ?? node.id,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LayerTile(entry: entry);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LayersHeader extends StatelessWidget {
  const _LayersHeader({
    required this.dockSide,
    required this.entryCount,
    required this.onToggleVisibility,
    this.onHeaderDragStart,
    this.onHeaderDragUpdate,
    this.onHeaderDragEnd,
  });

  final ViewerLayersDockSide dockSide;
  final int entryCount;
  final VoidCallback onToggleVisibility;
  final GestureDragStartCallback? onHeaderDragStart;
  final GestureDragUpdateCallback? onHeaderDragUpdate;
  final GestureDragEndCallback? onHeaderDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: onHeaderDragStart,
      onHorizontalDragUpdate: onHeaderDragUpdate,
      onHorizontalDragEnd: onHeaderDragEnd,
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            const Text(
              'Capas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$entryCount',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Icon(
              dockSide == ViewerLayersDockSide.left
                  ? Icons.align_horizontal_left_rounded
                  : Icons.align_horizontal_right_rounded,
              size: 16,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
            _LayersVisibilityButton(
              tooltip: 'Ocultar panel de capas',
              icon: Icons.visibility_off_outlined,
              onPressed: onToggleVisibility,
            ),
          ],
        ),
      ),
    );
  }
}

class _LayersVisibilityButton extends StatelessWidget {
  const _LayersVisibilityButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 18,
        onTap: onPressed,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF20242B),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({required this.entry});

  final ViewerLayerEntry entry;

  @override
  Widget build(BuildContext context) {
    final depthPadding = 10.0 + (entry.depth * 16.0);
    final isSelected = entry.isSelected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<ViewerBloc>().add(
            ViewerElementSelected(
              elementId: entry.id,
              centerImage: false,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(depthPadding, 10, 10, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1D3340)
                : const Color(0xFF111419),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4FC3F7) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                entry.isImage
                    ? Icons.photo_size_select_large_outlined
                    : Icons.edit_note_outlined,
                size: 16,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (entry.hasChildren)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: Colors.white38,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF222831),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
