import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_canvas_interaction_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

/// Painter del canvas del visor.
class ViewerCanvasPainter extends CustomPainter {
  /// Crea una instancia de [ViewerCanvasPainter].
  const ViewerCanvasPainter({
    required this.frame,
    required this.selectedElementId,
    required this.contentZoom,
    this.hiddenElementId,
  });

  /// Estado visual del frame.
  final FrameState frame;

  /// Id del elemento seleccionado.
  final String? selectedElementId;

  /// Zoom visual aplicado al contenido del frame.
  final double contentZoom;

  /// Elemento que no debe pintarse porque se esta editando inline.
  final String? hiddenElementId;

  @override
  void paint(Canvas canvas, Size size) {
    ViewerCompositionHelper.paintFrame(
      canvas,
      frame,
      contentZoom: contentZoom,
      hiddenElementId: hiddenElementId,
    );
    _drawFrameOutline(canvas, frame.canvasSize);

    if (selectedElementId == null) return;
    final selected = frame.elements
        .where((element) => element.id == selectedElementId)
        .firstOrNull;
    if (selected == null) return;
    _drawSelection(canvas, selected);
  }

  void _drawFrameOutline(Canvas canvas, Size frameSize) {
    canvas.drawRect(
      Offset.zero & frameSize,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white24,
    );
  }

  void _drawSelection(Canvas canvas, CanvasElement element) {
    final bounds = ViewerCanvasInteractionService.selectionBounds(
      element,
      elements: frame.elements,
      zoom: contentZoom,
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.lightBlueAccent;
    final handle = Paint()..color = Colors.lightBlueAccent;

    canvas.drawRect(bounds, outline);

    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ];
    final midPoints = [
      Offset(bounds.left + bounds.width / 2, bounds.top),
      Offset(bounds.left + bounds.width / 2, bounds.bottom),
      Offset(bounds.left, bounds.top + bounds.height / 2),
      Offset(bounds.right, bounds.top + bounds.height / 2),
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, 6, handle);
    }
    for (final mid in midPoints) {
      canvas.drawCircle(mid, 5, handle);
    }
  }

  @override
  bool shouldRepaint(covariant ViewerCanvasPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.selectedElementId != selectedElementId ||
        oldDelegate.contentZoom != contentZoom ||
        oldDelegate.hiddenElementId != hiddenElementId;
  }
}
