import 'package:flutter/material.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Control visual para cada slot rápido de carpeta/proyecto.
class RecentStripProjectSlotControl extends StatelessWidget {
  /// Crea una instancia de [RecentStripProjectSlotControl].
  const RecentStripProjectSlotControl({
    required this.slotIndex,
    required this.project,
    required this.isSelected,
    required this.onSelect,
    required this.onReplace,
    super.key,
  });

  /// Índice visual del slot.
  final int slotIndex;

  /// Proyecto asignado al slot.
  final ProjectEntity? project;

  /// Estado de selección visual.
  final bool isSelected;

  /// Acción para activar el slot.
  final VoidCallback? onSelect;

  /// Acción para reemplazar carpeta del slot.
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final folderName = _buildFolderName(project);
    final slotColor = project == null
        ? Colors.white24
        : Color(project!.color).withValues(alpha: 0.9);
    final tooltip = project == null
        ? 'Slot ${slotIndex + 1} vacio'
        : '${project!.name}\n${project!.folderPath}';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.lightBlueAccent : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: slotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  folderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onReplace,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.swap_horiz,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildFolderName(ProjectEntity? project) {
    if (project == null) return 'Seleccionar carpeta';
    final trimmed = project.name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final normalized = project.folderPath.replaceAll(r'\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? normalized : parts.last;
  }
}
