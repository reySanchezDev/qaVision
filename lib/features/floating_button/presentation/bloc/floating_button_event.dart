import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Eventos del BLoC del Botón Flotante.
sealed class FloatingButtonEvent extends Equatable {
  /// Crea una instancia de [FloatingButtonEvent].
  const FloatingButtonEvent();

  @override
  List<Object?> get props => [];
}

/// Dispara una captura de pantalla desde el botón.
final class FloatingButtonCaptureRequested extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonCaptureRequested].
  /// [captureRegion] indica si se debe seleccionar una zona.
  const FloatingButtonCaptureRequested({this.captureRegion = false});

  /// Si se debe capturar una región (§2.0).
  final bool captureRegion;

  @override
  List<Object?> get props => [captureRegion];
}

/// Inicia el botón con el proyecto predeterminado.
final class FloatingButtonStarted extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonStarted].
  const FloatingButtonStarted();
}

/// Actualiza la posición del botón al ser arrastrado.
final class FloatingButtonDragged extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonDragged] con el [offset] dado.
  const FloatingButtonDragged(this.offset);

  /// El desplazamiento (posición) nuevo del botón.
  final Offset offset;

  @override
  List<Object?> get props => [offset];
}

/// Expande o contrae el panel lateral del botón.
final class FloatingButtonToggled extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonToggled].
  const FloatingButtonToggled();
}

/// Cambia el proyecto activo desde el botón.
final class FloatingButtonProjectChanged extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonProjectChanged]
  /// para el [project] dado.
  const FloatingButtonProjectChanged(this.project);

  /// El proyecto al cual se desea cambiar.
  final ProjectEntity project;

  @override
  List<Object?> get props => [project];
}
