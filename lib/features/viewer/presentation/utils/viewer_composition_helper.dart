import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qavision/core/utils/drawing_helpers.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
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
    String? hiddenElementId,
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

    final document = ViewerDocumentGraphService.build(frame);
    final sorted = document.orderedElements();

    for (final element in sorted) {
      if (!forExport &&
          hiddenElementId != null &&
          hiddenElementId.isNotEmpty &&
          element.id == hiddenElementId) {
        continue;
      }
      if (element is ImageFrameComponent) {
        _drawImage(
          canvas,
          frame.elements,
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
      return imageFrameRect(
        element,
        elements: elements,
        imageZoom: imageZoom,
      );
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
  ///
  /// Regla importante del visor:
  /// - una imagen raiz conserva su top-left logico dentro del workspace
  /// - una subimagen se proyecta relativa al viewport interno del padre
  ///
  /// Esto evita dos regresiones clave:
  /// - que el workspace parezca "encogerse" cuando baja el zoom
  /// - que las subimagenes se despeguen visualmente de su frame padre
  static Rect imageFrameRect(
    ImageFrameComponent element, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final parentId = element.parentImageId;
    if (elements != null && parentId != null && parentId.isNotEmpty) {
      final parent = elements.whereType<ImageFrameComponent>().firstWhere(
        (candidate) => candidate.id == parentId,
        orElse: () => element,
      );
      if (parent.id != element.id) {
        final parentViewport = imageContentViewportRect(
          parent,
          elements: elements,
          imageZoom: scale,
        );
        final logicalParentViewport = parent.contentViewportRect;
        final localOffset = element.position - logicalParentViewport.topLeft;
        return Rect.fromLTWH(
          parentViewport.left + (localOffset.dx * scale),
          parentViewport.top + (localOffset.dy * scale),
          element.size.width * scale,
          element.size.height * scale,
        );
      }
    }
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
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final frameRect = imageFrameRect(
      element,
      elements: elements,
      imageZoom: imageZoom,
    );
    final padding = element.clampedPadding * imageZoom.clamp(0.1, 10.0);
    return Rect.fromLTWH(
      frameRect.left + padding,
      frameRect.top + padding,
      math.max(1, frameRect.width - (padding * 2)),
      math.max(1, frameRect.height - (padding * 2)),
    );
  }

  /// Convierte el top-left visible de un frame a su posicion logica.
  ///
  /// Para frames raiz la conversion es identidad. Para subimagenes se revierte
  /// la proyeccion relativa al viewport del padre, de modo que drag/resize en
  /// pantalla vuelvan a almacenarse en coordenadas logicas consistentes.
  static Offset logicalFrameTopLeftFromDisplayTopLeft({
    required Offset displayTopLeft,
    required String? parentImageId,
    required List<CanvasElement> elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    if (parentImageId == null || parentImageId.isEmpty) {
      return displayTopLeft;
    }

    ImageFrameComponent? parent;
    for (final candidate in elements.whereType<ImageFrameComponent>()) {
      if (candidate.id == parentImageId) {
        parent = candidate;
        break;
      }
    }
    if (parent == null) {
      return displayTopLeft;
    }
    final projectedParentViewport = imageContentViewportRect(
      parent,
      elements: elements,
      imageZoom: scale,
    );
    final logicalParentViewport = parent.contentViewportRect;
    final projectedOffset = displayTopLeft - projectedParentViewport.topLeft;
    return Offset(
      logicalParentViewport.left + (projectedOffset.dx / scale),
      logicalParentViewport.top + (projectedOffset.dy / scale),
    );
  }

  /// Convierte un rectangulo visible de un frame a su rectangulo logico.
  static Rect logicalFrameRectFromDisplayRect({
    required Rect displayRect,
    required String? parentImageId,
    required List<CanvasElement> elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final logicalTopLeft = logicalFrameTopLeftFromDisplayTopLeft(
      displayTopLeft: displayRect.topLeft,
      parentImageId: parentImageId,
      elements: elements,
      imageZoom: scale,
    );
    return Rect.fromLTWH(
      logicalTopLeft.dx,
      logicalTopLeft.dy,
      displayRect.width / scale,
      displayRect.height / scale,
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
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final viewport = imageContentViewportRect(
      element,
      elements: elements,
      imageZoom: scale,
    );
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
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final drawRect = imageDrawRect(
      image,
      elements: elements,
      imageZoom: scale,
    );
    return Offset(
      (canvasPoint.dx - drawRect.left) / scale,
      (canvasPoint.dy - drawRect.top) / scale,
    );
  }

  /// Convierte un punto visible del canvas al espacio interno del viewport del
  /// frame.
  static Offset canvasPointToImageFrame(
    ImageFrameComponent image,
    Offset canvasPoint, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final viewport = imageContentViewportRect(
      image,
      elements: elements,
      imageZoom: scale,
    );
    return Offset(
      (canvasPoint.dx - viewport.left) / scale,
      (canvasPoint.dy - viewport.top) / scale,
    );
  }

  /// Convierte un punto del espacio interno de la imagen al canvas visible.
  static Offset imageContentPointToCanvas(
    ImageFrameComponent image,
    Offset imageContentPoint, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final drawRect = imageDrawRect(
      image,
      elements: elements,
      imageZoom: scale,
    );
    return Offset(
      drawRect.left + (imageContentPoint.dx * scale),
      drawRect.top + (imageContentPoint.dy * scale),
    );
  }

  /// Convierte un punto del viewport logico del frame al canvas visible.
  static Offset imageFramePointToCanvas(
    ImageFrameComponent image,
    Offset framePoint, {
    List<CanvasElement>? elements,
    double imageZoom = 1,
  }) {
    final scale = imageZoom.clamp(0.1, 10.0);
    final viewport = imageContentViewportRect(
      image,
      elements: elements,
      imageZoom: scale,
    );
    return Offset(
      viewport.left + (framePoint.dx * scale),
      viewport.top + (framePoint.dy * scale),
    );
  }

  /// Proyecta una anotación al canvas visible respetando su espacio geométrico.
  static AnnotationElement projectAnnotation(
    List<CanvasElement> elements,
    AnnotationElement element, {
    double imageZoom = 1,
  }) {
    if (element.type == AnnotationType.richTextPanel &&
        element.coordinateSpace == AnnotationCoordinateSpace.workspace) {
      final baseRect = element.endPosition == null
          ? Rect.fromLTWH(element.position.dx, element.position.dy, 360, 220)
          : _normalizedRect(element.position, element.endPosition!);
      final scale = imageZoom.clamp(0.1, 10.0);
      final scaledRect = Rect.fromLTWH(
        baseRect.left,
        baseRect.top,
        baseRect.width * scale,
        baseRect.height * scale,
      );
      return element.copyWith(
        position: scaledRect.topLeft,
        endPosition: scaledRect.bottomRight,
      );
    }

    if (element.coordinateSpace == AnnotationCoordinateSpace.imageFrame) {
      final attachedImage = findAttachedImage(elements, element);
      if (attachedImage == null) {
        return element.copyWith(
          coordinateSpace: AnnotationCoordinateSpace.workspace,
        );
      }

      return element.copyWith(
        position: imageFramePointToCanvas(
          attachedImage,
          element.position,
          elements: elements,
          imageZoom: imageZoom,
        ),
        endPosition: element.endPosition == null
            ? null
            : imageFramePointToCanvas(
                attachedImage,
                element.endPosition!,
                elements: elements,
                imageZoom: imageZoom,
              ),
        points: element.points
            .map(
              (point) => imageFramePointToCanvas(
                attachedImage,
                point,
                elements: elements,
                imageZoom: imageZoom,
              ),
            )
            .toList(growable: false),
        coordinateSpace: AnnotationCoordinateSpace.workspace,
      );
    }

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
        elements: elements,
        imageZoom: imageZoom,
      ),
      endPosition: element.endPosition == null
          ? null
          : imageContentPointToCanvas(
              attachedImage,
              element.endPosition!,
              elements: elements,
              imageZoom: imageZoom,
            ),
      points: element.points
          .map(
            (point) => imageContentPointToCanvas(
              attachedImage,
              point,
              elements: elements,
              imageZoom: imageZoom,
            ),
          )
          .toList(growable: false),
      coordinateSpace: AnnotationCoordinateSpace.workspace,
    );
  }

  /// Rectangulo visible del panel enriquecido.
  ///
  /// Para paneles del workspace el zoom afecta el tamano visible del cuadro
  /// sin alterar su top-left logico. Para paneles adjuntos a una imagen,
  /// la proyeccion de `projectAnnotation` ya incorpora la escala correcta.
  static Rect richTextPanelRect(
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
    final baseRect = projected.endPosition == null
        ? Rect.fromLTWH(projected.position.dx, projected.position.dy, 360, 220)
        : _normalizedRect(projected.position, projected.endPosition!);
    return baseRect;
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

    if (projected.type == AnnotationType.richTextPanel) {
      final rect = richTextPanelRect(
        element,
        elements: elements,
        imageZoom: imageZoom,
      );
      return rect.inflate(4);
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
    List<CanvasElement> elements,
    ImageFrameComponent component, {
    required bool forExport,
    required double displayScale,
  }) {
    final frameRect = imageFrameRect(
      component,
      elements: elements,
      imageZoom: displayScale,
    );
    final contentRect = imageContentViewportRect(
      component,
      elements: elements,
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
      final drawRect = imageDrawRect(
        component,
        elements: elements,
        imageZoom: displayScale,
      );
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
      case AnnotationType.richTextPanel:
        _drawRichTextPanel(
          canvas,
          source: element,
          projected: projected,
          imageZoom: imageZoom,
        );
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

  static void _drawRichTextPanel(
    ui.Canvas canvas, {
    required AnnotationElement source,
    required AnnotationElement projected,
    required double imageZoom,
  }) {
    final rect = projected.endPosition == null
        ? Rect.fromLTWH(projected.position.dx, projected.position.dy, 360, 220)
        : _normalizedRect(projected.position, projected.endPosition!);
    final logicalRect = source.endPosition == null
        ? Rect.fromLTWH(source.position.dx, source.position.dy, 360, 220)
        : _normalizedRect(source.position, source.endPosition!);
    final panelScale = logicalRect.width <= 0.001
        ? 1.0
        : (rect.width / logicalRect.width).clamp(0.25, 4.0);
    final borderRadius = (18 * panelScale).clamp(8, 24).toDouble();
    final panelPadding = EdgeInsets.fromLTRB(
      (18 * panelScale).clamp(8, 30).toDouble(),
      (16 * panelScale).clamp(8, 24).toDouble(),
      (18 * panelScale).clamp(8, 30).toDouble(),
      (18 * panelScale).clamp(8, 30).toDouble(),
    );
    final panelColor = Color(projected.backgroundColor);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    if (projected.hasShadow && panelColor.a > 0) {
      canvas.drawRRect(
        rrect.shift(Offset(0, (10 * panelScale).clamp(5, 12).toDouble())),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
    }

    if (panelColor.a > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = panelColor,
      );
    }

    final borderWidth =
        (projected.panelBorderWidth * panelScale).clamp(0, 8).toDouble();
    if (borderWidth > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = Color(projected.panelBorderColor),
      );
    }

    final contentRect = Rect.fromLTWH(
      rect.left + panelPadding.left,
      rect.top + panelPadding.top,
      math.max(24, rect.width - panelPadding.horizontal),
      math.max(24, rect.height - panelPadding.vertical),
    );

    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          contentRect.inflate(6),
          Radius.circular((14 * panelScale).clamp(8, 18).toDouble()),
        ),
      );

    final paragraphs = _buildRichTextParagraphs(projected, panelScale);
    var top = contentRect.top;
    for (final paragraph in paragraphs) {
      if (top >= contentRect.bottom) {
        break;
      }
      final textPainter = TextPainter(
        text: TextSpan(children: paragraph.spans),
        textDirection: TextDirection.ltr,
        textAlign: _textAlignForPanel(paragraph.alignment),
      )..layout(
          minWidth: contentRect.width,
          maxWidth: contentRect.width,
        );

      textPainter.paint(canvas, Offset(contentRect.left, top));
      top += textPainter.height;
    }
    canvas.restore();
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


  static List<_RichTextParagraph> _buildRichTextParagraphs(
    AnnotationElement element,
    double panelScale,
  ) {
    final baseStyle = TextStyle(
      color: Color(element.color),
      fontSize: math.max(8, element.textSize * panelScale),
      fontFamily: element.fontFamily,
      fontWeight: element.isBold ? FontWeight.w700 : FontWeight.w500,
      fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
      height: 1.35,
    );
    final operations = _decodeRichTextOperations(
      element.richTextDelta,
      fallbackText: element.text,
    );

    final paragraphs = <_RichTextParagraph>[];
    final currentSpans = <InlineSpan>[];

    void pushParagraph(ViewerTextPanelAlignment alignment) {
      paragraphs.add(
        _RichTextParagraph(
          alignment: alignment,
          spans: currentSpans.isEmpty
              ? <InlineSpan>[TextSpan(text: ' ', style: baseStyle)]
              : List<InlineSpan>.from(currentSpans),
        ),
      );
      currentSpans.clear();
    }

    for (final operation in operations) {
      final insert = operation['insert'];
      if (insert is! String || insert.isEmpty) {
        continue;
      }
      final attributes = operation['attributes'];
      final attributeMap = attributes is Map<String, dynamic>
          ? attributes
          : null;
      final paragraphAlignment = _panelAlignmentFromDeltaAttributes(
        attributeMap,
      );
      final segments = insert.replaceAll('\r\n', '\n').split('\n');
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (segment.isNotEmpty) {
          currentSpans.add(
            TextSpan(
              text: segment,
              style: baseStyle.merge(
                _styleFromRichTextAttributes(
                  attributeMap,
                  fallbackColor: Color(element.color),
                ),
              ),
            ),
          );
        }
        final isLineBreak = i < segments.length - 1;
        if (isLineBreak) {
          pushParagraph(paragraphAlignment ?? element.panelAlignment);
        }
      }
    }

    if (currentSpans.isNotEmpty || paragraphs.isEmpty) {
      pushParagraph(element.panelAlignment);
    }

    return paragraphs;
  }

  static List<Map<String, dynamic>> _decodeRichTextOperations(
    String? serialized, {
    required String fallbackText,
  }) {
    if (serialized != null && serialized.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(serialized);
        if (decoded is List) {
          return decoded
              .whereType<Map<dynamic, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList(growable: false);
        }
      } on FormatException {
        // Fallback below.
      }
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': fallbackText.trimRight().isEmpty
            ? '\n'
            : '${fallbackText.trimRight()}\n',
      },
    ];
  }

  static TextStyle _styleFromRichTextAttributes(
    Map<String, dynamic>? attributes, {
    required Color fallbackColor,
  }) {
    if (attributes == null || attributes.isEmpty) {
      return const TextStyle();
    }

    return TextStyle(
      fontWeight: attributes['bold'] == true ? FontWeight.w700 : null,
      fontStyle: attributes['italic'] == true ? FontStyle.italic : null,
      backgroundColor: _parseDeltaColor(attributes['background']),
      color: _parseDeltaColor(attributes['color']) ?? fallbackColor,
      fontFamily: attributes['font'] as String?,
    );
  }

  static Color? _parseDeltaColor(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final normalized = raw.trim().replaceFirst('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return null;
  }

  static TextAlign _textAlignForPanel(ViewerTextPanelAlignment alignment) {
    return switch (alignment) {
      ViewerTextPanelAlignment.left => TextAlign.left,
      ViewerTextPanelAlignment.center => TextAlign.center,
      ViewerTextPanelAlignment.right => TextAlign.right,
      ViewerTextPanelAlignment.justify => TextAlign.justify,
    };
  }

  static ViewerTextPanelAlignment? _panelAlignmentFromDeltaAttributes(
    Map<String, dynamic>? attributes,
  ) {
    final raw = attributes?['align'];
    if (raw is! String) {
      return null;
    }
    return switch (raw) {
      'left' => ViewerTextPanelAlignment.left,
      'center' => ViewerTextPanelAlignment.center,
      'right' => ViewerTextPanelAlignment.right,
      'justify' => ViewerTextPanelAlignment.justify,
      _ => null,
    };
  }
}

class _RichTextParagraph {
  const _RichTextParagraph({
    required this.alignment,
    required this.spans,
  });

  final ViewerTextPanelAlignment alignment;
  final List<InlineSpan> spans;
}
