import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_canvas_resize_policy.dart';

void main() {
  group('ViewerCanvasResizePolicy', () {
    test('calcula tamano esperado con margen de 200 px', () {
      final expected = ViewerCanvasResizePolicy.expectedCanvasSize(
        const Size(1600, 900),
      );

      expect(expected.width, 1800);
      expect(expected.height, 1100);
    });

    test('considera alineado cuando current == expected', () {
      final aligned = ViewerCanvasResizePolicy.isCanvasAligned(
        targetSize: const Size(1600, 900),
        currentSize: const Size(1800, 1100),
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
  });
}
