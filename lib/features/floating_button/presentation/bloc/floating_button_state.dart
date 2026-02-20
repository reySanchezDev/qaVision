import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Estados del BLoC del Botón Flotante.
class FloatingButtonState extends Equatable {
  /// Crea una instancia de [FloatingButtonState].
  const FloatingButtonState({
    this.position = const Offset(100, 100),
    this.isExpanded = false,
    this.activeProject,
    this.projects = const [],
    this.isVisible = true,
  });

  /// Posición actual del botón en la pantalla.
  final Offset position;

  /// Si el panel lateral está desplegado (§9.1).
  final bool isExpanded;

  /// Proyecto seleccionado actualmente para capturas.
  final ProjectEntity? activeProject;

  /// Lista de proyectos disponibles para cambio rápido.
  final List<ProjectEntity> projects;

  /// Si el botón es visible globalmente (§4.2).
  final bool isVisible;

  /// Crea una copia de este estado con los campos especificados modificados.
  FloatingButtonState copyWith({
    Offset? position,
    bool? isExpanded,
    ProjectEntity? activeProject,
    List<ProjectEntity>? projects,
    bool? isVisible,
  }) {
    return FloatingButtonState(
      position: position ?? this.position,
      isExpanded: isExpanded ?? this.isExpanded,
      activeProject: activeProject ?? this.activeProject,
      projects: projects ?? this.projects,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  List<Object?> get props => [
    position,
    isExpanded,
    activeProject,
    projects,
    isVisible,
  ];
}
