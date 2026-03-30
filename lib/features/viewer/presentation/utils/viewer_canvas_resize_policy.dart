import 'package:flutter/material.dart';

/// Reglas de normalizacion para el tamano del canvas del visor.
class ViewerCanvasResizePolicy {
  static const double _canvasMargin = 200;
  static const double _minWidth = 320;
  static const double _minHeight = 220;
  static const double _maxSize = 12000;

  /// Calcula el tamano esperado de canvas a partir del viewport objetivo.
  static Size expectedCanvasSize(Size targetSize) {
    return Size(
      (targetSize.width + _canvasMargin).clamp(_minWidth, _maxSize),
      (targetSize.height + _canvasMargin).clamp(_minHeight, _maxSize),
    );
  }

  /// Indica si el canvas actual ya cumple el tamano esperado.
  static bool isCanvasAligned({
    required Size targetSize,
    required Size currentSize,
    double tolerance = 0.5,
  }) {
    final expected = expectedCanvasSize(targetSize);
    return (expected.width - currentSize.width).abs() < tolerance &&
        (expected.height - currentSize.height).abs() < tolerance;
  }
}
