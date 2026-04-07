import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/features/floating_button/presentation/utils/virtual_desktop_overlay_metrics.dart';

void main() {
  group('buildVirtualDesktopOverlayMetrics', () {
    test('convierte bounds fisicos a overlay logico con el mismo dpr', () {
      final metrics = buildVirtualDesktopOverlayMetrics(
        physicalBounds: const Rect.fromLTWH(-1920, 0, 3840, 1080),
        devicePixelRatio: 1,
      );

      expect(metrics.logicalOrigin, const Offset(-1920, 0));
      expect(metrics.logicalSize, const Size(3840, 1080));
    });

    test(
      'convierte una seleccion local a coordenadas fisicas del escritorio',
      () {
        final metrics = buildVirtualDesktopOverlayMetrics(
          physicalBounds: const Rect.fromLTWH(-2560, 0, 4480, 1440),
          devicePixelRatio: 1.25,
        );

        final physicalRect = metrics.selectionToPhysicalRect(
          const Rect.fromLTWH(100, 80, 320, 240),
        );

        expect(physicalRect.left, -2435);
        expect(physicalRect.top, 100);
        expect(physicalRect.width, 400);
        expect(physicalRect.height, 300);
      },
    );
  });
}
