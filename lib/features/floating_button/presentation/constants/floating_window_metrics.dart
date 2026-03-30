import 'dart:ui';

/// Cantidad de accesos rapidos de proyectos visibles.
const int kFloatingQuickAccessCount = 3;

/// Cantidad de botones de modo de captura.
const int kFloatingCaptureModeCount = 3;

/// Cantidad de botones del extremo izquierdo.
const int kFloatingLeftEdgeActionCount = 1;

/// Cantidad de botones del extremo derecho.
const int kFloatingRightEdgeActionCount = 2;

/// Tamano base de boton circular secundario.
const double kFloatingControlButtonSize = 42;

/// Tamano del boton principal de captura.
const double kFloatingCaptureButtonSize = 56;

/// Separacion uniforme entre controles.
const double kFloatingControlGap = 8;

/// Tamano de icono para controles.
const double kFloatingControlIconSize = 22;

/// Padding interno del panel visible (fondo redondeado).
const double kFloatingPanelInnerPadding = 8;

/// Padding externo de seguridad para sombras dentro de la ventana.
const double kFloatingWindowOuterPadding = 12;

/// Franja visible que queda expuesta al acoplar la ventana fuera del borde.
const double kFloatingDockPeek = 18;

const int _kFloatingStandardButtonCount =
    kFloatingLeftEdgeActionCount +
    kFloatingQuickAccessCount +
    kFloatingCaptureModeCount +
    kFloatingRightEdgeActionCount;

const int _kFloatingTotalButtonCount = _kFloatingStandardButtonCount + 1;
const int _kFloatingGapCount = _kFloatingTotalButtonCount - 1;

const double _kFloatingHorizontalContentExtent =
    (_kFloatingStandardButtonCount * kFloatingControlButtonSize) +
    kFloatingCaptureButtonSize +
    (_kFloatingGapCount * kFloatingControlGap);

const double _kFloatingVerticalContentExtent =
    (_kFloatingStandardButtonCount * kFloatingControlButtonSize) +
    kFloatingCaptureButtonSize +
    (_kFloatingGapCount * kFloatingControlGap);

/// Ancho de ventana en horizontal autoajustado al contenido.
const double kFloatingHorizontalWidth =
    _kFloatingHorizontalContentExtent +
    (kFloatingPanelInnerPadding * 2) +
    (kFloatingWindowOuterPadding * 2);

/// Alto de ventana en horizontal autoajustado al contenido.
const double kFloatingHorizontalHeight =
    kFloatingCaptureButtonSize +
    (kFloatingPanelInnerPadding * 2) +
    (kFloatingWindowOuterPadding * 2);

/// Tamano de ventana usado en orientacion horizontal.
const Size kFloatingHorizontalSize = Size(
  kFloatingHorizontalWidth,
  kFloatingHorizontalHeight,
);

/// Ancho de ventana en vertical autoajustado al contenido.
const double kFloatingVerticalWidth =
    kFloatingCaptureButtonSize +
    (kFloatingPanelInnerPadding * 2) +
    (kFloatingWindowOuterPadding * 2);

/// Alto de ventana en vertical autoajustado al contenido.
const double kFloatingVerticalHeight =
    _kFloatingVerticalContentExtent +
    (kFloatingPanelInnerPadding * 2) +
    (kFloatingWindowOuterPadding * 2);

/// Tamano de ventana usado en orientacion vertical.
const Size kFloatingVerticalSize = Size(
  kFloatingVerticalWidth,
  kFloatingVerticalHeight,
);
