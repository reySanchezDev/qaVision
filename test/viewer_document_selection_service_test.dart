import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_selection_service.dart';

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
  group('ViewerDocumentSelectionService', () {
    test('genera entradas jerarquicas con depth y seleccion', () {
      final root = _image(
        id: 'root',
        position: Offset.zero,
        size: const Size(200, 140),
      );
      final child = _image(
        id: 'child',
        position: const Offset(20, 20),
        size: const Size(80, 60),
        zIndex: 1,
        parentImageId: 'root',
      );
      const annotation = AnnotationElement(
        id: 'ann',
        position: Offset(12, 10),
        zIndex: 2,
        type: AnnotationType.text,
        color: 0xFFE53935,
        strokeWidth: 4,
        text: 'Comentario QA',
        attachedImageId: 'root',
        coordinateSpace: AnnotationCoordinateSpace.imageContent,
      );

      final document = ViewerDocumentGraphService.build(
        FrameState(elements: [root, child, annotation]),
      );
      final entries = ViewerDocumentSelectionService.buildLayerEntries(
        document,
        selectedId: 'ann',
      );

      final rootEntry = entries.firstWhere((entry) => entry.id == 'root');
      final childEntry = entries.firstWhere((entry) => entry.id == 'child');
      final annotationEntry = entries.firstWhere((entry) => entry.id == 'ann');

      expect(rootEntry.depth, 0);
      expect(childEntry.depth, 1);
      expect(annotationEntry.depth, 1);
      expect(annotationEntry.isSelected, isTrue);
      expect(annotationEntry.label, contains('Comentario QA'));
    });

    test('construye el camino de seleccion desde la raiz', () {
      final root = _image(
        id: 'root',
        position: Offset.zero,
        size: const Size(200, 140),
      );
      final child = _image(
        id: 'child',
        position: const Offset(20, 20),
        size: const Size(80, 60),
        zIndex: 1,
        parentImageId: 'root',
      );

      final document = ViewerDocumentGraphService.build(
        FrameState(elements: [root, child]),
      );
      final path = ViewerDocumentSelectionService.selectionPath(
        document,
        'child',
      );

      expect(path.map((node) => node.id).toList(), ['root', 'child']);
    });
  });
}
