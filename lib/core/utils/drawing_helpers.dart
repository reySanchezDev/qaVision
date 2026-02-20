import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ayudantes para el dibujo manual en el visor (§9.4).
class DrawingHelpers {
  /// Dibuja una flecha entre dos puntos.
  static void drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double arrowSize = 15,
  }) {
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    final p1 = Offset(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final p2 = Offset(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = paint.color);
  }

  /// Dibuja un rectángulo con bordes definidos.
  static void drawRectangle(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    canvas.drawRect(Rect.fromPoints(p1, p2), paint);
  }

  /// Dibuja un círculo circunscrito en el área definida por p1 y p2.
  static void drawCircle(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    canvas.drawOval(Rect.fromPoints(p1, p2), paint);
  }
}
