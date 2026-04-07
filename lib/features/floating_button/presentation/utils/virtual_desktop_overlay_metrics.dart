import 'dart:ui';

/// Métricas del escritorio virtual para overlays que deben cubrir todos los
/// monitores activos en Windows.
class VirtualDesktopOverlayMetrics {
  /// Crea una instancia inmutable con bounds lógicos y físicos del overlay.
  const VirtualDesktopOverlayMetrics({
    required this.logicalBounds,
    required this.physicalBounds,
    required this.devicePixelRatio,
  });

  /// Bounds lógicos usados por `window_manager` y el lienzo Flutter.
  final Rect logicalBounds;

  /// Bounds físicos reales del escritorio virtual en píxeles de Windows.
  final Rect physicalBounds;

  /// DPR aplicado por la ventana Flutter que aloja el overlay.
  final double devicePixelRatio;

  /// Posición lógica superior izquierda del overlay.
  Offset get logicalOrigin => logicalBounds.topLeft;

  /// Tamaño lógico del overlay.
  Size get logicalSize => logicalBounds.size;

  /// Convierte un rectángulo local del overlay a coordenadas físicas del
  /// escritorio virtual, que es lo que consumen la captura nativa y `ffmpeg`.
  Rect selectionToPhysicalRect(Rect localSelectionRect) {
    return Rect.fromLTWH(
      physicalBounds.left + (localSelectionRect.left * devicePixelRatio),
      physicalBounds.top + (localSelectionRect.top * devicePixelRatio),
      localSelectionRect.width * devicePixelRatio,
      localSelectionRect.height * devicePixelRatio,
    );
  }
}

/// Construye las métricas de overlay a partir del rectángulo físico del
/// escritorio virtual y el DPR actual de la ventana.
VirtualDesktopOverlayMetrics buildVirtualDesktopOverlayMetrics({
  required Rect physicalBounds,
  required double devicePixelRatio,
}) {
  final safeDpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
  return VirtualDesktopOverlayMetrics(
    physicalBounds: physicalBounds,
    logicalBounds: Rect.fromLTWH(
      physicalBounds.left / safeDpr,
      physicalBounds.top / safeDpr,
      physicalBounds.width / safeDpr,
      physicalBounds.height / safeDpr,
    ),
    devicePixelRatio: safeDpr,
  );
}
