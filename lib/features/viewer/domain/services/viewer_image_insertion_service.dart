import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_document.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/services/image_frame_component_service.dart';
import 'package:qavision/features/viewer/domain/services/viewer_document_graph_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';

/// Plan derivado para insertar una nueva imagen en el documento del visor.
class ViewerImageInsertionPlan {
  /// Crea un [ViewerImageInsertionPlan].
  const ViewerImageInsertionPlan({
    required this.parentImageId,
    required this.movementBounds,
    required this.fittedSize,
    required this.position,
  });

  /// Id del frame padre cuando la imagen se inserta dentro de otro frame.
  final String? parentImageId;

  /// Rectangulo real donde la imagen puede vivir.
  final Rect movementBounds;

  /// Tamano ya ajustado al espacio disponible.
  final Size fittedSize;

  /// Posicion inicial final ya acotada al area de movimiento.
  final Offset position;
}

/// Resuelve de forma consistente donde y como insertar nuevas imagenes.
class ViewerImageInsertionService {
  static const double _rootFillRatio = 0.55;
  static const double _nestedFillRatio = 0.72;
  static const double _cascadeOffset = 24;
  static const double _preferredInset = 18;

  /// Construye un plan de insercion para una nueva imagen.
  static ViewerImageInsertionPlan plan({
    required FrameState frame,
    required Size rawImageSize,
    String? selectedElementId,
    Offset? dropPoint,
    double displayZoom = 1,
  }) {
    final document = ViewerDocumentGraphService.build(frame);
    final parent = _resolveTargetImage(
      document,
      selectedElementId: selectedElementId,
      dropPoint: dropPoint,
      displayZoom: displayZoom,
    );
    final movementBounds =
        parent?.contentViewportRect ??
        ViewerWorkspaceLayout.resolve(frame.canvasSize);
    final fittedSize = ImageFrameComponentService.fitImageInsideFrame(
      rawImageSize,
      movementBounds.size,
      maxFillRatio: parent == null ? _rootFillRatio : _nestedFillRatio,
    );
    final preferredPosition = _resolvePreferredPosition(
      document,
      parent: parent,
      movementBounds: movementBounds,
      fittedSize: fittedSize,
      dropPoint: dropPoint,
      displayZoom: displayZoom,
    );
    final clampedPosition = ImageFrameComponentService.clampPositionToFrame(
      position: preferredPosition,
      size: fittedSize,
      frameSize: frame.canvasSize,
      movementBounds: movementBounds,
    );

    return ViewerImageInsertionPlan(
      parentImageId: parent?.id,
      movementBounds: movementBounds,
      fittedSize: fittedSize,
      position: clampedPosition,
    );
  }

  static ImageFrameComponent? _resolveTargetImage(
    ViewerDocument document, {
    required String? selectedElementId,
    required Offset? dropPoint,
    required double displayZoom,
  }) {
    if (dropPoint != null) {
      for (final image in document.orderedImages(frontToBack: true)) {
        final projectedViewport =
            ViewerCompositionHelper.imageContentViewportRect(
              image,
              elements: document.frame.elements,
              imageZoom: displayZoom,
            );
        if (projectedViewport.contains(dropPoint)) {
          return image;
        }
      }
      return null;
    }

    if (selectedElementId == null || selectedElementId.isEmpty) {
      return null;
    }

    final selected = document.elementById(selectedElementId);
    if (selected is ImageFrameComponent) {
      return selected;
    }
    if (selected is AnnotationElement) {
      final attachedId = selected.attachedImageId;
      if (attachedId != null && attachedId.isNotEmpty) {
        return document.imageById(attachedId);
      }
    }
    return null;
  }

  static Offset _resolvePreferredPosition(
    ViewerDocument document, {
    required ImageFrameComponent? parent,
    required Rect movementBounds,
    required Size fittedSize,
    required Offset? dropPoint,
    required double displayZoom,
  }) {
    if (dropPoint != null) {
      final scale = displayZoom.clamp(0.1, 10.0);
      final scaledSize = Size(
        fittedSize.width * scale,
        fittedSize.height * scale,
      );
      final displayRect = Rect.fromLTWH(
        dropPoint.dx - (scaledSize.width / 2),
        dropPoint.dy - (scaledSize.height / 2),
        scaledSize.width,
        scaledSize.height,
      );
      if (parent == null) {
        return displayRect.topLeft;
      }
      return ViewerCompositionHelper.logicalFrameRectFromDisplayRect(
        displayRect: displayRect,
        parentImageId: parent.id,
        elements: document.frame.elements,
        imageZoom: scale,
      ).topLeft;
    }

    final cascadeCount = _imageSiblingCount(document, parent);
    final inset = _preferredInset + (_cascadeOffset * cascadeCount);
    return Offset(
      movementBounds.left + inset,
      movementBounds.top + inset,
    );
  }

  static int _imageSiblingCount(
    ViewerDocument document,
    ImageFrameComponent? parent,
  ) {
    if (parent == null) {
      return document.orderedImages().where((image) {
        final parentId = image.parentImageId;
        return parentId == null || parentId.isEmpty;
      }).length;
    }

    return document
            .nodeById(parent.id)
            ?.childIds
            .map(document.imageById)
            .whereType<ImageFrameComponent>()
            .length ??
        0;
  }
}
