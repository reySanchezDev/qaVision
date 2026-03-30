import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Eventos del BLoC de la pantalla flotante.
sealed class FloatingButtonEvent extends Equatable {
  /// Crea una instancia base de [FloatingButtonEvent].
  const FloatingButtonEvent();

  @override
  List<Object?> get props => [];
}

/// Inicializa la pantalla flotante.
final class FloatingButtonStarted extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonStarted].
  const FloatingButtonStarted();
}

/// Recalcula el docking al mover la ventana.
final class FloatingButtonDragged extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonDragged].
  const FloatingButtonDragged({
    required this.offset,
    required this.screenBounds,
  });

  /// Posicion reportada del top-left de la ventana.
  final Offset offset;

  /// Bounds visibles del display primario.
  final Rect screenBounds;

  @override
  List<Object?> get props => [offset, screenBounds];
}

/// Dispara una captura segun el modo actual.
final class FloatingButtonCaptureRequested extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonCaptureRequested].
  const FloatingButtonCaptureRequested({
    this.captureRect,
    this.windowAlreadyHidden = false,
    this.restoreFloatingWindow = true,
  });

  /// Rectangulo de captura en coordenadas de pantalla.
  final Rect? captureRect;

  /// Indica si la ventana ya fue ocultada antes de disparar la captura.
  final bool windowAlreadyHidden;

  /// Indica si la ventana flotante debe mostrarse al finalizar la captura.
  final bool restoreFloatingWindow;

  @override
  List<Object?> get props => [
    captureRect,
    windowAlreadyHidden,
    restoreFloatingWindow,
  ];
}

/// Cambia el proyecto activo.
final class FloatingButtonProjectChanged extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonProjectChanged].
  const FloatingButtonProjectChanged(this.project, {this.fromPicker = false});

  /// Proyecto seleccionado.
  final ProjectEntity project;

  /// True cuando se selecciono desde el icono selector de proyecto.
  final bool fromPicker;

  @override
  List<Object?> get props => [project, fromPicker];
}

/// Asigna una carpeta al slot rapido indicado.
final class FloatingButtonQuickSlotFolderSelected extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonQuickSlotFolderSelected].
  const FloatingButtonQuickSlotFolderSelected({
    required this.slotIndex,
    required this.folderPath,
  });

  /// Slot destino (0..2).
  final int slotIndex;

  /// Ruta absoluta de carpeta seleccionada.
  final String folderPath;

  @override
  List<Object?> get props => [slotIndex, folderPath];
}

/// Cambia el modo de captura activo.
final class FloatingButtonCaptureModeChanged extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonCaptureModeChanged].
  const FloatingButtonCaptureModeChanged(this.mode);

  /// Modo nuevo.
  final FloatingCaptureMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Actualiza visibilidad, color y posicion desde configuracion.
final class FloatingButtonSettingsUpdated extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonSettingsUpdated].
  const FloatingButtonSettingsUpdated({
    required this.isVisible,
    required this.color,
    required this.position,
  });

  /// Si debe estar visible.
  final bool isVisible;

  /// Color ARGB principal.
  final int color;

  /// Posicion persistida.
  final Offset position;

  @override
  List<Object?> get props => [isVisible, color, position];
}

/// Sincroniza los proyectos al cambiar en cualquier pantalla.
final class FloatingButtonProjectsSynced extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonProjectsSynced].
  const FloatingButtonProjectsSynced(this.projects);

  /// Lista actual de proyectos.
  final List<ProjectEntity> projects;

  @override
  List<Object?> get props => [projects];
}

/// Detiene una sesion continua de captura clip.
final class FloatingButtonClipSessionStarted extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonClipSessionStarted].
  const FloatingButtonClipSessionStarted();
}

/// Detiene una sesion continua de captura clip.
final class FloatingButtonClipSessionStopped extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonClipSessionStopped].
  const FloatingButtonClipSessionStopped();
}

/// Marca el inicio del selector de region.
final class FloatingButtonRegionSelectionStarted extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonRegionSelectionStarted].
  const FloatingButtonRegionSelectionStarted();
}

/// Marca el fin del selector de region.
final class FloatingButtonRegionSelectionEnded extends FloatingButtonEvent {
  /// Crea una instancia de [FloatingButtonRegionSelectionEnded].
  const FloatingButtonRegionSelectionEnded();
}
