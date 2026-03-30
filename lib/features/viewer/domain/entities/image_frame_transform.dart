import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Transformaciones geométricas del frame de imagen.
class ImageFrameTransform extends Equatable {
  /// Crea una instancia de [ImageFrameTransform].
  const ImageFrameTransform({
    required this.position,
    required this.size,
    this.contentOffset = Offset.zero,
    this.zoom = 1,
  });

  /// Posición top-left del frame en coordenadas del canvas.
  final Offset position;

  /// Tamaño del frame en el canvas.
  final Size size;

  /// Desplazamiento del contenido de imagen dentro del frame.
  final Offset contentOffset;

  /// Zoom lógico del contenido del frame.
  final double zoom;

  /// Crea una copia con cambios puntuales.
  ImageFrameTransform copyWith({
    Offset? position,
    Size? size,
    Offset? contentOffset,
    double? zoom,
  }) {
    return ImageFrameTransform(
      position: position ?? this.position,
      size: size ?? this.size,
      contentOffset: contentOffset ?? this.contentOffset,
      zoom: zoom ?? this.zoom,
    );
  }

  @override
  List<Object?> get props => [
    position,
    size,
    contentOffset,
    zoom,
  ];
}
