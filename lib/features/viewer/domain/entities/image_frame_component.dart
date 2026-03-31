import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Componente de alto nivel que representa un frame de imagen en el visor.
///
/// Esta abstracción permite tratar la imagen como una pieza modular con
/// propiedades explícitas de estilo y transformación.
class ImageFrameComponent extends CanvasElement with EquatableMixin {
  /// Crea una instancia de [ImageFrameComponent].
  const ImageFrameComponent({
    required super.id,
    required super.position,
    required super.zIndex,
    required this.path,
    required this.contentSize,
    required this.style,
    required this.transform,
    this.image,
    this.parentImageId,
    this.isLockedBase = false,
  });

  /// Ruta del archivo fuente.
  final String path;

  /// Tamaño visual del contenido de imagen antes de clipping.
  final Size contentSize;

  /// Estilo visual del frame.
  final ImageFrameStyle style;

  /// Transformaciones geométricas del frame.
  final ImageFrameTransform transform;

  /// Imagen decodificada (`ui.Image`) cuando está cargada.
  final dynamic image;

  /// Id del frame padre cuando esta imagen vive dentro de otro frame.
  final String? parentImageId;

  /// Indica si este frame corresponde a la captura base bloqueada.
  final bool isLockedBase;

  /// Tamaño del frame.
  Size get size => transform.size;

  /// Offset del contenido.
  Offset get contentOffset => transform.contentOffset;

  /// Zoom lógico del componente.
  double get zoom => transform.zoom;

  /// Rectángulo externo del frame.
  Rect get frameRect => position & size;

  /// Padding efectivo limitado por el tamaño del frame.
  double get clampedPadding {
    final maxPadding = math.max(0, math.min(size.width, size.height) / 2 - 1);
    return style.padding.clamp(0, maxPadding).toDouble();
  }

  /// Rectángulo de viewport interno donde se clippea la imagen.
  Rect get contentViewportRect {
    final padding = clampedPadding;
    final rect = frameRect;
    return Rect.fromLTWH(
      rect.left + padding,
      rect.top + padding,
      math.max(1, rect.width - (padding * 2)),
      math.max(1, rect.height - (padding * 2)),
    );
  }

  /// Ajusta el offset interno del contenido para mantener intersección.
  Offset clampContentOffset(Offset offset) {
    final viewport = contentViewportRect;
    final minX = math.min(0, viewport.width - contentSize.width);
    final maxX = math.max(0, viewport.width - contentSize.width);
    final minY = math.min(0, viewport.height - contentSize.height);
    final maxY = math.max(0, viewport.height - contentSize.height);
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }

  /// Rectángulo de dibujo final del contenido dentro del frame.
  Rect get imageDrawRect {
    final viewport = contentViewportRect;
    final boundedOffset = clampContentOffset(contentOffset);
    return Rect.fromLTWH(
      viewport.left + boundedOffset.dx,
      viewport.top + boundedOffset.dy,
      contentSize.width,
      contentSize.height,
    );
  }

  /// Crea una copia con cambios puntuales.
  ImageFrameComponent copyWith({
    String? id,
    Offset? position,
    int? zIndex,
    String? path,
    Size? contentSize,
    ImageFrameStyle? style,
    ImageFrameTransform? transform,
    dynamic image,
    String? parentImageId,
    bool clearParentImageId = false,
    bool? isLockedBase,
  }) {
    // Sincronización: si se pasa una nueva posición pero no un transform,
    // actualizamos la posición dentro del transform actual.
    // Si se pasa un nuevo transform pero no una posición, la posición
    // se deriva del nuevo transform.
    final nextTransform =
        transform ??
        (position != null
            ? this.transform.copyWith(position: position)
            : this.transform);

    final nextPosition =
        position ?? (transform != null ? transform.position : this.position);

    return ImageFrameComponent(
      id: id ?? this.id,
      position: nextPosition,
      zIndex: zIndex ?? this.zIndex,
      path: path ?? this.path,
      contentSize: contentSize ?? this.contentSize,
      style: style ?? this.style,
      transform: nextTransform,
      image: image ?? this.image,
      parentImageId: clearParentImageId
          ? null
          : (parentImageId ?? this.parentImageId),
      isLockedBase: isLockedBase ?? this.isLockedBase,
    );
  }

  @override
  List<Object?> get props => [
    id,
    position,
    zIndex,
    path,
    contentSize,
    style,
    transform,
    image,
    parentImageId,
    isLockedBase,
  ];
}
