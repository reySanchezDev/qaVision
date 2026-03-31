import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

void main() {
  group('Viewer annotation projection', () {
    test('convierte ida y vuelta entre canvas e imagen respetando zoom', () {
      const image = ImageFrameComponent(
        id: 'img-1',
        position: Offset(120, 80),
        zIndex: 0,
        path: 'fake.jpg',
        contentSize: Size(240, 160),
        style: ImageFrameStyle(
          backgroundColor: 0xFFFFFFFF,
          backgroundOpacity: 1,
          borderColor: 0x00000000,
          borderWidth: 0,
          padding: 12,
        ),
        transform: ImageFrameTransform(
          position: Offset(120, 80),
          size: Size(300, 220),
          contentOffset: Offset(-30, -20),
        ),
      );

      const canvasPoint = Offset(210, 150);
      final imagePoint = ViewerCompositionHelper.canvasPointToImageContent(
        image,
        canvasPoint,
        imageZoom: 0.75,
      );
      final roundTrip = ViewerCompositionHelper.imageContentPointToCanvas(
        image,
        imagePoint,
        imageZoom: 0.75,
      );

      expect(roundTrip.dx, closeTo(canvasPoint.dx, 0.001));
      expect(roundTrip.dy, closeTo(canvasPoint.dy, 0.001));
    });

    test(
      'proyecta una anotacion adjunta al mismo punto con distintos zooms',
      () {
      const image = ImageFrameComponent(
        id: 'img-1',
        position: Offset(100, 100),
        zIndex: 0,
        path: 'fake.jpg',
        contentSize: Size(240, 160),
        style: ImageFrameStyle(
          backgroundColor: 0xFFFFFFFF,
          backgroundOpacity: 1,
          borderColor: 0x00000000,
          borderWidth: 0,
          padding: 0,
        ),
        transform: ImageFrameTransform(
          position: Offset(100, 100),
          size: Size(240, 160),
        ),
      );

      const annotation = AnnotationElement(
        id: 'ann-1',
        type: AnnotationType.arrow,
        color: 0xFFE53935,
        strokeWidth: 4,
        position: Offset(20, 30),
        endPosition: Offset(140, 60),
        attachedImageId: 'img-1',
        coordinateSpace: AnnotationCoordinateSpace.imageContent,
        zIndex: 1,
      );

      final elements = <CanvasElement>[image, annotation];
      final projectedAtHalf = ViewerCompositionHelper.projectAnnotation(
        elements,
        annotation,
        imageZoom: 0.5,
      );
      final projectedAtFull = ViewerCompositionHelper.projectAnnotation(
        elements,
        annotation,
      );

      expect(projectedAtHalf.position, const Offset(110, 115));
      expect(projectedAtHalf.endPosition, const Offset(170, 130));
      expect(projectedAtFull.position, const Offset(120, 130));
      expect(projectedAtFull.endPosition, const Offset(240, 160));
    });
  });
}
