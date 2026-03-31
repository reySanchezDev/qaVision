import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_viewport_transform_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

void main() {
  group('ViewerViewportTransformService', () {
    test('convierte ida y vuelta entre display y logical', () {
      const zoom = 1.75;
      const displayPoint = Offset(350, 210);
      const displaySize = Size(280, 140);

      final logicalPoint = ViewerViewportTransformService.toLogicalPoint(
        displayPoint: displayPoint,
        zoom: zoom,
      );
      final roundtripPoint = ViewerViewportTransformService.toDisplayPoint(
        logicalPoint: logicalPoint,
        zoom: zoom,
      );

      final logicalSize = ViewerViewportTransformService.toLogicalSize(
        displaySize: displaySize,
        zoom: zoom,
      );
      final roundtripSize = ViewerViewportTransformService.toDisplaySize(
        logicalSize: logicalSize,
        zoom: zoom,
      );

      expect(roundtripPoint.dx, closeTo(displayPoint.dx, 0.001));
      expect(roundtripPoint.dy, closeTo(displayPoint.dy, 0.001));
      expect(roundtripSize.width, closeTo(displaySize.width, 0.001));
      expect(roundtripSize.height, closeTo(displaySize.height, 0.001));
    });

    test('convierte rectangulos ida y vuelta entre display y logical', () {
      const rect = Rect.fromLTWH(100, 80, 360, 220);
      const zoom = 0.66;

      final logicalRect = ViewerViewportTransformService.toLogicalRect(
        displayRect: rect,
        zoom: zoom,
      );
      final roundtripRect = ViewerViewportTransformService.toDisplayRect(
        logicalRect: logicalRect,
        zoom: zoom,
      );

      expect(roundtripRect.left, closeTo(rect.left, 0.001));
      expect(roundtripRect.top, closeTo(rect.top, 0.001));
      expect(roundtripRect.width, closeTo(rect.width, 0.001));
      expect(roundtripRect.height, closeTo(rect.height, 0.001));
    });

    test('resuelve fit zoom respetando padding y max zoom', () {
      final fitZoom = ViewerViewportTransformService.resolveFitZoom(
        viewportSize: const Size(1400, 900),
        imageSize: const Size(900, 600),
        maxZoom: 1.4,
      );

      expect(fitZoom, lessThanOrEqualTo(1.4));
      expect(
        fitZoom,
        greaterThan(ViewerViewportTransformService.defaultMinZoom),
      );
    });

    test('resuelve max zoom a partir de canvas e imagen', () {
      final maxZoom = ViewerViewportTransformService.resolveMaxZoom(
        canvasSize: const Size(1200, 900),
        imageSize: const Size(600, 300),
      );

      expect(maxZoom, closeTo(2.0, 0.001));
    });

    test(
      'mantiene la posicion raiz estable y proyecta hijos relativos al padre',
      () {
        const style = ImageFrameStyle(
          backgroundColor: 0xFFFFFFFF,
          backgroundOpacity: 1,
          borderColor: 0xFF000000,
          borderWidth: 0,
          padding: 20,
        );
        const root = ImageFrameComponent(
          id: 'root',
          position: Offset(120, 80),
          zIndex: 0,
          path: 'root.jpg',
          contentSize: Size(700, 420),
          style: style,
          transform: ImageFrameTransform(
            position: Offset(120, 80),
            size: Size(700, 420),
          ),
        );
        const child = ImageFrameComponent(
          id: 'child',
          position: Offset(440, 180),
          zIndex: 1,
          path: 'child.jpg',
          contentSize: Size(180, 120),
          style: style,
          transform: ImageFrameTransform(
            position: Offset(440, 180),
            size: Size(180, 120),
          ),
          parentImageId: 'root',
        );
        const zoom = 0.5;
        const elements = [root, child];

        final projectedRoot = ViewerCompositionHelper.imageFrameRect(
          root,
          elements: elements,
          imageZoom: zoom,
        );
        final projectedChild = ViewerCompositionHelper.imageFrameRect(
          child,
          elements: elements,
          imageZoom: zoom,
        );

        expect(projectedRoot.topLeft, const Offset(120, 80));
        expect(projectedRoot.size, const Size(350, 210));

        final parentViewport = ViewerCompositionHelper.imageContentViewportRect(
          root,
          elements: elements,
          imageZoom: zoom,
        );
        final expectedChildTopLeft = Offset(
          parentViewport.left +
              ((child.position.dx - root.contentViewportRect.left) * zoom),
          parentViewport.top +
              ((child.position.dy - root.contentViewportRect.top) * zoom),
        );
        expect(
          projectedChild.topLeft.dx,
          closeTo(expectedChildTopLeft.dx, 0.001),
        );
        expect(
          projectedChild.topLeft.dy,
          closeTo(expectedChildTopLeft.dy, 0.001),
        );
      },
    );
  });
}
