import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Eventos del BLoC del Visor / Editor.
sealed class ViewerEvent extends Equatable {
  /// Crea una instancia de [ViewerEvent].
  const ViewerEvent();

  @override
  List<Object?> get props => [];
}

/// Inicia el visor con una ruta de imagen base.
final class ViewerStarted extends ViewerEvent {
  /// Crea una instancia de [ViewerStarted].
  const ViewerStarted({required this.imagePath});

  /// Ruta del archivo de imagen a cargar.
  final String imagePath;

  @override
  List<Object?> get props => [imagePath];
}

/// Cambia la herramienta de anotación activa.
final class ViewerToolChanged extends ViewerEvent {
  /// Crea una instancia de [ViewerToolChanged].
  const ViewerToolChanged(this.tool);

  /// Nuevo tipo de herramienta (§9.4).
  final AnnotationType tool;

  @override
  List<Object?> get props => [tool];
}

/// Cambia las propiedades globales de dibujo.
final class ViewerPropertiesChanged extends ViewerEvent {
  /// Crea una instancia de [ViewerPropertiesChanged].
  const ViewerPropertiesChanged({this.color, this.strokeWidth});

  /// Nuevo color en formato ARB.
  final int? color;

  /// Nuevo grosor de línea.
  final double? strokeWidth;

  @override
  List<Object?> get props => [color, strokeWidth];
}

/// Cambia el color de fondo del lienzo (§9.0).
final class ViewerBackgroundColorChanged extends ViewerEvent {
  /// Crea una instancia de [ViewerBackgroundColorChanged].
  const ViewerBackgroundColorChanged(this.color);

  /// Nuevo color de fondo en formato ARB.
  final int color;

  @override
  List<Object?> get props => [color];
}

/// Inicia una nueva anotación en una posición dada.
final class ViewerAnnotationStarted extends ViewerEvent {
  /// Crea una instancia de [ViewerAnnotationStarted].
  const ViewerAnnotationStarted(this.position);

  /// Posición donde se inicia el trazo.
  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// Actualiza la anotación actual con un nuevo punto o posición final.
final class ViewerAnnotationUpdated extends ViewerEvent {
  /// Crea una instancia de [ViewerAnnotationUpdated].
  const ViewerAnnotationUpdated(this.position);

  /// Nueva posición del cursor/puntero.
  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// Finaliza la anotación actual y la persiste en el historial.
final class ViewerAnnotationFinished extends ViewerEvent {
  /// Crea una instancia de [ViewerAnnotationFinished].
  const ViewerAnnotationFinished();
}

/// Solicita deshacer la última acción (§9.4).
final class ViewerUndoRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerUndoRequested].
  const ViewerUndoRequested();
}

/// Solicita rehacer la última acción deshecha (§9.4).
final class ViewerRedoRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerRedoRequested].
  const ViewerRedoRequested();
}

/// Solicita el exportado / guardado de la composición actual (§9.7).
final class ViewerExportRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerExportRequested].
  const ViewerExportRequested();
}

/// Solicita copiar la composición actual al portapapeles (§9.7).
final class ViewerCopyRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerCopyRequested].
  const ViewerCopyRequested();
}

/// Solicita compartir la composición actual (§9.7).
final class ViewerShareRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerShareRequested].
  const ViewerShareRequested();
}

/// Solicita la lista de capturas recientes para el proyecto (§12.1).
final class ViewerRecentCapturesRequested extends ViewerEvent {
  /// Crea una instancia de [ViewerRecentCapturesRequested].
  const ViewerRecentCapturesRequested({required this.projectPath});

  /// Ruta del directorio del proyecto.
  final String projectPath;

  @override
  List<Object?> get props => [projectPath];
}

/// Añade una imagen externa al lienzo (§9.3, §7.0).
final class ViewerImageAdded extends ViewerEvent {
  /// Crea una instancia de [ViewerImageAdded].
  const ViewerImageAdded({required this.imagePath, required this.projectPath});

  /// Ruta de la imagen a añadir.
  final String imagePath;

  /// Ruta del directorio del proyecto.
  final String projectPath;

  @override
  List<Object?> get props => [imagePath, projectPath];
}

/// Selecciona un elemento del lienzo para edición o movimiento (§7.0).
final class ViewerElementSelected extends ViewerEvent {
  /// Crea una instancia de [ViewerElementSelected].
  const ViewerElementSelected({this.elementId});

  /// ID del elemento seleccionado. Null para deseleccionar.
  final String? elementId;

  @override
  List<Object?> get props => [elementId];
}

/// Mueve un elemento del lienzo a una nueva posición (§7.0).
final class ViewerElementMoved extends ViewerEvent {
  /// Crea una instancia de [ViewerElementMoved].
  const ViewerElementMoved({required this.elementId, required this.position});

  /// ID del elemento a mover.
  final String elementId;

  /// Nueva posición (top-left).
  final Offset position;

  @override
  List<Object?> get props => [elementId, position];
}

/// Elimina un elemento del lienzo (§7.0).
final class ViewerElementDeleted extends ViewerEvent {
  /// Crea una instancia de [ViewerElementDeleted].
  const ViewerElementDeleted({required this.elementId});

  /// ID del elemento a eliminar.
  final String elementId;

  @override
  List<Object?> get props => [elementId];
}

/// Cambia el orden de apilamiento de un elemento (§7.0).
final class ViewerElementZOrderChanged extends ViewerEvent {
  /// Crea una instancia de [ViewerElementZOrderChanged].
  const ViewerElementZOrderChanged({
    required this.elementId,
    required this.isForward,
  });

  /// ID del elemento.
  final String elementId;

  /// Si es true, lo trae al frente. Si es false, lo envía al fondo.
  final bool isForward;

  @override
  List<Object?> get props => [elementId, isForward];
}
