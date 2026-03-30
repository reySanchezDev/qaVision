import 'package:flutter/widgets.dart';

/// Intent para atajo de deshacer.
class ViewerUndoIntent extends Intent {
  /// Crea una instancia de [ViewerUndoIntent].
  const ViewerUndoIntent();
}

/// Intent para atajo de rehacer.
class ViewerRedoIntent extends Intent {
  /// Crea una instancia de [ViewerRedoIntent].
  const ViewerRedoIntent();
}

/// Intent para atajo de eliminar elemento seleccionado.
class ViewerDeleteIntent extends Intent {
  /// Crea una instancia de [ViewerDeleteIntent].
  const ViewerDeleteIntent();
}
