import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Bordes validos para acoplar la pantalla flotante.
enum FloatingDockEdge {
  /// Borde izquierdo de la pantalla.
  left,

  /// Borde derecho de la pantalla.
  right,

  /// Borde superior de la pantalla.
  top,

  /// Borde inferior de la pantalla.
  bottom,
}

/// Modo de captura activo en la pantalla flotante.
enum FloatingCaptureMode {
  /// Captura de pantalla completa.
  screen,

  /// Captura de región seleccionada.
  region,

  /// Sesión de captura continua (clip).
  clip,
}

/// Helpers de [FloatingDockEdge].
extension FloatingDockEdgeX on FloatingDockEdge {
  /// True cuando el borde obliga layout vertical.
  bool get isVertical =>
      this == FloatingDockEdge.left || this == FloatingDockEdge.right;
}

/// Estado del BLoC de la pantalla flotante.
class FloatingButtonState extends Equatable {
  /// Crea una instancia de [FloatingButtonState].
  const FloatingButtonState({
    this.position = const Offset(0, 100),
    this.dockEdge = FloatingDockEdge.top,
    this.activeProject,
    this.projects = const [],
    this.quickProjectIds = const [],
    this.isVisible = true,
    this.color = 0xFF1E88E5,
    this.captureMode = FloatingCaptureMode.region,
    this.isClipSessionActive = false,
    this.isRegionSelecting = false,
  });

  /// Posicion actual de la ventana flotante (top-left).
  final Offset position;

  /// Borde al que se encuentra acoplada.
  final FloatingDockEdge dockEdge;

  /// Proyecto seleccionado actualmente para capturas.
  final ProjectEntity? activeProject;

  /// Lista completa de proyectos disponibles.
  final List<ProjectEntity> projects;

  /// IDs de accesos rapidos visibles (maximo 3).
  final List<String> quickProjectIds;

  /// Si la pantalla flotante es visible globalmente.
  final bool isVisible;

  /// Color ARGB de acento principal.
  final int color;

  /// Modo de captura activo.
  final FloatingCaptureMode captureMode;

  /// Si hay una sesion continua de clip ejecutandose.
  final bool isClipSessionActive;

  /// Si el selector de region esta activo temporalmente.
  final bool isRegionSelecting;

  /// True si el layout interno debe renderizarse en vertical.
  bool get isVertical => dockEdge.isVertical;

  /// Tamano de ventana requerido segun la orientacion actual.
  Size get windowSize =>
      isVertical ? kFloatingVerticalSize : kFloatingHorizontalSize;

  /// Crea una copia de este estado con los campos especificados modificados.
  FloatingButtonState copyWith({
    Offset? position,
    FloatingDockEdge? dockEdge,
    ProjectEntity? activeProject,
    bool clearActiveProject = false,
    List<ProjectEntity>? projects,
    List<String>? quickProjectIds,
    bool? isVisible,
    int? color,
    FloatingCaptureMode? captureMode,
    bool? isClipSessionActive,
    bool? isRegionSelecting,
  }) {
    return FloatingButtonState(
      position: position ?? this.position,
      dockEdge: dockEdge ?? this.dockEdge,
      activeProject: clearActiveProject
          ? null
          : activeProject ?? this.activeProject,
      projects: projects ?? this.projects,
      quickProjectIds: quickProjectIds ?? this.quickProjectIds,
      isVisible: isVisible ?? this.isVisible,
      color: color ?? this.color,
      captureMode: captureMode ?? this.captureMode,
      isClipSessionActive: isClipSessionActive ?? this.isClipSessionActive,
      isRegionSelecting: isRegionSelecting ?? this.isRegionSelecting,
    );
  }

  @override
  List<Object?> get props => [
    position,
    dockEdge,
    activeProject,
    projects,
    quickProjectIds,
    isVisible,
    color,
    captureMode,
    isClipSessionActive,
    isRegionSelecting,
  ];
}
