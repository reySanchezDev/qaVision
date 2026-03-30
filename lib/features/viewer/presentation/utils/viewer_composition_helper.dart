import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qavision/core/utils/drawing_helpers.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Shared rendering helpers for viewer canvas and export composition.
class ViewerCompositionHelper {
  /// Paints the complete frame.
  static void paintFrame(
    ui.Canvas canvas,
    FrameState frame, {
    bool forExport = false,
    double contentZoom = 1,
  }) {
    canvas.drawRect(
      Offset.zero & frame.canvasSize,
      Paint()..color = Color(frame.backgroundColor),
    );

    final sorted = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final useZoom = !forExport && (contentZoom - 1).abs() > 0.001;
    if (useZoom) {
      final frameRect = Offset.zero & frame.canvasSize;
      final center = frameRect.center;
      canvas
        ..save()
        ..clipRect(frameRect)
        ..translate(center.dx, center.dy)
        ..scale(contentZoom)
        ..translate(-center.dx, -center.dy);
    }

    for (final element in sorted) {
      if (element is ImageFrameComponent) {
        _drawImage(canvas, element, forExport: forExport);
      } else if (element is AnnotationElement) {
        _drawAnnotation(canvas, element);
      }
    }

    if (useZoom) {
      canvas.restore();
    }
  }

  /// Returns the visual bounds of any element.
  static Rect elementBounds(CanvasElement element) {
    if (element is ImageFrameComponent) {
      return imageFrameRect(element);
    }

    if (element is AnnotationElement) {
      return annotationBounds(element);
    }

    return Rect.zero;
  }

  /// Outer frame rect for an image element.
  static Rect imageFrameRect(ImageFrameComponent element) {
    return element.frameRect;
  }

  /// Effective inner viewport rect where image content is clipped.
  static Rect imageContentViewportRect(ImageFrameComponent element) {
    return element.contentViewportRect;
  }

  /// Clamps image content offset so content always intersects the viewport.
  static Offset clampImageContentOffset(
    ImageFrameComponent element,
    Offset offset,
  ) {
    return element.clampContentOffset(offset);
  }

  /// Draw rect for image content inside its frame viewport.
  static Rect imageDrawRect(ImageFrameComponent element) {
    return element.imageDrawRect;
  }

  /// Returns the visual bounds of an annotation.
  static Rect annotationBounds(AnnotationElement element) {
    final strokePadding = math.max(6, element.strokeWidth).toDouble();

    if (element.type == AnnotationType.stepMarker) {
      return Rect.fromCircle(center: element.position, radius: 20);
    }

    if (element.type == AnnotationType.text ||
        element.type == AnnotationType.commentBubble) {
      final textSize = math.max(12, element.textSize).toDouble();
      final width = math
          .max(40, element.text.length * textSize * 0.58)
          .toDouble();
      final height = textSize * 1.55;
      final base = Rect.fromLTWH(
        element.position.dx,
        element.position.dy,
        width,
        height,
      );
      return element.type == AnnotationType.commentBubble
          ? base.inflate(8)
          : base.inflate(4);
    }

    if (element.type == AnnotationType.pencil && element.points.isNotEmpty) {
      var minX = element.points.first.dx;
      var minY = element.points.first.dy;
      var maxX = element.points.first.dx;
      var maxY = element.points.first.dy;
      for (final point in element.points.skip(1)) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokePadding);
    }

    if (element.endPosition != null) {
      return _normalizedRect(element.position, element.endPosition!).inflate(
        strokePadding,
      );
    }

    return Rect.fromCenter(
      center: element.position,
      width: 36,
      height: 36,
    );
  }

  static void _drawImage(
    ui.Canvas canvas,
    ImageFrameComponent component, {
    required bool forExport,
  }) {
    final frameRect = component.frameRect;
    final rawBackgroundOpacity = component.style.backgroundOpacity.clamp(
      0.0,
      1.0,
    );
    final frameBackgroundColor = forExport && rawBackgroundOpacity < 0.01
        ? const Color(0xFFFFFFFF)
        : Color(component.style.backgroundColor).withValues(
            alpha: rawBackgroundOpacity,
          );
    canvas.drawRect(
      frameRect,
      Paint()
        ..style = PaintingStyle.fill
        ..color = frameBackgroundColor,
    );

    final contentRect = component.contentViewportRect;

    canvas
      ..save()
      ..clipRect(contentRect);

    if (component.image is ui.Image) {
      final uiImage = component.image as ui.Image;
      final drawRect = component.imageDrawRect;
      canvas.drawImageRect(
        uiImage,
        Rect.fromLTWH(
          0,
          0,
          uiImage.width.toDouble(),
          uiImage.height.toDouble(),
        ),
        drawRect,
        Paint(),
      );
    } else {
      canvas.drawRect(
        contentRect,
        Paint()..color = Colors.grey.withValues(alpha: 0.4),
      );
    }
    canvas.restore();

    if (component.style.borderWidth > 0) {
      canvas.drawRect(
        frameRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = component.style.borderWidth
          ..color = Color(component.style.borderColor),
      );
    }
  }

  static void _drawAnnotation(ui.Canvas canvas, AnnotationElement element) {
    final strokePaint = Paint()
      ..color = Color(element.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final normalizedOpacity = element.opacity.clamp(0.05, 1.0);

    switch (element.type) {
      case AnnotationType.arrow:
        if (element.endPosition != null) {
          DrawingHelpers.drawArrow(
            canvas,
            element.position,
            element.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.rectangle:
        if (element.endPosition != null) {
          DrawingHelpers.drawRectangle(
            canvas,
            element.position,
            element.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.circle:
        if (element.endPosition != null) {
          DrawingHelpers.drawCircle(
            canvas,
            element.position,
            element.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.highlighter:
        if (element.endPosition != null) {
          final rect = _normalizedRect(element.position, element.endPosition!);
          canvas.drawRect(
            rect,
            Paint()
              ..style = PaintingStyle.fill
              ..color = Color(element.color).withValues(
                alpha: normalizedOpacity,
              ),
          );
        }
      case AnnotationType.pencil:
        if (element.points.length > 1) {
          final path = Path()
            ..moveTo(element.points.first.dx, element.points.first.dy);
          for (final point in element.points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, strokePaint);
        }
      case AnnotationType.text:
        _drawText(canvas, element);
      case AnnotationType.commentBubble:
        _drawCommentBubble(canvas, element);
      case AnnotationType.blur:
        if (element.endPosition != null) {
          final rect = _normalizedRect(element.position, element.endPosition!);
          _drawPixelateMask(canvas, rect, element.color, normalizedOpacity);
        }
      case AnnotationType.stepMarker:
        _drawStepMarker(canvas, element);
      case AnnotationType.eraser:
      // Eraser is handled as action, not as drawable element.
      case AnnotationType.selection:
        // Selection is only a UI tool, no drawing output.
        break;
    }
  }

  static void _drawPixelateMask(
    ui.Canvas canvas,
    Rect rect,
    int color,
    double opacity,
  ) {
    const pixel = 10.0;
    final accent = Color(color);

    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: 0.18 + (opacity * 0.18)),
    );

    var row = 0;
    for (var y = rect.top; y < rect.bottom; y += pixel) {
      var col = 0;
      for (var x = rect.left; x < rect.right; x += pixel) {
        final width = math.min(pixel, rect.right - x);
        final height = math.min(pixel, rect.bottom - y);
        final isEven = (row + col).isEven;
        final blockColor = isEven
            ? Colors.black.withValues(alpha: 0.36)
            : accent.withValues(alpha: 0.22);
        canvas.drawRect(
          Rect.fromLTWH(x, y, width, height),
          Paint()..color = blockColor,
        );
        col++;
      }
      row++;
    }

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.85),
    );
  }

  static void _drawText(ui.Canvas canvas, AnnotationElement element) {
    TextPainter(
        text: TextSpan(
          text: element.text,
          style: TextStyle(
            color: Color(element.color),
            fontWeight: FontWeight.w600,
            fontSize: math.max(12, element.textSize),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 6,
      )
      ..layout(maxWidth: 600)
      ..paint(canvas, element.position);
  }

  static void _drawCommentBubble(ui.Canvas canvas, AnnotationElement element) {
    final textSize = math.max(12, element.textSize).toDouble();
    final textPainter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: textSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: 460);

    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final bubbleRect = Rect.fromLTWH(
      element.position.dx,
      element.position.dy,
      textPainter.width + padding.horizontal,
      textPainter.height + padding.vertical,
    );
    final bubblePaint = Paint()..color = Color(element.color);

    final rrect = RRect.fromRectAndRadius(
      bubbleRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, bubblePaint);

    final tail = Path()
      ..moveTo(bubbleRect.left + 18, bubbleRect.bottom - 4)
      ..lineTo(bubbleRect.left + 8, bubbleRect.bottom + 12)
      ..lineTo(bubbleRect.left + 30, bubbleRect.bottom - 2)
      ..close();
    canvas.drawPath(tail, bubblePaint);

    textPainter.paint(
      canvas,
      Offset(
        bubbleRect.left + padding.left,
        bubbleRect.top + padding.top,
      ),
    );
  }

  static void _drawStepMarker(ui.Canvas canvas, AnnotationElement element) {
    canvas.drawCircle(
      element.position,
      16,
      Paint()..color = Color(element.color),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      element.position - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static Rect _normalizedRect(Offset a, Offset b) {
    return Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }
}
