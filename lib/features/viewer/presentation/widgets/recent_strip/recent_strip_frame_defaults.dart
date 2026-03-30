/// Defaults de estilo del frame al insertar/abrir imágenes desde la tira.
class RecentStripFrameDefaults {
  /// Crea una instancia de [RecentStripFrameDefaults].
  const RecentStripFrameDefaults({
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.padding,
  });

  /// Color de fondo.
  final int backgroundColor;

  /// Opacidad de fondo.
  final double backgroundOpacity;

  /// Color de borde.
  final int borderColor;

  /// Grosor de borde.
  final double borderWidth;

  /// Padding interno.
  final double padding;
}
