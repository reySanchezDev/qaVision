/// Defaults visuales aplicados al frame base de imagen en el visor.
class ViewerImageFrameDefaults {
  /// Crea un conjunto de defaults para frames de imagen.
  const ViewerImageFrameDefaults({
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.padding,
  });

  /// Color ARGB del fondo del frame.
  final int backgroundColor;

  /// Opacidad del fondo del frame.
  final double backgroundOpacity;

  /// Color ARGB del borde del frame.
  final int borderColor;

  /// Grosor del borde del frame.
  final double borderWidth;

  /// Padding interno del frame.
  final double padding;
}
