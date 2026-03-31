import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_document.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';

ImageFrameComponent _image({
  required String id,
  required Offset position,
  required Size size,
  int zIndex = 0,
  String? parentImageId,
}) {
  return ImageFrameComponent(
    id: id,
    position: position,
    zIndex: zIndex,
    path: '$id.jpg',
    contentSize: size,
    style: const ImageFrameStyle(
      backgroundColor: 0xFFFFFFFF,
      backgroundOpacity: 1,
      borderColor: 0x00000000,
      borderWidth: 0,
      padding: 0,
    ),
    transform: ImageFrameTransform(
      position: position,
      size: size,
    ),
    parentImageId: parentImageId,
  );
}

void main() {
  group('ViewerDocumentGraphService', () {
    test('construye jerarquia padre-hijo para imagenes y anotaciones', () {
      final root = _image(
        id: 'root',
        position: const Offset(100, 100),
        size: const Size(300, 200),
      );
      final child = _image(
        id: 'child',
        position: const Offset(150, 130),
        size: const Size(120, 90),
        zIndex: 1,
        parentImageId: 'root',
      );
      const annotation = AnnotationElement(
        id: 'ann',
        position: Offset(20, 20),
        zIndex: 2,
        type: AnnotationType.arrow,
        color: 0xFFE53935,
        strokeWidth: 4,
        endPosition: Offset(90, 80),
        attachedImageId: 'root',
        coordinateSpace: AnnotationCoordinateSpace.imageContent,
      );

      final document = ViewerDocumentGraphService.build(
        FrameState(elements: [root, child, annotation]),
      );

      expect(
        document.nodeById('root')?.kind,
        ViewerDocumentNodeKind.imageFrame,
      );
      expect(
        document.nodeById('root')?.childIds,
        containsAll(['child', 'ann']),
      );
      expect(
        ViewerDocumentGraphService.descendantImageIds(document, 'root'),
        contains('child'),
      );
    });

    test('hit test respeta orden superior del documento', () {
      final back = _image(
        id: 'back',
        position: const Offset(50, 50),
        size: const Size(200, 160),
      );
      final front = _image(
        id: 'front',
        position: const Offset(100, 80),
        size: const Size(200, 160),
        zIndex: 3,
      );

      final document = ViewerDocumentGraphService.build(
        FrameState(elements: [back, front]),
      );
      final hit = ViewerDocumentGraphService.hitTest(
        document,
        const Offset(140, 120),
      );

      expect(hit?.id, 'front');
    });

    test('export rect enfocado incluye subarbol y anotaciones adjuntas', () {
      final root = _image(
        id: 'root',
        position: const Offset(100, 100),
        size: const Size(300, 200),
      );
      final child = _image(
        id: 'child',
        position: const Offset(330, 220),
        size: const Size(80, 60),
        zIndex: 1,
        parentImageId: 'root',
      );
      const annotation = AnnotationElement(
        id: 'ann',
        position: Offset(10, 10),
        zIndex: 2,
        type: AnnotationType.arrow,
        color: 0xFFE53935,
        strokeWidth: 4,
        endPosition: Offset(360, 230),
        attachedImageId: 'root',
      );

      final document = ViewerDocumentGraphService.build(
        FrameState(elements: [root, child, annotation]),
      );
      final exportRect = ViewerDocumentGraphService.resolveExportRect(
        document,
        focusImageId: 'root',
      );

      expect(exportRect.left, lessThanOrEqualTo(100));
      expect(exportRect.top, lessThanOrEqualTo(100));
      expect(exportRect.right, greaterThanOrEqualTo(410));
      expect(exportRect.bottom, greaterThanOrEqualTo(280));
    });
  });
}
