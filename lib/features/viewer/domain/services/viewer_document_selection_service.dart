import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_document.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_layer_entry.dart';

/// Servicio que adapta el arbol del documento a necesidades de seleccion/capas.
class ViewerDocumentSelectionService {
  /// Genera una lista plana jerarquica para el panel de capas.
  static List<ViewerLayerEntry> buildLayerEntries(
    ViewerDocument document, {
    String? selectedId,
  }) {
    final entries = <ViewerLayerEntry>[];
    final rootNodes = document.orderedNodeIds
        .map(document.nodeById)
        .whereType<ViewerDocumentNode>()
        .where((node) => node.parentId == null)
        .toList(growable: false);

    void visit(ViewerDocumentNode node, int depth) {
      entries.add(
        ViewerLayerEntry(
          id: node.id,
          label: _labelForNode(node, document),
          depth: depth,
          parentId: node.parentId,
          isImage: node.element is ImageFrameComponent,
          isSelected: node.id == selectedId,
          hasChildren: node.childIds.isNotEmpty,
        ),
      );

      final children = node.childIds
          .map(document.nodeById)
          .whereType<ViewerDocumentNode>()
          .toList(growable: false)
        ..sort(
          (a, b) => a.element.zIndex.compareTo(b.element.zIndex),
        );

      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    for (final root in rootNodes) {
      visit(root, 0);
    }

    return entries.reversed.toList(growable: false);
  }

  /// Camino jerarquico desde la raiz hasta el nodo seleccionado.
  static List<ViewerDocumentNode> selectionPath(
    ViewerDocument document,
    String? selectedId,
  ) {
    if (selectedId == null || selectedId.isEmpty) {
      return const <ViewerDocumentNode>[];
    }

    final path = <ViewerDocumentNode>[];
    var current = document.nodeById(selectedId);
    while (current != null) {
      path.insert(0, current);
      final parentId = current.parentId;
      if (parentId == null || parentId.isEmpty) {
        break;
      }
      current = document.nodeById(parentId);
    }
    return path;
  }

  static String _labelForNode(
    ViewerDocumentNode node,
    ViewerDocument document,
  ) {
    final element = node.element;
    if (element is ImageFrameComponent) {
      final siblingIndex = _siblingIndex(document, node.id);
      return node.parentId == null
          ? 'Imagen ${siblingIndex + 1}'
          : 'Subimagen ${siblingIndex + 1}';
    }

    if (element is AnnotationElement) {
      final base = switch (element.type) {
        AnnotationType.arrow => 'Flecha',
        AnnotationType.rectangle => 'Rectangulo',
        AnnotationType.circle => 'Circulo',
        AnnotationType.highlighter => 'Highlighter',
        AnnotationType.pencil => 'Lapiz',
        AnnotationType.text => 'Texto',
        AnnotationType.commentBubble => 'Burbuja',
        AnnotationType.blur => 'Blur',
        AnnotationType.stepMarker => 'Paso',
        AnnotationType.eraser => 'Borrador',
        AnnotationType.selection => 'Seleccion',
      };
      if (element.text.trim().isNotEmpty &&
          (element.type == AnnotationType.text ||
              element.type == AnnotationType.commentBubble ||
              element.type == AnnotationType.stepMarker)) {
        final compact = element.text.trim();
        final preview = compact.length > 18
            ? '${compact.substring(0, 18)}...'
            : compact;
        return '$base: $preview';
      }
      return base;
    }

    return 'Elemento';
  }

  static int _siblingIndex(ViewerDocument document, String nodeId) {
    final node = document.nodeById(nodeId);
    if (node == null) return 0;
    final parentId = node.parentId;

    final siblingIds = parentId == null
        ? document.orderedNodeIds
            .map(document.nodeById)
            .whereType<ViewerDocumentNode>()
            .where((entry) => entry.parentId == null && entry.isImage)
            .map((entry) => entry.id)
            .toList(growable: false)
        : document.nodeById(parentId)?.childIds
                .map(document.nodeById)
                .whereType<ViewerDocumentNode>()
                .where((entry) => entry.isImage)
                .map((entry) => entry.id)
                .toList(growable: false) ??
            const <String>[];

    return siblingIds.indexOf(nodeId).clamp(0, siblingIds.length);
  }
}
