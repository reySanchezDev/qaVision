import 'package:flutter/material.dart';

/// Entidades base para el Lienzo del Visor (§9.1).
///
/// Define los elementos que pueden existir en el lienzo:
/// imágenes y anotaciones.

/// Tipo de anotación disponible.
enum AnnotationType {
  /// Línea con punta de flecha.
  arrow,

  /// Rectángulo de borde.
  rectangle,

  /// Círculo de borde.
  circle,

  /// Trazo libre.
  pencil,

  /// Texto flotante.
  text,

  /// Área difuminada.
  blur,

  /// Círculo con número secuencial.
  stepMarker,

  /// Herramienta de selección y movimiento (§7.0).
  selection,
}

/// Representa un elemento genérico en el lienzo.
sealed class CanvasElement {
  /// Crea un [CanvasElement].
  const CanvasElement({
    required this.id,
    required this.position,
    required this.zIndex,
  });

  /// Identificador único del elemento.
  final String id;

  /// Posición inicial (top-left) en el lienzo.
  final Offset position;

  /// Orden de apilamiento (capa).
  final int zIndex;
}

/// Representa una imagen en el lienzo (§9.4).
class ImageElement extends CanvasElement {
  /// Crea un [ImageElement].
  const ImageElement({
    required super.id,
    required super.position,
    required super.zIndex,
    required this.path,
    required this.size,
    this.image, // Decoded image for rendering
  });

  /// Ruta al archivo de imagen.
  final String path;

  /// Tamaño de visualización de la imagen.
  final Size size;

  /// Objeto de imagen decodificado (§9.2).
  final dynamic image;

  /// Crea una copia de este objeto con los campos dados cambiados.
  ImageElement copyWith({
    String? id,
    Offset? position,
    int? zIndex,
    String? path,
    Size? size,
    dynamic image,
  }) {
    return ImageElement(
      id: id ?? this.id,
      position: position ?? this.position,
      zIndex: zIndex ?? this.zIndex,
      path: path ?? this.path,
      size: size ?? this.size,
      image: image ?? this.image,
    );
  }
}

/// Representa una anotación vectorial (§9.4).
class AnnotationElement extends CanvasElement {
  /// Crea un [AnnotationElement].
  const AnnotationElement({
    required super.id,
    required super.position,
    required super.zIndex,
    required this.type,
    required this.color,
    required this.strokeWidth,
    this.endPosition,
    this.points = const [],
    this.text = '',
  });

  /// Tipo de anotación.
  final AnnotationType type;

  /// Color en formato ARB.
  final int color;

  /// Grosor del trazo.
  final double strokeWidth;

  /// Posición final (para flechas, rectángulos, etc.).
  final Offset? endPosition;

  /// Lista de puntos para dibujo libre (pencil).
  final List<Offset> points;

  /// Contenido de texto (para etiquetas o marcadores).
  final String text;

  /// Crea una copia de este objeto con los campos dados cambiados.
  AnnotationElement copyWith({
    String? id,
    Offset? position,
    int? zIndex,
    AnnotationType? type,
    int? color,
    double? strokeWidth,
    Offset? endPosition,
    List<Offset>? points,
    String? text,
  }) {
    return AnnotationElement(
      id: id ?? this.id,
      position: position ?? this.position,
      zIndex: zIndex ?? this.zIndex,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      endPosition: endPosition ?? this.endPosition,
      points: points ?? this.points,
      text: text ?? this.text,
    );
  }
}

/// Estado actual del cuadro (composición de elementos) (§9.1).
class FrameState {
  /// Crea un [FrameState].
  const FrameState({
    this.canvasSize = const Size(1920, 1080),
    this.elements = const [],
    this.backgroundColor = 0xFF121212, // Color de fondo por defecto (§9.0)
  });

  /// Tamaño total del lienzo de trabajo.
  final Size canvasSize;

  /// Lista de elementos presentes en este cuadro.
  final List<CanvasElement> elements;

  /// Color de fondo del lienzo en formato ARB.
  final int backgroundColor;

  /// Crea una copia de este componente con los campos dados cambiados.
  FrameState copyWith({
    Size? canvasSize,
    List<CanvasElement>? elements,
    int? backgroundColor,
  }) {
    // Si se pasan elementos, recalculamos el tamaño si es necesario
    var finalSize = canvasSize ?? this.canvasSize;
    if (elements != null && elements.isNotEmpty) {
      var maxX = 0.0;
      var maxY = 0.0;
      for (final e in elements) {
        if (e is ImageElement) {
          maxX = maxX > (e.position.dx + e.size.width)
              ? maxX
              : (e.position.dx + e.size.width);
          maxY = maxY > (e.position.dy + e.size.height)
              ? maxY
              : (e.position.dy + e.size.height);
        } else if (e is AnnotationElement && e.endPosition != null) {
          maxX = maxX > e.position.dx ? maxX : e.position.dx;
          maxX = maxX > e.endPosition!.dx ? maxX : e.endPosition!.dx;
          maxY = maxY > e.position.dy ? maxY : e.position.dy;
          maxY = maxY > e.endPosition!.dy ? maxY : e.endPosition!.dy;
        } else {
          maxX = maxX > e.position.dx ? maxX : e.position.dx;
          maxY = maxY > e.position.dy ? maxY : e.position.dy;
        }
      }
      // Añadir margen
      finalSize = Size(maxX + 100, maxY + 100);
    }

    return FrameState(
      canvasSize: finalSize,
      elements: elements ?? this.elements,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
