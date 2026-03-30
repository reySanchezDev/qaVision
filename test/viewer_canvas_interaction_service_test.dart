import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_canvas_interaction_service.dart';

void main() {
  group('ViewerCanvasInteractionService', () {
    const image = ImageFrameComponent(
      id: 'img-1',
      position: Offset(100, 120),
      zIndex: 1,
      path: 'fake.jpg',
      contentSize: Size(300, 220),
      style: ImageFrameStyle(
        backgroundColor: 0,
        backgroundOpacity: 0,
        borderColor: 0,
        borderWidth: 0,
        padding: 0,
      ),
      transform: ImageFrameTransform(
        position: Offset(100, 120),
        size: Size(300, 220),
      ),
    );

    test('detecta handles en los 4 lados y 4 esquinas', () {
      final left = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(100, 230),
      );
      final right = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(400, 230),
      );
      final top = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(240, 120),
      );
      final bottom = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(240, 340),
      );
      final topLeft = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(100, 120),
      );
      final topRight = ViewerCanvasInteractionService.hitTestFrameResizeHandles(
        element: image,
        logicalPoint: const Offset(400, 120),
      );
      final bottomLeft =
          ViewerCanvasInteractionService.hitTestFrameResizeHandles(
            element: image,
            logicalPoint: const Offset(100, 340),
          );
      final bottomRight =
          ViewerCanvasInteractionService.hitTestFrameResizeHandles(
            element: image,
            logicalPoint: const Offset(400, 340),
          );

      expect(left, ViewerImageResizeHandle.left);
      expect(right, ViewerImageResizeHandle.right);
      expect(top, ViewerImageResizeHandle.top);
      expect(bottom, ViewerImageResizeHandle.bottom);
      expect(topLeft, ViewerImageResizeHandle.topLeft);
      expect(topRight, ViewerImageResizeHandle.topRight);
      expect(bottomLeft, ViewerImageResizeHandle.bottomLeft);
      expect(bottomRight, ViewerImageResizeHandle.bottomRight);
    });

    test('resizing por izquierda expande sin mover borde derecho', () {
      final startRect = image.frameRect;
      final resized = ViewerCanvasInteractionService.computeResizedRect(
        startRect: startRect,
        delta: const Offset(-80, 0),
        handle: ViewerImageResizeHandle.left,
        frameSize: const Size(1500, 900),
      );

      expect(resized.left, 20);
      expect(resized.right, 400);
      expect(resized.top, 120);
      expect(resized.bottom, 340);
      expect(resized.width, 380);
      expect(resized.height, 220);
    });

    test('resizing por arriba expande sin mover borde inferior', () {
      final startRect = image.frameRect;
      final resized = ViewerCanvasInteractionService.computeResizedRect(
        startRect: startRect,
        delta: const Offset(0, -60),
        handle: ViewerImageResizeHandle.top,
        frameSize: const Size(1500, 900),
      );

      expect(resized.left, 100);
      expect(resized.right, 400);
      expect(resized.top, 60);
      expect(resized.bottom, 340);
      expect(resized.width, 300);
      expect(resized.height, 280);
    });

    test('resizing por abajo expande sin mover borde superior', () {
      final startRect = image.frameRect;
      final resized = ViewerCanvasInteractionService.computeResizedRect(
        startRect: startRect,
        delta: const Offset(0, 120),
        handle: ViewerImageResizeHandle.bottom,
        frameSize: const Size(1500, 900),
      );

      expect(resized.left, 100);
      expect(resized.right, 400);
      expect(resized.top, 120);
      expect(resized.bottom, 460);
      expect(resized.width, 300);
      expect(resized.height, 340);
    });
  });
}
