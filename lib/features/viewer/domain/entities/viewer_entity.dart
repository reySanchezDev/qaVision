import 'package:flutter/material.dart';

/// Tool type available in the capture editor.
enum AnnotationType {
  /// Arrow line.
  arrow,

  /// Rectangle shape.
  rectangle,

  /// Circle shape.
  circle,

  /// Transparent highlighted rectangle.
  highlighter,

  /// Freehand pencil stroke.
  pencil,

  /// Plain text label.
  text,

  /// Rich multiline text panel.
  richTextPanel,

  /// Bubble callout with text.
  commentBubble,

  /// Blur/mask area.
  blur,

  /// Numbered step marker.
  stepMarker,

  /// Erase selected annotation.
  eraser,

  /// Select and transform elements.
  selection,
}

/// Alineacion disponible para bloques de texto enriquecido.
enum ViewerTextPanelAlignment {
  /// Left aligned text.
  left,

  /// Center aligned text.
  center,

  /// Right aligned text.
  right,

  /// Justified paragraph text.
  justify,
}

/// Espacio geométrico donde vive una anotación.
enum AnnotationCoordinateSpace {
  /// Coordenadas absolutas del workspace.
  workspace,

  /// Coordenadas relativas al viewport interno del frame de imagen.
  imageFrame,

  /// Coordenadas relativas al contenido interno de una imagen.
  imageContent,
}

/// Base class for any drawable element inside the frame canvas.
abstract class CanvasElement {
  /// Creates a [CanvasElement].
  const CanvasElement({
    required this.id,
    required this.position,
    required this.zIndex,
  });

  /// Unique element id.
  final String id;

  /// Top-left position in canvas coordinates.
  final Offset position;

  /// Stack order.
  final int zIndex;
}

/// Vector/text annotation element.
class AnnotationElement extends CanvasElement {
  /// Creates an [AnnotationElement].
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
    this.richTextDelta,
    this.textSize = 18,
    this.opacity = 1.0,
    this.fontFamily = 'Segoe UI',
    this.isBold = false,
    this.isItalic = false,
    this.hasShadow = false,
    this.backgroundColor = 0xF6FFFFFF,
    this.panelBorderColor = 0x61E53935,
    this.panelBorderWidth = 1.2,
    this.panelAlignment = ViewerTextPanelAlignment.justify,
    this.attachedImageId,
    this.coordinateSpace = AnnotationCoordinateSpace.workspace,
  });

  /// Annotation type.
  final AnnotationType type;

  /// ARGB color.
  final int color;

  /// Stroke width.
  final double strokeWidth;

  /// End position used by geometric tools.
  final Offset? endPosition;

  /// Freehand points.
  final List<Offset> points;

  /// Text content for text/bubble/step marker.
  final String text;

  /// Serialized Quill Delta used by rich text panels.
  final String? richTextDelta;

  /// Text size for text-based tools.
  final double textSize;

  /// Opacity used by tools like highlighter.
  final double opacity;

  /// Preferred font family for text-capable elements.
  final String fontFamily;

  /// Whether text should use bold style.
  final bool isBold;

  /// Whether text should use italic style.
  final bool isItalic;

  /// Whether the text panel should render a subtle shadow.
  final bool hasShadow;

  /// Panel background color for rich text blocks.
  final int backgroundColor;

  /// Border color for rich text blocks.
  final int panelBorderColor;

  /// Border width for rich text blocks.
  final double panelBorderWidth;

  /// Paragraph alignment for rich text blocks.
  final ViewerTextPanelAlignment panelAlignment;

  /// Owning image id when annotation was created on top of an image.
  final String? attachedImageId;

  /// Espacio geométrico donde se interpretan sus coordenadas.
  final AnnotationCoordinateSpace coordinateSpace;

  /// Creates a copy with updated fields.
  AnnotationElement copyWith({
    String? id,
    Offset? position,
    int? zIndex,
    AnnotationType? type,
    int? color,
    double? strokeWidth,
    Offset? endPosition,
    bool clearEndPosition = false,
    List<Offset>? points,
    String? text,
    String? richTextDelta,
    bool clearRichTextDelta = false,
    double? textSize,
    double? opacity,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? hasShadow,
    int? backgroundColor,
    int? panelBorderColor,
    double? panelBorderWidth,
    ViewerTextPanelAlignment? panelAlignment,
    String? attachedImageId,
    bool clearAttachedImageId = false,
    AnnotationCoordinateSpace? coordinateSpace,
  }) {
    return AnnotationElement(
      id: id ?? this.id,
      position: position ?? this.position,
      zIndex: zIndex ?? this.zIndex,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      endPosition: clearEndPosition ? null : (endPosition ?? this.endPosition),
      points: points ?? this.points,
      text: text ?? this.text,
      richTextDelta: clearRichTextDelta
          ? null
          : (richTextDelta ?? this.richTextDelta),
      textSize: textSize ?? this.textSize,
      opacity: opacity ?? this.opacity,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      hasShadow: hasShadow ?? this.hasShadow,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      panelBorderColor: panelBorderColor ?? this.panelBorderColor,
      panelBorderWidth: panelBorderWidth ?? this.panelBorderWidth,
      panelAlignment: panelAlignment ?? this.panelAlignment,
      attachedImageId: clearAttachedImageId
          ? null
          : (attachedImageId ?? this.attachedImageId),
      coordinateSpace: coordinateSpace ?? this.coordinateSpace,
    );
  }
}

/// Full frame state for the composition canvas.
class FrameState {
  /// Creates a [FrameState].
  const FrameState({
    this.canvasSize = const Size(1920, 1080),
    this.elements = const [],
    this.backgroundColor = 0xFF111111,
  });

  /// Canvas frame size.
  final Size canvasSize;

  /// Elements currently placed on frame.
  final List<CanvasElement> elements;

  /// Background color ARGB.
  final int backgroundColor;

  /// Creates a copy with updated fields.
  FrameState copyWith({
    Size? canvasSize,
    List<CanvasElement>? elements,
    int? backgroundColor,
  }) {
    return FrameState(
      canvasSize: canvasSize ?? this.canvasSize,
      elements: elements ?? this.elements,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
