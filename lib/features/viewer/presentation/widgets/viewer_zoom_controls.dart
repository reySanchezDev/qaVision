import 'package:flutter/material.dart';

/// Controles de zoom del canvas del visor.
class ViewerZoomControls extends StatelessWidget {
  /// Crea una instancia de [ViewerZoomControls].
  const ViewerZoomControls({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    super.key,
  });

  /// Zoom actual entre 1 y 1+.
  final double zoom;

  /// Acción de acercar.
  final VoidCallback onZoomIn;

  /// Acción de alejar.
  final VoidCallback onZoomOut;

  /// Acción de reset a zoom base.
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Alejar',
              icon: const Icon(Icons.remove, size: 18),
              color: Colors.white70,
              onPressed: onZoomOut,
            ),
            InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${(zoom * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
