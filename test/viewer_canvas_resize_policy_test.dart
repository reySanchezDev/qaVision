import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_canvas_resize_policy.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';

void main() {
  group('ViewerCanvasResizePolicy', () {
    test('calcula tamano esperado ajustado al viewport', () {
      final expected = ViewerCanvasResizePolicy.expectedCanvasSize(
        const Size(1600, 900),
      );

      expect(expected.width, 1600);
      expect(expected.height, 900);
    });

    test('considera alineado cuando current == expected', () {
      final aligned = ViewerCanvasResizePolicy.isCanvasAligned(
        targetSize: const Size(1600, 900),
        currentSize: const Size(1600, 900),
      );

      expect(aligned, isTrue);
    });

    test('detecta desalineado cuando el canvas vuelve al default', () {
      final aligned = ViewerCanvasResizePolicy.isCanvasAligned(
        targetSize: const Size(1600, 900),
        currentSize: const Size(1500, 900),
      );

      expect(aligned, isFalse);
    });

    test('reserva margenes laterales negros para el workspace util', () {
      final workspace = ViewerWorkspaceLayout.resolve(const Size(1600, 900));

      expect(workspace.left, 0);
      expect(workspace.top, 0);
      expect(workspace.right, 1600);
      expect(workspace.bottom, 900);
    });
  });
}
