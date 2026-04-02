import 'package:flutter/material.dart';

/// Controles de zoom del canvas del visor.
class ViewerZoomControls extends StatelessWidget {
  /// Crea una instancia de [ViewerZoomControls].
  const ViewerZoomControls({
    required this.zoom,
    required this.fitZoom,
    required this.minEditableZoom,
    required this.canZoomOut,
    required this.onFitToScreen,
    required this.onActualSize,
    required this.onZoomIn,
    required this.onZoomOut,
    super.key,
  });

  /// Zoom actual entre 1 y 1+.
  final double zoom;

  /// Zoom calculado para ajustar la imagen al viewport.
  final double fitZoom;

  /// Zoom minimo saludable para acciones manuales de edicion.
  final double minEditableZoom;

  /// Indica si todavia es saludable seguir alejando manualmente.
  final bool canZoomOut;

  /// Accion para ajustar al area visible.
  final VoidCallback onFitToScreen;

  /// Accion para volver al tamano real.
  final VoidCallback onActualSize;

  /// Acción de acercar.
  final VoidCallback onZoomIn;

  /// Acción de alejar.
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final isFitActive = (zoom - fitZoom).abs() < 0.02;
    final isActualSize = (zoom - 1).abs() < 0.02;
    final isBelowEditableFloor = zoom < minEditableZoom - 0.02;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomActionButton(
              tooltip: 'Ajustar a pantalla',
              label: 'Fit',
              isActive: isFitActive,
              onPressed: onFitToScreen,
            ),
            const _ZoomDivider(),
            _ZoomActionButton(
              tooltip: 'Tamano real',
              label: '100%',
              isActive: isActualSize,
              onPressed: onActualSize,
            ),
            const _ZoomDivider(),
            IconButton(
              tooltip: 'Alejar',
              icon: const Icon(Icons.remove, size: 18),
              color: Colors.white70,
              onPressed: canZoomOut ? onZoomOut : null,
            ),
            SizedBox(
              width: 56,
              child: Center(
                child: Text(
                  '${(zoom * 100).round()}%',
                  style: TextStyle(
                    color: isBelowEditableFloor
                        ? const Color(0xFFFFD180)
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Acercar',
              icon: const Icon(Icons.add, size: 18),
              color: Colors.white70,
              onPressed: onZoomIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomActionButton extends StatelessWidget {
  const _ZoomActionButton({
    required this.tooltip,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: isActive ? Colors.white : Colors.white70,
          backgroundColor: isActive
              ? Colors.lightBlueAccent.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ZoomDivider extends StatelessWidget {
  const _ZoomDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white12,
    );
  }
}
