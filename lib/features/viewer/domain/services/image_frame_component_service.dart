import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';

/// Operaciones de dominio para manipular [ImageFrameComponent].
class ImageFrameComponentService {
  /// Tamaño mínimo permitido para ancho/alto del frame.
  static const double minFrameSize = 8;

  /// Ajusta una posición para que el frame quede dentro de [frameSize].
  static Offset clampPositionToFrame({
    required Offset position,
    required Size size,
    required Size frameSize,
    Rect? movementBounds,
    double displayScale = 1,
  }) {
    final bounds = movementBounds ?? (Offset.zero & frameSize);
    final scaledWidth = size.width * displayScale;
    final scaledHeight = size.height * displayScale;
    final minX = bounds.left;
    final maxX = math.max(bounds.left, bounds.right - scaledWidth);
    final minY = bounds.top;
    final maxY = math.max(bounds.top, bounds.bottom - scaledHeight);

    return Offset(
      position.dx.clamp(minX, maxX),
      position.dy.clamp(minY, maxY),
    );
  }

  /// Ajusta un tamaño para respetar límites del canvas.
  static Size clampSizeToFrame({
    required Size size,
    required Size frameSize,
    Rect? movementBounds,
    double displayScale = 1,
  }) {
    final bounds = movementBounds ?? (Offset.zero & frameSize);
    final scale = displayScale <= 0 ? 1.0 : displayScale;
    return Size(
      size.width.clamp(minFrameSize, bounds.width / scale),
      size.height.clamp(minFrameSize, bounds.height / scale),
    );
  }

  /// Ajusta el padding del frame al tamaño disponible.
  static double clampPaddingToFrame(double padding, Size frameSize) {
    final maxPadding = math.max(
      0,
      math.min(frameSize.width, frameSize.height) / 2 - 1,
    );
    return padding.clamp(0, maxPadding).toDouble();
  }

  /// Mueve el componente y lo mantiene dentro del canvas.
  static ImageFrameComponent move({
    required ImageFrameComponent component,
    required Offset position,
    required Size frameSize,
    Rect? movementBounds,
    double displayScale = 1,
  }) {
    final boundedPosition = clampPositionToFrame(
      position: position,
      size: component.size,
      frameSize: frameSize,
      movementBounds: movementBounds,
      displayScale: displayScale,
    );
    return component.copyWith(
      transform: component.transform.copyWith(position: boundedPosition),
    );
  }

  /// Redimensiona el componente dentro del canvas y recalcula su offset.
  /// Mantiene el contenido fijo en el espacio global compensando
  /// el contentOffset.
  static ImageFrameComponent resize({
    required ImageFrameComponent component,
    required Size size,
    required Size frameSize,
    Offset? position,
    Rect? movementBounds,
    double displayScale = 1,
  }) {
    final boundedSize = clampSizeToFrame(
      size: size,
      frameSize: frameSize,
      movementBounds: movementBounds,
      displayScale: displayScale,
    );
    final targetPosition = position ?? component.position;
    final boundedPosition = clampPositionToFrame(
      position: targetPosition,
      size: boundedSize,
      frameSize: frameSize,
      movementBounds: movementBounds,
      displayScale: displayScale,
    );

    // Logica Lego Mode: compensamos el desplazamiento del viewport
    // (position + padding)
    // para que el contenido parezca no moverse en coordenadas globales.
    final posDelta = boundedPosition - component.position;
    final oldPadding = component.clampedPadding;

    // Calculamos el nuevo padding basado en el tamaño objetivo.
    final maxPadding = math.max(
      0,
      math.min(boundedSize.width, boundedSize.height) / 2 - 1,
    );
    final newPadding = component.style.padding.clamp(0, maxPadding).toDouble();
    final paddingDelta = newPadding - oldPadding;

    // Compensación total: restamos ambos deltas al offset de contenido.
    final proposedContentOffset =
        component.contentOffset - posDelta - Offset(paddingDelta, paddingDelta);

    final resized = component.copyWith(
      style: component.style.copyWith(padding: newPadding),
      transform: component.transform.copyWith(
        position: boundedPosition,
        size: boundedSize,
      ),
    );

    // Ajustamos el offset compensado a los nuevos límites del viewport.
    return resized.copyWith(
      transform: resized.transform.copyWith(
        contentOffset: resized.clampContentOffset(proposedContentOffset),
      ),
    );
  }

  /// Ajusta el desplazamiento del contenido para no salir del viewport.
  static ImageFrameComponent moveContent({
    required ImageFrameComponent component,
    required Offset proposedOffset,
  }) {
    return component.copyWith(
      transform: component.transform.copyWith(
        contentOffset: component.clampContentOffset(proposedOffset),
      ),
    );
  }

  /// Restringe tamaño, posición, padding y offset del componente al canvas.
  static ImageFrameComponent constrainToCanvas({
    required ImageFrameComponent component,
    required Size frameSize,
    Rect? movementBounds,
    double displayScale = 1,
  }) {
    final resized = resize(
      component: component,
      size: component.size,
      position: component.position,
      frameSize: frameSize,
      movementBounds: movementBounds,
      displayScale: displayScale,
    );
    return moveContent(
      component: resized,
      proposedOffset: resized.contentOffset,
    );
  }

  /// Calcula tamaño visual para encajar imagen cruda dentro del frame.
  static Size fitImageInsideFrame(
    Size raw,
    Size frameSize, {
    double maxFillRatio = 0.55,
  }) {
    final ratioLimit = maxFillRatio.clamp(0.1, 1.0);
    final maxWidth = frameSize.width * ratioLimit;
    final maxHeight = frameSize.height * ratioLimit;
    final widthRatio = maxWidth / raw.width;
    final heightRatio = maxHeight / raw.height;
    final ratio = math.min(1, math.min(widthRatio, heightRatio));
    return Size(raw.width * ratio, raw.height * ratio);
  }
}
