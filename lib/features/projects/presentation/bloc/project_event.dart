import 'package:equatable/equatable.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Eventos del BLoC de proyectos.
sealed class ProjectEvent extends Equatable {
  /// Constructor base de [ProjectEvent].
  const ProjectEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para cargar la lista de proyectos.
final class ProjectsLoaded extends ProjectEvent {
  /// Crea una instancia de [ProjectsLoaded].
  const ProjectsLoaded();
}

/// Evento para crear un nuevo proyecto.
final class ProjectCreated extends ProjectEvent {
  /// Crea una instancia de [ProjectCreated].
  const ProjectCreated(this.project);

  /// El proyecto a crear.
  final ProjectEntity project;

  @override
  List<Object?> get props => [project];
}

/// Evento para actualizar un proyecto existente.
final class ProjectUpdated extends ProjectEvent {
  /// Crea una instancia de [ProjectUpdated].
  const ProjectUpdated(this.project);

  /// El proyecto actualizado.
  final ProjectEntity project;

  @override
  List<Object?> get props => [project];
}

/// Evento para establecer un proyecto como predeterminado.
final class ProjectSetDefault extends ProjectEvent {
  /// Crea una instancia de [ProjectSetDefault].
  const ProjectSetDefault(this.projectId);

  /// ID del proyecto a establecer como predeterminado.
  final String projectId;

  @override
  List<Object?> get props => [projectId];
}
