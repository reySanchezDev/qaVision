import 'dart:math' as math;
import 'dart:ui';

/// Utilidades unificadas para transformar coordenadas entre viewport y canvas.
///
/// Mantiene en un unico lugar la logica de zoom, fit, max-zoom y conversion
/// de puntos/tamanos/rectangulos. Esto reduce regresiones cuando cambia el
/// comportamiento visual del visor.
class ViewerViewportTransformService {
  /// Zoom minimo absoluto permitido para vista general del viewport.
  static const double defaultViewMinZoom = 0.1;

  /// Zoom minimo saludable para operaciones de edicion.
  static const double defaultEditableMinZoom = 0.75;

  /// Alias legado para compatibilidad con llamadas existentes.
  static const double defaultMinZoom = defaultViewMinZoom;

  /// Zoom maximo duro permitido por defecto para el viewport.
  static const double defaultHardMaxZoom = 3;

  /// Padding visual usado por defecto al calcular el fit.
  static const double defaultFitPadding = 48;

  /// Normaliza cualquier valor de zoom invalido.
  static double normalizeZoom(
    double zoom, {
    double minZoom = defaultViewMinZoom,
    double maxZoom = 10,
  }) {
    if (!zoom.isFinite || zoom <= 0) {
      return 1.clamp(minZoom, maxZoom).toDouble();
    }
    return zoom.clamp(minZoom, maxZoom);
  }

  /// Indica si el contenido requiere un transform visual.
  static bool shouldScaleContent(double zoom) {
    return (normalizeZoom(zoom) - 1.0).abs() > 0.001;
  }

  /// Convierte un punto visual del viewport al espacio logico del canvas.
  static Offset toLogicalPoint({
    required Offset displayPoint,
    required double zoom,
  }) {
    return displayPoint;
  }

  /// Convierte un punto logico del canvas al espacio visual del viewport.
  static Offset toDisplayPoint({
    required Offset logicalPoint,
    required double zoom,
  }) {
    return logicalPoint;
  }

  /// Convierte un tamano visual al espacio logico.
  static Size toLogicalSize({
    required Size displaySize,
    required double zoom,
  }) {
    return displaySize;
  }

  /// Convierte un tamano logico al espacio visual.
  static Size toDisplaySize({
    required Size logicalSize,
    required double zoom,
  }) {
    return logicalSize;
  }

  /// Convierte un rectangulo visual al espacio logico.
  static Rect toLogicalRect({
    required Rect displayRect,
    required double zoom,
  }) {
    final logicalTopLeft = toLogicalPoint(
      displayPoint: displayRect.topLeft,
      zoom: zoom,
    );
    final logicalSize = toLogicalSize(
      displaySize: displayRect.size,
      zoom: zoom,
    );
    return Rect.fromLTWH(
      logicalTopLeft.dx,
      logicalTopLeft.dy,
      logicalSize.width,
      logicalSize.height,
    );
  }

  /// Convierte un rectangulo logico al espacio visual.
  static Rect toDisplayRect({
    required Rect logicalRect,
    required double zoom,
  }) {
    final displayTopLeft = toDisplayPoint(
      logicalPoint: logicalRect.topLeft,
      zoom: zoom,
    );
    final displaySize = toDisplaySize(
      logicalSize: logicalRect.size,
      zoom: zoom,
    );
    return Rect.fromLTWH(
      displayTopLeft.dx,
      displayTopLeft.dy,
      displaySize.width,
      displaySize.height,
    );
  }

  /// Resuelve el zoom maximo permitido para una imagen respecto al canvas.
  static double resolveMaxZoom({
    required Size canvasSize,
    required Size imageSize,
    double minZoom = defaultViewMinZoom,
    double hardMaxZoom = defaultHardMaxZoom,
  }) {
    final maxWidthZoom = canvasSize.width / imageSize.width;
    final maxHeightZoom = canvasSize.height / imageSize.height;
    final limit = math.min(maxWidthZoom, maxHeightZoom);
    if (!limit.isFinite) {
      return hardMaxZoom;
    }
    return limit.clamp(minZoom, hardMaxZoom);
  }

  /// Resuelve el zoom que ajusta la imagen al viewport disponible.
  static double resolveFitZoom({
    required Size viewportSize,
    required Size imageSize,
    double minZoom = defaultViewMinZoom,
    double maxZoom = defaultHardMaxZoom,
    double padding = defaultFitPadding,
  }) {
    if (viewportSize == Size.zero) {
      return 1.clamp(minZoom, maxZoom).toDouble();
    }

    final availableWidth = math.max(1, viewportSize.width - padding);
    final availableHeight = math.max(1, viewportSize.height - padding);
    final fitZoom = math.min(
      availableWidth / imageSize.width,
      availableHeight / imageSize.height,
    );

    return fitZoom.clamp(minZoom, maxZoom);
  }
}
