import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

/// Resize handle for image elements.
enum ViewerImageResizeHandle {
  /// No active handle.
  none,

  /// Left edge.
  left,

  /// Right edge.
  right,

  /// Top edge.
  top,

  /// Bottom edge.
  bottom,

  /// Top-left corner.
  topLeft,

  /// Top-right corner.
  topRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom-right corner.
  bottomRight,
}

/// Hit-test result for image resize operations.
class ViewerImageResizeHit {
  /// Creates [ViewerImageResizeHit].
  const ViewerImageResizeHit({
    required this.element,
    required this.handle,
  });

  /// Target image element.
  final ImageFrameComponent element;

  /// Detected edge/corner handle.
  final ViewerImageResizeHandle handle;
}

/// Canvas interaction and hit-test helpers for viewer canvas.
class ViewerCanvasInteractionService {
  static const double _elementHitInflate = 8;
  static const double _imageResizeEdgeHitSlop = 22;
  static const double _imageResizeCornerHitSlop = 30;

  /// Finds selected element by id from [state].
  static CanvasElement? selectedElement(ViewerState state) {
    final id = state.selectedElementId;
    if (id == null) return null;
    for (final element in state.frame.elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  /// Z-ordered hit-test that returns top-most element under [point].
  static CanvasElement? hitTest(
    FrameState frame,
    Offset point, {
    required double zoom,
  }) {
    final logicalPoint = toLogicalPoint(
      point: point,
      frameSize: frame.canvasSize,
      zoom: zoom,
    );
    final sorted = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final element in sorted) {
      if (element is ImageFrameComponent) {
        if (element.frameRect.contains(logicalPoint)) {
          return element;
        }
      } else {
        final bounds = ViewerCompositionHelper.elementBounds(
          element,
        ).inflate(_elementHitInflate);
        if (bounds.contains(logicalPoint)) {
          return element;
        }
      }
    }
    return null;
  }

  /// Returns true when [point] is on a resize handle for [element].
  static bool isOnResizeHandle(CanvasElement element, Offset point) {
    if (element is ImageFrameComponent) {
      final handle = hitTestFrameResizeHandles(
        logicalPoint: point,
        element: element,
      );
      return handle != null && handle != ViewerImageResizeHandle.none;
    }
    final bounds = ViewerCompositionHelper.elementBounds(element);
    final handle = Rect.fromCenter(
      center: bounds.bottomRight,
      width: 24,
      height: 24,
    );
    return handle.contains(point);
  }

  /// Detects which image resize handle is under [logicalPoint].
  static ViewerImageResizeHandle? hitTestFrameResizeHandles({
    required Offset logicalPoint,
    required ImageFrameComponent element,
  }) {
    final bounds = element.frameRect;
    const edge = _imageResizeEdgeHitSlop;
    const corner = _imageResizeCornerHitSlop;

    final nearLeft = (logicalPoint.dx - bounds.left).abs() <= edge;
    final nearRight = (logicalPoint.dx - bounds.right).abs() <= edge;
    final nearTop = (logicalPoint.dy - bounds.top).abs() <= edge;
    final nearBottom = (logicalPoint.dy - bounds.bottom).abs() <= edge;

    final nearTopLeft =
        nearLeft &&
        nearTop &&
        (logicalPoint - bounds.topLeft).distance <= corner;
    final nearTopRight =
        nearRight &&
        nearTop &&
        (logicalPoint - bounds.topRight).distance <= corner;
    final nearBottomLeft =
        nearLeft &&
        nearBottom &&
        (logicalPoint - bounds.bottomLeft).distance <= corner;
    final nearBottomRight =
        nearRight &&
        nearBottom &&
        (logicalPoint - bounds.bottomRight).distance <= corner;

    if (nearTopLeft) return ViewerImageResizeHandle.topLeft;
    if (nearTopRight) return ViewerImageResizeHandle.topRight;
    if (nearBottomLeft) return ViewerImageResizeHandle.bottomLeft;
    if (nearBottomRight) return ViewerImageResizeHandle.bottomRight;

    final inVerticalRange =
        logicalPoint.dy >= bounds.top - edge &&
        logicalPoint.dy <= bounds.bottom + edge;
    final inHorizontalRange =
        logicalPoint.dx >= bounds.left - edge &&
        logicalPoint.dx <= bounds.right + edge;

    if (nearLeft && inVerticalRange) return ViewerImageResizeHandle.left;
    if (nearRight && inVerticalRange) return ViewerImageResizeHandle.right;
    if (nearTop && inHorizontalRange) return ViewerImageResizeHandle.top;
    if (nearBottom && inHorizontalRange) return ViewerImageResizeHandle.bottom;
    return ViewerImageResizeHandle.none;
  }

  /// Finds top-most image resize hit under [logicalPoint].
  static ViewerImageResizeHit? hitTopImageResizeHandle(
    FrameState frame,
    Offset logicalPoint,
  ) {
    final images = frame.elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final image in images) {
      final handle = hitTestFrameResizeHandles(
        logicalPoint: logicalPoint,
        element: image,
      );
      if (handle != null && handle != ViewerImageResizeHandle.none) {
        return ViewerImageResizeHit(
          element: image,
          handle: handle,
        );
      }
    }
    return null;
  }

  /// Finds top-most image whose frame contains [logicalPoint].
  static ImageFrameComponent? hitTopImageFrame(
    FrameState frame,
    Offset logicalPoint,
  ) {
    final images = frame.elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final image in images) {
      if (image.frameRect.contains(logicalPoint)) {
        return image;
      }
    }
    return null;
  }

  /// Computes resized rectangle for an image element.
  static Rect computeResizedRect({
    required Rect startRect,
    required Offset delta,
    required ViewerImageResizeHandle handle,
    required Size frameSize,
  }) {
    var left = startRect.left;
    var top = startRect.top;
    var right = startRect.right;
    var bottom = startRect.bottom;
    const minSize = 8.0;

    switch (handle) {
      case ViewerImageResizeHandle.left:
        left += delta.dx;
      case ViewerImageResizeHandle.right:
        right += delta.dx;
      case ViewerImageResizeHandle.top:
        top += delta.dy;
      case ViewerImageResizeHandle.bottom:
        bottom += delta.dy;
      case ViewerImageResizeHandle.topLeft:
        left += delta.dx;
        top += delta.dy;
      case ViewerImageResizeHandle.topRight:
        right += delta.dx;
        top += delta.dy;
      case ViewerImageResizeHandle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case ViewerImageResizeHandle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case ViewerImageResizeHandle.none:
        return startRect;
    }

    final affectsLeft =
        handle == ViewerImageResizeHandle.left ||
        handle == ViewerImageResizeHandle.topLeft ||
        handle == ViewerImageResizeHandle.bottomLeft;

    final affectsTop =
        handle == ViewerImageResizeHandle.top ||
        handle == ViewerImageResizeHandle.topLeft ||
        handle == ViewerImageResizeHandle.topRight;

    // Nota: se elimino la logica de compensacion automatica que empujaba
    // el lado opuesto al tocar un borde del canvas.
    // Esto causaba una sensacion de inversion de controles.

    if (right - left < minSize) {
      if (affectsLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (affectsTop) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    left = left.clamp(-20000, frameSize.width - minSize);
    top = top.clamp(-20000, frameSize.height - minSize);
    right = right.clamp(left + minSize, 20000);
    bottom = bottom.clamp(top + minSize, 20000);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Converts local screen coordinates to logical canvas coordinates.
  static Offset toLogicalPoint({
    required Offset point,
    required Size frameSize,
    required double zoom,
  }) {
    if ((zoom - 1).abs() <= 0.001) {
      return point;
    }
    final center = frameSize.center(Offset.zero);
    return Offset(
      ((point.dx - center.dx) / zoom) + center.dx,
      ((point.dy - center.dy) / zoom) + center.dy,
    );
  }

  /// Computes free resize size for non-image annotations.
  static Size computeGenericResizeSize({
    required Size startSize,
    required Offset delta,
  }) {
    return Size(
      (startSize.width + delta.dx).clamp(8, 12000).toDouble(),
      (startSize.height + delta.dy).clamp(8, 12000).toDouble(),
    );
  }

  /// Returns bounds used for selection outline around [element].
  static Rect selectionBounds(CanvasElement element) {
    return ViewerCompositionHelper.elementBounds(element).inflate(4);
  }

  /// True when [point] falls inside image frame bounds.
  static bool isInsideImageFrame(ImageFrameComponent element, Offset point) {
    return element.frameRect.contains(point);
  }
}
