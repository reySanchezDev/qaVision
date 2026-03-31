import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qavision/core/utils/drawing_helpers.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';

/// Shared rendering helpers for viewer canvas and export composition.
class ViewerCompositionHelper {
  static const Color _kFrameVoidColor = Color(0xFF101010);
  static const Color _kWorkspaceBaseColor = Color(0xFF101010);
  static const Color _kWorkspaceSurfaceColor = Color(0xFF1A1D22);
  static const Color _kWorkspaceBorderColor = Color(0x22FFFFFF);

  /// Paints the complete frame.
  static void paintFrame(
    ui.Canvas canvas,
    FrameState frame, {
    bool forExport = false,
    double contentZoom = 1,
  }) {
    canvas.drawRect(
      Offset.zero & frame.canvasSize,
      Paint()
        ..color = forExport
            ? Color(frame.backgroundColor)
            : _kWorkspaceBaseColor,
    );

    if (!forExport) {
      final workspaceRect = ViewerWorkspaceLayout.resolve(frame.canvasSize);
      canvas
        ..drawRect(
          workspaceRect,
          Paint()..color = _kWorkspaceSurfaceColor,
        )
        ..drawRect(
          workspaceRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _kWorkspaceBorderColor,
        );
    }

    final sorted = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final element in sorted) {
      if (element is ImageFrameComponent) {
        _drawImage(
          canvas,
          element,
          forExport: forExport,
          displayScale: forExport ? 1 : contentZoom,
        );
      } else if (element is AnnotationElement) {
        _drawAnnotation(
          canvas,
          frame.elements,
          element,
          imageZoom: forExport ? 1 : contentZoom,
        );
      }
    }
  }

  /// Returns the visual bounds of any element.
  static Rect elementBounds(
    CanvasElement element, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    if (element is ImageFrameComponent) {
      return imageFrameRect(element, imageZoom: imageZoom);
    }

    if (element is AnnotationElement) {
      return annotationBounds(
        element,
        elements: elements,
        imageZoom: imageZoom,
      );
    }

    return Rect.zero;
  }

  /// Outer frame rect for an image element.
  static Rect imageFrameRect(
    ImageFrameComponent element, {
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    return Rect.fromLTWH(
      element.position.dx,
      element.position.dy,
      element.size.width * scale,
      element.size.height * scale,
    );
  }

  /// Effective inner viewport rect where image content is clipped.
  static Rect imageContentViewportRect(
    ImageFrameComponent element, {
    double imageZoom = 1,
  }) {
    final frameRect = imageFrameRect(element, imageZoom: imageZoom);
    final padding = element.clampedPadding * imageZoom.clamp(0.1, 10.0);
    return Rect.fromLTWH(
      frameRect.left + padding,
      frameRect.top + padding,
      math.max(1, frameRect.width - (padding * 2)),
      math.max(1, frameRect.height - (padding * 2)),
    );
  }

  /// Clamps image content offset so content always intersects the viewport.
  static Offset clampImageContentOffset(
    ImageFrameComponent element,
    Offset offset,
  ) {
    return element.clampContentOffset(offset);
  }

  /// Draw rect for image content inside its frame viewport.
  static Rect imageDrawRect(
    ImageFrameComponent element, {
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final viewport = imageContentViewportRect(element, imageZoom: scale);
    final boundedOffset = element.clampContentOffset(element.contentOffset);
    return Rect.fromLTWH(
      viewport.left + boundedOffset.dx * scale,
      viewport.top + boundedOffset.dy * scale,
      element.contentSize.width * scale,
      element.contentSize.height * scale,
    );
  }

  /// Busca la imagen dueña de una anotación adjunta.
  static ImageFrameComponent? findAttachedImage(
    List<CanvasElement> elements,
    AnnotationElement annotation,
  ) {
    final attachedId = annotation.attachedImageId;
    if (attachedId == null || attachedId.isEmpty) {
      return null;
    }

    for (final element in elements) {
      if (element is ImageFrameComponent && element.id == attachedId) {
        return element;
      }
    }
    return null;
  }

  /// Convierte un punto visible del canvas al espacio interno de la imagen.
  static Offset canvasPointToImageContent(
    ImageFrameComponent image,
    Offset canvasPoint, {
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final drawRect = imageDrawRect(image, imageZoom: scale);
    return Offset(
      (canvasPoint.dx - drawRect.left) / scale,
      (canvasPoint.dy - drawRect.top) / scale,
    );
  }

  /// Convierte un punto del espacio interno de la imagen al canvas visible.
  static Offset imageContentPointToCanvas(
    ImageFrameComponent image,
    Offset imageContentPoint, {
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final drawRect = imageDrawRect(image, imageZoom: scale);
    return Offset(
      drawRect.left + (imageContentPoint.dx * scale),
      drawRect.top + (imageContentPoint.dy * scale),
    );
  }

  /// Proyecta una anotación al canvas visible respetando su espacio geométrico.
  static AnnotationElement projectAnnotation(
    List<CanvasElement> elements,
    AnnotationElement element, {
    double imageZoom = 1,
  }) {
    if (element.coordinateSpace != AnnotationCoordinateSpace.imageContent) {
      return element;
    }

    final attachedImage = findAttachedImage(elements, element);
    if (attachedImage == null) {
      return element.copyWith(
        coordinateSpace: AnnotationCoordinateSpace.workspace,
      );
    }

    return element.copyWith(
      position: imageContentPointToCanvas(
        attachedImage,
        element.position,
        imageZoom: imageZoom,
      ),
      endPosition: element.endPosition == null
          ? null
          : imageContentPointToCanvas(
              attachedImage,
              element.endPosition!,
              imageZoom: imageZoom,
            ),
      points: element.points
          .map(
            (point) => imageContentPointToCanvas(
              attachedImage,
              point,
              imageZoom: imageZoom,
            ),
          )
          .toList(growable: false),
      coordinateSpace: AnnotationCoordinateSpace.workspace,
    );
  }

  /// Returns the visual bounds of an annotation.
  static Rect annotationBounds(
    AnnotationElement element, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final projected = elements == null
        ? element
        : projectAnnotation(
            elements,
            element,
            imageZoom: imageZoom,
          );
    final strokePadding = math.max(6, projected.strokeWidth).toDouble();

    if (projected.type == AnnotationType.stepMarker) {
      return Rect.fromCircle(center: projected.position, radius: 20);
    }

    if (projected.type == AnnotationType.text ||
        projected.type == AnnotationType.commentBubble) {
      final textSize = math.max(12, projected.textSize).toDouble();
      final width = math
          .max(40, projected.text.length * textSize * 0.58)
          .toDouble();
      final height = textSize * 1.55;
      final base = Rect.fromLTWH(
        projected.position.dx,
        projected.position.dy,
        width,
        height,
      );
      return projected.type == AnnotationType.commentBubble
          ? base.inflate(8)
          : base.inflate(4);
    }

    if (projected.type == AnnotationType.pencil &&
        projected.points.isNotEmpty) {
      var minX = projected.points.first.dx;
      var minY = projected.points.first.dy;
      var maxX = projected.points.first.dx;
      var maxY = projected.points.first.dy;
      for (final point in projected.points.skip(1)) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokePadding);
    }

    if (projected.endPosition != null) {
      return _normalizedRect(
        projected.position,
        projected.endPosition!,
      ).inflate(strokePadding);
    }

    return Rect.fromCenter(
      center: projected.position,
      width: 36,
      height: 36,
    );
  }

  static void _drawImage(
    ui.Canvas canvas,
    ImageFrameComponent component, {
    required bool forExport,
    required double displayScale,
  }) {
    final frameRect = imageFrameRect(component, imageZoom: displayScale);
    final contentRect = imageContentViewportRect(
      component,
      imageZoom: displayScale,
    );
    final rawBackgroundOpacity = component.style.backgroundOpacity.clamp(
      0.0,
      1.0,
    );
    final frameBackgroundColor = forExport && rawBackgroundOpacity < 0.01
        ? const Color(0xFFFFFFFF)
        : Color(component.style.backgroundColor).withValues(
            alpha: rawBackgroundOpacity,
          );
    final frameVoidColor = forExport
        ? const Color(0xFF101010)
        : _kFrameVoidColor;
    final frameSurfaceColor = rawBackgroundOpacity > 0.01
        ? frameBackgroundColor
        : frameVoidColor;

    canvas.drawRect(
      frameRect,
      Paint()
        ..style = PaintingStyle.fill
        ..color = frameSurfaceColor,
    );

    // ignore: cascade_invocations, separate calls read clearer around clip setup
    canvas.save();
    // ignore: cascade_invocations, separate calls read clearer around clip setup
    canvas.clipRect(contentRect);

    if (component.image is ui.Image) {
      final uiImage = component.image as ui.Image;
      final drawRect = imageDrawRect(component, imageZoom: displayScale);
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

  static void _drawAnnotation(
    ui.Canvas canvas,
    List<CanvasElement> elements,
    AnnotationElement element, {
    required double imageZoom,
  }) {
    final projected = projectAnnotation(
      elements,
      element,
      imageZoom: imageZoom,
    );
    final strokePaint = Paint()
      ..color = Color(projected.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = projected.strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final normalizedOpacity = projected.opacity.clamp(0.05, 1.0);

    switch (projected.type) {
      case AnnotationType.arrow:
        if (projected.endPosition != null) {
          DrawingHelpers.drawArrow(
            canvas,
            projected.position,
            projected.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.rectangle:
        if (projected.endPosition != null) {
          DrawingHelpers.drawRectangle(
            canvas,
            projected.position,
            projected.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.circle:
        if (projected.endPosition != null) {
          DrawingHelpers.drawCircle(
            canvas,
            projected.position,
            projected.endPosition!,
            strokePaint,
          );
        }
      case AnnotationType.highlighter:
        if (projected.endPosition != null) {
          final rect = _normalizedRect(
            projected.position,
            projected.endPosition!,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..style = PaintingStyle.fill
              ..color = Color(projected.color).withValues(
                alpha: normalizedOpacity,
              ),
          );
        }
      case AnnotationType.pencil:
        if (projected.points.length > 1) {
          final path = Path()
            ..moveTo(projected.points.first.dx, projected.points.first.dy);
          for (final point in projected.points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, strokePaint);
        }
      case AnnotationType.text:
        _drawText(canvas, projected);
      case AnnotationType.commentBubble:
        _drawCommentBubble(canvas, projected);
      case AnnotationType.blur:
        if (projected.endPosition != null) {
          final rect = _normalizedRect(
            projected.position,
            projected.endPosition!,
          );
          _drawPixelateMask(
            canvas,
            rect,
            projected.color,
            normalizedOpacity,
          );
        }
      case AnnotationType.stepMarker:
        _drawStepMarker(canvas, projected);
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
