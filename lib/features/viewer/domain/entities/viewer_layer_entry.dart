/// Entrada lista para representar un nodo del documento en la UI de capas.
class ViewerLayerEntry {
  /// Crea una entrada del panel de capas.
  const ViewerLayerEntry({
    required this.id,
    required this.label,
    required this.depth,
    required this.parentId,
    required this.isImage,
    required this.isSelected,
    required this.hasChildren,
  });

  /// Id del nodo asociado.
  final String id;

  /// Texto visible al usuario.
  final String label;

  /// Profundidad jerarquica dentro del arbol.
  final int depth;

  /// Id del padre cuando existe.
  final String? parentId;

  /// Indica si representa un frame de imagen.
  final bool isImage;

  /// Indica si es el elemento seleccionado actual.
  final bool isSelected;

  /// Indica si el nodo tiene hijos.
  final bool hasChildren;
}
