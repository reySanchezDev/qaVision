import 'package:flutter/material.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

enum _RecentStripProjectAction { replace, remove }

/// Control visual para cada carpeta/proyecto de la cinta.
class RecentStripProjectSlotControl extends StatefulWidget {
  /// Crea una instancia de [RecentStripProjectSlotControl].
  const RecentStripProjectSlotControl({
    required this.project,
    required this.isSelected,
    required this.onSelect,
    this.onReplace,
    this.onRemove,
    super.key,
  });

  /// Proyecto asignado al chip.
  final ProjectEntity? project;

  /// Estado de selección visual.
  final bool isSelected;

  /// Acción para activar el chip.
  final VoidCallback? onSelect;

  /// Acción para cambiar la carpeta asignada.
  final VoidCallback? onReplace;

  /// Acción para quitar la carpeta de la cinta.
  final VoidCallback? onRemove;

  @override
  State<RecentStripProjectSlotControl> createState() =>
      _RecentStripProjectSlotControlState();
}

class _RecentStripProjectSlotControlState
    extends State<RecentStripProjectSlotControl> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final folderName = _buildFolderName(project);
    final slotColor = project == null
        ? Colors.white24
        : Color(project.color).withValues(alpha: 0.9);
    final tooltip = project == null
        ? 'Carpeta no disponible'
        : '${project.name}\n'
              '${project.folderPath}\n'
              'Usa ⋯ o clic derecho para opciones';
    final showActions = project != null && (_isHovering || widget.isSelected);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: InkWell(
            onTap: widget.onSelect,
            onSecondaryTapDown: project == null
                ? null
                : (details) => _showOptionsMenu(context, details.globalPosition),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minWidth: 136, maxWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.lightBlueAccent
                      : Colors.white24,
                  width: widget.isSelected ? 2 : 1,
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
                  Expanded(
                    child: Text(
                      folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IgnorePointer(
                    ignoring: !showActions,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: showActions ? 1 : 0,
                      child: Builder(
                        builder: (buttonContext) {
                          return Tooltip(
                            message: 'Opciones de carpeta',
                            child: InkWell(
                              onTap: () async {
                                final box = buttonContext.findRenderObject();
                                if (box is! RenderBox) return;
                                final origin = box.localToGlobal(
                                  Offset(box.size.width / 2, box.size.height),
                                );
                                await _showOptionsMenu(buttonContext, origin);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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

  Future<void> _showOptionsMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final selected = await showMenu<_RecentStripProjectAction>(
      context: context,
      color: const Color(0xFF171A20),
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.context.size!,
      ),
      constraints: const BoxConstraints(minWidth: 210),
      menuPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      items: [
        if (widget.onReplace != null)
          PopupMenuItem<_RecentStripProjectAction>(
            value: _RecentStripProjectAction.replace,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.drive_folder_upload_outlined,
                    size: 17,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Cambiar carpeta',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (widget.onRemove != null)
          PopupMenuItem<_RecentStripProjectAction>(
            value: _RecentStripProjectAction.remove,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A1E22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: Color(0xFFFFA4AD),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quitar',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );

    switch (selected) {
      case _RecentStripProjectAction.replace:
        widget.onReplace?.call();
      case _RecentStripProjectAction.remove:
        widget.onRemove?.call();
      case null:
        break;
    }
  }
}

/// Botón compacto para agregar otra carpeta a la cinta.
class RecentStripAddFolderControl extends StatelessWidget {
  /// Crea una instancia de [RecentStripAddFolderControl].
  const RecentStripAddFolderControl({
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// Acción para abrir el selector de carpeta.
  final VoidCallback onPressed;

  /// Indica si aún se pueden agregar más carpetas.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled
          ? 'Agregar carpeta'
          : 'Máximo de 6 carpetas en la cinta',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 144),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF1A1D22)
                  : const Color(0xFF17191D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? Colors.white24 : Colors.white10,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: enabled ? Colors.white70 : Colors.white30,
                ),
                const SizedBox(width: 8),
                Text(
                  'Agregar carpeta',
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
