import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_layer_entry.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_selection_service.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';

/// Panel compacto de capas basado en el arbol real del documento.
class ViewerLayersPanel extends StatelessWidget {
  /// Crea el panel de capas del visor.
  const ViewerLayersPanel({
    required this.onToggleVisibility,
    this.isVisible = true,
    super.key,
  });

  /// Alterna la visibilidad del panel.
  final VoidCallback onToggleVisibility;

  /// Indica si el panel esta expandido.
  final bool isVisible;

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

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isVisible
                  ? ConstrainedBox(
                      key: const ValueKey('layers-expanded'),
                      constraints: const BoxConstraints(
                        maxWidth: 300,
                        maxHeight: 320,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xEE171A1F),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 18,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                  const Spacer(),
                                  Text(
                                    '${entries.length}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _LayersVisibilityButton(
                                    tooltip: 'Ocultar panel de capas',
                                    icon: Icons.visibility_off_outlined,
                                    onPressed: onToggleVisibility,
                                  ),
                                ],
                              ),
                              if (selectionPath.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: selectionPath
                                      .map(
                                        (node) => _SelectionChip(
                                          label:
                                              entryById[node.id]?.label ??
                                              node.id,
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: entries.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, index) {
                                    final entry = entries[index];
                                    return _LayerTile(entry: entry);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      key: const ValueKey('layers-collapsed'),
                      decoration: BoxDecoration(
                        color: const Color(0xEE171A1F),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 14,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                              '${entries.length}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _LayersVisibilityButton(
                              tooltip: 'Mostrar panel de capas',
                              icon: Icons.visibility_outlined,
                              onPressed: onToggleVisibility,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
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
