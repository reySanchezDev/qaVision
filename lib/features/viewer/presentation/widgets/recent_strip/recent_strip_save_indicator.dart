import 'package:flutter/material.dart';

/// Indicador inline de estado de guardado automático.
class RecentStripSaveIndicator extends StatelessWidget {
  /// Crea una instancia de [RecentStripSaveIndicator].
  const RecentStripSaveIndicator({
    required this.isAutoSaving,
    this.recoveredSession = false,
    super.key,
  });

  /// `true` si hay guardado en curso.
  final bool isAutoSaving;

  /// `true` si la sesión actual se recuperó desde un borrador.
  final bool recoveredSession;

  @override
  Widget build(BuildContext context) {
    final background = isAutoSaving
        ? Colors.orange.withValues(alpha: 0.8)
        : recoveredSession
        ? Colors.lightBlue.withValues(alpha: 0.78)
        : Colors.green.withValues(alpha: 0.75);
    final text = isAutoSaving
        ? 'Guardando borrador...'
        : recoveredSession
        ? 'Sesion recuperada'
        : 'Guardado';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
