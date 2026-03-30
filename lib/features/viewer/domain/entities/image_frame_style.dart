import 'package:equatable/equatable.dart';

/// Estilo visual de un contenedor de imagen dentro del visor.
class ImageFrameStyle extends Equatable {
  /// Crea una instancia de [ImageFrameStyle].
  const ImageFrameStyle({
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.padding,
  });

  /// Color de fondo ARGB.
  final int backgroundColor;

  /// Opacidad de fondo entre 0 y 1.
  final double backgroundOpacity;

  /// Color de borde ARGB.
  final int borderColor;

  /// Grosor del borde.
  final double borderWidth;

  /// Padding interno del frame.
  final double padding;

  /// Crea una copia con cambios puntuales.
  ImageFrameStyle copyWith({
    int? backgroundColor,
    double? backgroundOpacity,
    int? borderColor,
    double? borderWidth,
    double? padding,
  }) {
    return ImageFrameStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      padding: padding ?? this.padding,
    );
  }

  @override
  List<Object?> get props => [
    backgroundColor,
    backgroundOpacity,
    borderColor,
    borderWidth,
    padding,
  ];
}
