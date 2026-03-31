import 'package:flutter/material.dart';

/// Indicador inline del estado real entre borrador local y guardado final.
class RecentStripSaveIndicator extends StatelessWidget {
  /// Crea una instancia de [RecentStripSaveIndicator].
  const RecentStripSaveIndicator({
    required this.isAutoSaving,
    this.hasFinalSave = false,
    this.recoveredSession = false,
    super.key,
  });

  /// `true` si hay guardado de borrador en curso.
  final bool isAutoSaving;

  /// `true` si en la sesion actual ya se genero una imagen final.
  final bool hasFinalSave;

  /// `true` si la sesion actual se recupero desde un borrador.
  final bool recoveredSession;

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();

    return Tooltip(
      message: status.tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                status.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SaveIndicatorStatus _resolveStatus() {
    if (isAutoSaving) {
      return _SaveIndicatorStatus(
        background: Colors.orange.withValues(alpha: 0.82),
        icon: Icons.sync_rounded,
        text: 'Borrador local...',
        tooltip:
            'QAVision esta guardando un borrador recuperable. '
            'La imagen final aun no se actualiza fuera del visor.',
      );
    }
    if (recoveredSession) {
      return _SaveIndicatorStatus(
        background: Colors.lightBlue.withValues(alpha: 0.78),
        icon: Icons.restore_page_outlined,
        text: 'Borrador recuperado',
        tooltip:
            'Estas viendo una sesion recuperada desde borrador. '
            'Usa Guardar para actualizar la imagen final.',
      );
    }
    if (hasFinalSave) {
      return _SaveIndicatorStatus(
        background: Colors.green.withValues(alpha: 0.75),
        icon: Icons.task_alt_rounded,
        text: 'Imagen final guardada',
        tooltip:
            'La imagen final ya fue exportada y cualquier visor externo '
            'deberia ver estos cambios.',
      );
    }
    return _SaveIndicatorStatus(
      background: const Color(0xFF4B5563).withValues(alpha: 0.82),
      icon: Icons.edit_note_rounded,
      text: 'Edicion local',
      tooltip:
          'Hay cambios en la sesion del visor. '
          'Usa Guardar para generar la imagen final visible fuera de QAVision.',
    );
  }
}

class _SaveIndicatorStatus {
  const _SaveIndicatorStatus({
    required this.background,
    required this.icon,
    required this.text,
    required this.tooltip,
  });

  final Color background;
  final IconData icon;
  final String text;
  final String tooltip;
}
