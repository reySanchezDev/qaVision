import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

/// Widget que envuelve el lienzo interactivo del visor (§9.4).
class ViewerCanvas extends StatelessWidget {
  /// Crea una instancia de [ViewerCanvas].
  const ViewerCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (previous, current) => previous.frame != current.frame,
      builder: (context, state) {
        return GestureDetector(
          onPanStart: (details) => _handlePanStart(context, state, details),
          onPanUpdate: (details) => _handlePanUpdate(context, state, details),
          onPanEnd: (details) => _handlePanEnd(context, state, details),
          child: CustomPaint(
            painter: ViewerPainter(
              frame: state.frame,
              selectedElementId: state.selectedElementId,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  void _handlePanStart(
    BuildContext context,
    ViewerState state,
    DragStartDetails details,
  ) {
    final position = details.localPosition;

    if (state.activeTool == AnnotationType.selection) {
      // Find the top-most element at this position
      final hitElement = _hitTest(state.frame, position);
      context.read<ViewerBloc>().add(
        ViewerElementSelected(elementId: hitElement?.id),
      );
    } else {
      context.read<ViewerBloc>().add(
        ViewerAnnotationStarted(position),
      );
    }
  }

  void _handlePanUpdate(
    BuildContext context,
    ViewerState state,
    DragUpdateDetails details,
  ) {
    final position = details.localPosition;

    if (state.activeTool == AnnotationType.selection) {
      if (state.selectedElementId != null) {
        // Simple drag of selected element
        context.read<ViewerBloc>().add(
          ViewerElementMoved(
            elementId: state.selectedElementId!,
            position: position,
          ),
        );
      }
    } else if (state.isDrawing) {
      context.read<ViewerBloc>().add(
        ViewerAnnotationUpdated(position),
      );
    }
  }

  void _handlePanEnd(
    BuildContext context,
    ViewerState state,
    DragEndDetails details,
  ) {
    if (state.isDrawing) {
      context.read<ViewerBloc>().add(const ViewerAnnotationFinished());
    }
  }

  CanvasElement? _hitTest(FrameState frame, Offset position) {
    // Search elements in reverse z-order to find the one on top
    final sortedElements = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    for (final element in sortedElements) {
      if (element is ImageElement) {
        final rect = element.position & element.size;
        if (rect.contains(position)) return element;
      } else if (element is AnnotationElement) {
        // Basic rectangular hit test for annotations for now
        final rect = element.position & const Size(40, 40);
        if (rect.contains(position)) return element;
      }
    }
    return null;
  }
}

/// Painter encargado de renderizar imágenes y anotaciones en el lienzo (§9.4).
class ViewerPainter extends CustomPainter {
  /// Crea una instancia de [ViewerPainter].
  ViewerPainter({required this.frame, this.selectedElementId});

  /// Estado del lienzo a dibujar.
  final FrameState frame;

  /// ID del elemento seleccionado para resaltar.
  final String? selectedElementId;

  @override
  void paint(Canvas canvas, Size size) {
    ViewerCompositionHelper.paintFrame(canvas, frame);

    // Dibuja borde de selección si hay un elemento activo
    if (selectedElementId != null) {
      final element = frame.elements.indexWhere(
        (e) => e.id == selectedElementId,
      );
      if (element != -1) {
        _drawSelectionIndicator(canvas, frame.elements[element]);
      }
    }
  }

  void _drawSelectionIndicator(Canvas canvas, CanvasElement element) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    Rect? rect;
    if (element is ImageElement) {
      rect = element.position & element.size;
    } else if (element is AnnotationElement) {
      rect = Rect.fromCenter(
        center: element.position,
        width: 40,
        height: 40,
      );
    }

    if (rect != null) {
      canvas
        ..drawRect(rect.inflate(4), paint)
        ..drawCircle(rect.topLeft, 4, paint..style = PaintingStyle.fill)
        ..drawCircle(rect.topRight, 4, paint)
        ..drawCircle(rect.bottomLeft, 4, paint)
        ..drawCircle(rect.bottomRight, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ViewerPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.selectedElementId != selectedElementId;
  }
}
