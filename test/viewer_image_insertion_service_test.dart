import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/viewer_image_insertion_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

ImageFrameComponent _image({
  required String id,
  required Offset position,
  required Size size,
  String? parentImageId,
  double padding = 0,
  int zIndex = 0,
}) {
  return ImageFrameComponent(
    id: id,
    position: position,
    zIndex: zIndex,
    path: '$id.jpg',
    contentSize: size,
    style: ImageFrameStyle(
      backgroundColor: 0xFFFFFFFF,
      backgroundOpacity: 1,
      borderColor: 0x00000000,
      borderWidth: 0,
      padding: padding,
    ),
    transform: ImageFrameTransform(
      position: position,
      size: size,
    ),
    parentImageId: parentImageId,
  );
}

void main() {
  group('ViewerImageInsertionService', () {
    test('usa el frame seleccionado como padre cuando no hay drop point', () {
      final root = _image(
        id: 'root',
        position: const Offset(120, 80),
        size: const Size(500, 360),
        padding: 16,
      );
      final frame = FrameState(
        canvasSize: const Size(1400, 900),
        elements: [root],
      );

      final plan = ViewerImageInsertionService.plan(
        frame: frame,
        rawImageSize: const Size(800, 600),
        selectedElementId: root.id,
      );

      expect(plan.parentImageId, root.id);
      expect(root.contentViewportRect.contains(plan.position), isTrue);
      expect(
        root.contentViewportRect.contains(
          plan.position + Offset(plan.fittedSize.width, plan.fittedSize.height),
        ),
        isTrue,
      );
    });

    test('prioriza el frame mas profundo bajo el punto de drop', () {
      final root = _image(
        id: 'root',
        position: const Offset(100, 60),
        size: const Size(700, 500),
        padding: 20,
      );
      final child = _image(
        id: 'child',
        position: const Offset(180, 140),
        size: const Size(220, 180),
        parentImageId: root.id,
        padding: 12,
        zIndex: 1,
      );
      final frame = FrameState(
        canvasSize: const Size(1500, 900),
        elements: [root, child],
      );

      final dropPoint = child.contentViewportRect.center;
      final plan = ViewerImageInsertionService.plan(
        frame: frame,
        rawImageSize: const Size(320, 240),
        selectedElementId: root.id,
        dropPoint: dropPoint,
      );

      expect(plan.parentImageId, child.id);
      expect(child.contentViewportRect.contains(plan.position), isTrue);
      expect(
        child.contentViewportRect.contains(
          plan.position + Offset(plan.fittedSize.width, plan.fittedSize.height),
        ),
        isTrue,
      );
    });

    test('si el drop cae fuera de cualquier frame inserta en workspace', () {
      final root = _image(
        id: 'root',
        position: const Offset(180, 120),
        size: const Size(420, 320),
      );
      final frame = FrameState(
        canvasSize: const Size(1200, 800),
        elements: [root],
      );

      final plan = ViewerImageInsertionService.plan(
        frame: frame,
        rawImageSize: const Size(240, 160),
        selectedElementId: root.id,
        dropPoint: const Offset(980, 660),
      );

      expect(plan.parentImageId, isNull);
      expect(
        (Offset.zero & frame.canvasSize).contains(plan.position),
        isTrue,
      );
    });

    test('resuelve target y posicion de drop respetando el zoom visible', () {
      final root = _image(
        id: 'root',
        position: const Offset(100, 80),
        size: const Size(300, 220),
        padding: 10,
      );
      final frame = FrameState(
        canvasSize: const Size(1200, 800),
        elements: [root],
      );
      const displayZoom = 1.5;
      final visualDropPoint = ViewerImageInsertionService.plan(
        frame: frame,
        rawImageSize: const Size(200, 100),
        dropPoint: ViewerCompositionHelper.imageContentViewportRect(
          root,
          imageZoom: displayZoom,
        ).center,
        displayZoom: displayZoom,
      );

      expect(visualDropPoint.parentImageId, root.id);
      expect(
        root.contentViewportRect.contains(visualDropPoint.position),
        isTrue,
      );
      expect(
        root.contentViewportRect.contains(
          visualDropPoint.position +
              Offset(
                visualDropPoint.fittedSize.width,
                visualDropPoint.fittedSize.height,
              ),
        ),
        isTrue,
      );
    });
  });
}
