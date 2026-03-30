import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/services/viewer_canvas_interaction_service.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_text_dialog.dart';

/// Acciones de texto del canvas (edición por doble tap).
class ViewerCanvasTextActions {
  /// Maneja el doble tap sobre texto/burbuja/marcador para edición inline.
  static Future<void> handleDoubleTapDown({
    required BuildContext context,
    required ViewerState state,
    required TapDownDetails details,
    required double contentZoom,
  }) async {
    if (state.activeTool != AnnotationType.selection) return;

    final hit = ViewerCanvasInteractionService.hitTest(
      state.frame,
      details.localPosition,
      zoom: contentZoom,
    );
    if (hit is! AnnotationElement) return;
    if (hit.type != AnnotationType.text &&
        hit.type != AnnotationType.commentBubble &&
        hit.type != AnnotationType.stepMarker) {
      return;
    }

    context.read<ViewerBloc>().add(
      ViewerElementSelected(
        elementId: hit.id,
        centerImage: false,
      ),
    );
    final updated = await ViewerTextDialog.prompt(
      context,
      initialValue: hit.text,
      title: 'Editar texto',
    );
    if (!context.mounted || updated == null || updated.trim().isEmpty) return;
    context.read<ViewerBloc>().add(ViewerSelectedElementTextUpdated(updated));
  }
}
