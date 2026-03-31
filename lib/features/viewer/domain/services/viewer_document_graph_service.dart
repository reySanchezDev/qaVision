import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_document.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';

/// Servicio que proyecta un [FrameState] a un documento/layers reutilizable.
class ViewerDocumentGraphService {
  /// Construye el documento derivado de un frame.
  static ViewerDocument build(FrameState frame) {
    final sortedElements = List<CanvasElement>.from(frame.elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final nodesById = <String, ViewerDocumentNode>{};
    final childIdsByParent = <String, List<String>>{};
    final orderedIds = <String>[];

    String? parentIdFor(CanvasElement element) {
      if (element is ImageFrameComponent) {
        final parentId = element.parentImageId?.trim();
        return (parentId == null || parentId.isEmpty) ? null : parentId;
      }
      if (element is AnnotationElement) {
        final parentId = element.attachedImageId?.trim();
        return (parentId == null || parentId.isEmpty) ? null : parentId;
      }
      return null;
    }

    for (final element in sortedElements) {
      final parentId = parentIdFor(element);
      final node = ViewerDocumentNode(
        id: element.id,
        kind: element is ImageFrameComponent
            ? ViewerDocumentNodeKind.imageFrame
            : ViewerDocumentNodeKind.annotation,
        element: element,
        parentId: parentId,
        childIds: const [],
      );
      nodesById[element.id] = node;
      orderedIds.add(element.id);
      if (parentId != null) {
        childIdsByParent
            .putIfAbsent(parentId, () => <String>[])
            .add(element.id);
      }
    }

    for (final entry in childIdsByParent.entries) {
      final current = nodesById[entry.key];
      if (current == null) continue;
      nodesById[entry.key] = ViewerDocumentNode(
        id: current.id,
        kind: current.kind,
        element: current.element,
        parentId: current.parentId,
        childIds: List<String>.unmodifiable(entry.value),
      );
    }

    return ViewerDocument(
      frame: frame,
      nodesById: Map<String, ViewerDocumentNode>.unmodifiable(nodesById),
      orderedNodeIds: List<String>.unmodifiable(orderedIds),
    );
  }

  /// Busca la imagen mas superior bajo el punto indicado.
  static ImageFrameComponent? topImageAtPoint(
    ViewerDocument document,
    Offset point, {
    double imageZoom = 1,
  }) {
    for (final image
        in document.orderedImages(frontToBack: true)) {
      final bounds = ViewerCompositionHelper.imageFrameRect(
        image,
        imageZoom: imageZoom,
      );
      if (bounds.contains(point)) {
        return image;
      }
    }
    return null;
  }

  /// Hit-test global sobre el documento ya ordenado.
  static CanvasElement? hitTest(
    ViewerDocument document,
    Offset point, {
    double imageZoom = 1,
    double annotationInflate = 8,
  }) {
    for (final element in document.orderedElements(frontToBack: true)) {
      if (element is ImageFrameComponent) {
        final bounds = ViewerCompositionHelper.imageFrameRect(
          element,
          imageZoom: imageZoom,
        );
        if (bounds.contains(point)) {
          return element;
        }
        continue;
      }

      final bounds = ViewerCompositionHelper.elementBounds(
        element,
        elements: document.frame.elements,
        imageZoom: imageZoom,
      ).inflate(annotationInflate);
      if (bounds.contains(point)) {
        return element;
      }
    }
    return null;
  }

  /// Obtiene los ids descendientes de una imagen.
  static Set<String> descendantImageIds(
    ViewerDocument document,
    String imageId,
  ) {
    final descendants = <String>{};

    void visit(String parentId) {
      final node = document.nodeById(parentId);
      if (node == null) return;
      for (final childId in node.childIds) {
        final child = document.nodeById(childId);
        if (child == null || child.element is! ImageFrameComponent) continue;
        if (!descendants.add(childId)) continue;
        visit(childId);
      }
    }

    visit(imageId);
    return descendants;
  }

  /// Imagen padre de un elemento dado.
  static ImageFrameComponent? parentImageForElement(
    ViewerDocument document,
    CanvasElement element,
  ) {
    if (element is ImageFrameComponent) {
      final parentId = element.parentImageId;
      if (parentId == null || parentId.isEmpty) return null;
      return document.imageById(parentId);
    }
    if (element is AnnotationElement) {
      final parentId = element.attachedImageId;
      if (parentId == null || parentId.isEmpty) return null;
      return document.imageById(parentId);
    }
    return null;
  }

  /// Rectangulo de exportacion para una imagen/subarbol o documento completo.
  static Rect resolveExportRect(
    ViewerDocument document, {
    String? focusImageId,
    double imageZoom = 1,
  }) {
    final elements = document.frame.elements;
    if (elements.isEmpty) {
      return Offset.zero & document.frame.canvasSize;
    }

    if (focusImageId != null && focusImageId.isNotEmpty) {
      final target = document.imageById(focusImageId);
      if (target != null) {
        var exportRect = ViewerCompositionHelper.imageFrameRect(
          target,
          imageZoom: imageZoom,
        );
        final subtreeIds = <String>{
          focusImageId,
          ...descendantImageIds(document, focusImageId),
        };
        for (final image in document.orderedImages()) {
          if (!subtreeIds.contains(image.id)) continue;
          exportRect = exportRect.expandToInclude(
            ViewerCompositionHelper.imageFrameRect(
              image,
              imageZoom: imageZoom,
            ),
          );
        }
        for (final element in elements.whereType<AnnotationElement>()) {
          final bounds = ViewerCompositionHelper.annotationBounds(
            element,
            elements: elements,
            imageZoom: imageZoom,
          );
          final isAttached = subtreeIds.contains(element.attachedImageId);
          if (isAttached || bounds.overlaps(exportRect)) {
            exportRect = exportRect.expandToInclude(bounds);
          }
        }
        return exportRect;
      }
    }

    var exportRect = ViewerCompositionHelper.elementBounds(
      elements.first,
      elements: elements,
      imageZoom: imageZoom,
    );
    for (var i = 1; i < elements.length; i++) {
      exportRect = exportRect.expandToInclude(
        ViewerCompositionHelper.elementBounds(
          elements[i],
          elements: elements,
          imageZoom: imageZoom,
        ),
      );
    }
    return exportRect;
  }

  /// Siguiente z-index libre del documento.
  static int nextZ(ViewerDocument document) {
    if (document.orderedNodeIds.isEmpty) return 0;
    final top = document.nodesById.values
        .map((node) => node.element.zIndex)
        .reduce(math.max);
    return top + 1;
  }

  /// Normaliza el z-index sin perder el orden relativo actual.
  static List<CanvasElement> normalizeZ(List<CanvasElement> elements) {
    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return List<CanvasElement>.generate(sorted.length, (index) {
      final element = sorted[index];
      if (element is ImageFrameComponent) {
        return element.copyWith(zIndex: index);
      }
      if (element is AnnotationElement) {
        return element.copyWith(zIndex: index);
      }
      return element;
    }, growable: false);
  }
}
