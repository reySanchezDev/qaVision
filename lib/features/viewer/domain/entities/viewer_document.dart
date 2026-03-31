import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Tipo de nodo dentro del documento editable del visor.
enum ViewerDocumentNodeKind {
  /// Frame de imagen.
  imageFrame,

  /// Anotacion vectorial o de texto.
  annotation,
}

/// Nodo del documento editable del visor.
class ViewerDocumentNode {
  /// Crea un nodo del documento.
  const ViewerDocumentNode({
    required this.id,
    required this.kind,
    required this.element,
    required this.parentId,
    required this.childIds,
  });

  /// Identificador unico del nodo.
  final String id;

  /// Tipo de nodo.
  final ViewerDocumentNodeKind kind;

  /// Elemento real asociado al nodo.
  final CanvasElement element;

  /// Id del padre cuando existe.
  final String? parentId;

  /// Hijos directos del nodo.
  final List<String> childIds;

  /// Indica si el nodo es una imagen.
  bool get isImage => element is ImageFrameComponent;

  /// Indica si el nodo es una anotacion.
  bool get isAnnotation => element is AnnotationElement;
}

/// Documento derivado del frame actual del visor.
class ViewerDocument {
  /// Crea un documento del visor.
  const ViewerDocument({
    required this.frame,
    required this.nodesById,
    required this.orderedNodeIds,
  });

  /// Frame fuente del documento.
  final FrameState frame;

  /// Nodos indexados por id.
  final Map<String, ViewerDocumentNode> nodesById;

  /// Orden global por z-index.
  final List<String> orderedNodeIds;

  /// Obtiene un nodo por id.
  ViewerDocumentNode? nodeById(String id) => nodesById[id];

  /// Obtiene un elemento por id.
  CanvasElement? elementById(String id) => nodesById[id]?.element;

  /// Obtiene una imagen por id.
  ImageFrameComponent? imageById(String id) {
    final element = elementById(id);
    return element is ImageFrameComponent ? element : null;
  }

  /// Obtiene los elementos en orden de render.
  List<CanvasElement> orderedElements({bool frontToBack = false}) {
    final ids = frontToBack ? orderedNodeIds.reversed : orderedNodeIds;
    return ids
        .map((id) => nodesById[id]?.element)
        .whereType<CanvasElement>()
        .toList(growable: false);
  }

  /// Obtiene las imagenes ordenadas por z-index.
  List<ImageFrameComponent> orderedImages({bool frontToBack = false}) {
    return orderedElements(frontToBack: frontToBack)
        .whereType<ImageFrameComponent>()
        .toList(growable: false);
  }
}
