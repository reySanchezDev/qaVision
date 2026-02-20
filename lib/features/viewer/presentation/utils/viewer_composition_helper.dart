import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qavision/core/utils/drawing_helpers.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Utilidades para renderizar elementos del lienzo en un [Canvas] (§9.3).
///
/// Lógica compartida entre el [CustomPainter] y el motor de composición.
class ViewerCompositionHelper {
  /// Renderiza un estado completo del cuadro en el [canvas] proporcionado.
  static void paintFrame(ui.Canvas canvas, FrameState frame) {
    // Dibujar fondo (§9.0)
    canvas.drawRect(
      Offset.zero & frame.canvasSize,
      Paint()..color = Color(frame.backgroundColor),
    );

    // Ordenar elementos por zIndex para dibujar capas correctamente.
    final sortedElements = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final element in sortedElements) {
      if (element is ImageElement) {
        drawImage(canvas, element);
      } else if (element is AnnotationElement) {
        drawAnnotation(canvas, element);
      }
    }
  }

  /// Dibuja una imagen en el [canvas].
  static void drawImage(ui.Canvas canvas, ImageElement element) {
    if (element.image is ui.Image) {
      final uiImage = element.image as ui.Image;
      canvas.drawImageRect(
        uiImage,
        Rect.fromLTWH(
          0,
          0,
          uiImage.width.toDouble(),
          uiImage.height.toDouble(),
        ),
        element.position & element.size,
        Paint(),
      );
    } else {
      final rect = element.position & element.size;
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  /// Dibuja una anotación en el [canvas].
  static void drawAnnotation(ui.Canvas canvas, AnnotationElement element) {
    final paint = Paint()
      ..color = Color(element.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth
      ..strokeCap = ui.StrokeCap.round;

    switch (element.type) {
      case AnnotationType.arrow:
        if (element.endPosition != null) {
          DrawingHelpers.drawArrow(
            canvas,
            element.position,
            element.endPosition!,
            paint,
          );
        }
      case AnnotationType.rectangle:
        if (element.endPosition != null) {
          DrawingHelpers.drawRectangle(
            canvas,
            element.position,
            element.endPosition!,
            paint,
          );
        }
      case AnnotationType.circle:
        if (element.endPosition != null) {
          DrawingHelpers.drawCircle(
            canvas,
            element.position,
            element.endPosition!,
            paint,
          );
        }
      case AnnotationType.pencil:
        if (element.points.length > 1) {
          final path = Path()
            ..moveTo(element.points.first.dx, element.points.first.dy);
          for (var i = 1; i < element.points.length; i++) {
            path.lineTo(element.points[i].dx, element.points[i].dy);
          }
          canvas.drawPath(path, paint);
        }
      case AnnotationType.text:
        _drawText(canvas, element);
      case AnnotationType.blur:
        _drawBlur(canvas, element);
      case AnnotationType.stepMarker:
        _drawStepMarker(canvas, element);
      case AnnotationType.selection:
        // La selección no dibuja nada adicional por ahora (§7.0)
        break;
    }
  }

  static void _drawText(ui.Canvas canvas, AnnotationElement element) {
    TextPainter(
        text: TextSpan(
          text: element.text,
          style: TextStyle(
            color: Color(element.color),
            fontSize: element.strokeWidth * 4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, element.position);
  }

  static void _drawBlur(ui.Canvas canvas, AnnotationElement element) {
    if (element.endPosition == null) return;
    final rect = Rect.fromPoints(element.position, element.endPosition!);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill,
    );
  }

  static void _drawStepMarker(ui.Canvas canvas, AnnotationElement element) {
    final paint = Paint()..color = Color(element.color);
    canvas.drawCircle(element.position, 15, paint);
    final textPainter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      element.position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
