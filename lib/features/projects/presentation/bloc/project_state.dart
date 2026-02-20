import 'package:equatable/equatable.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Estados del BLoC de proyectos.
sealed class ProjectState extends Equatable {
  /// Constructor base de [ProjectState].
  const ProjectState();

  @override
  List<Object?> get props => [];
}

/// Extensión para facilitar el acceso al proyecto activo.
extension ProjectStateX on ProjectState {
  /// Devuelve el proyecto marcado como predeterminado, si existe.
  ProjectEntity? get activeProject {
    if (this is ProjectLoadSuccess) {
      final success = this as ProjectLoadSuccess;
      return success.projects.firstWhere(
        (p) => p.isDefault,
        orElse: () => success.projects.first,
      );
    }
    return null;
  }
}

/// Estado inicial antes de cargar proyectos.
final class ProjectInitial extends ProjectState {
  /// Crea una instancia de [ProjectInitial].
  const ProjectInitial();
}

/// Estado de carga.
final class ProjectLoading extends ProjectState {
  /// Crea una instancia de [ProjectLoading].
  const ProjectLoading();
}

/// Estado cuando los proyectos se cargaron correctamente.
final class ProjectLoadSuccess extends ProjectState {
  /// Crea una instancia de [ProjectLoadSuccess].
  const ProjectLoadSuccess(this.projects);

  /// Lista de proyectos cargados.
  final List<ProjectEntity> projects;

  @override
  List<Object?> get props => [projects];
}

/// Estado de error.
final class ProjectError extends ProjectState {
  /// Crea una instancia de [ProjectError].
  const ProjectError(this.message, {this.exception});

  /// Mensaje de error.
  final String message;

  /// Excepción original.
  final Exception? exception;

  @override
  List<Object?> get props => [message, exception];
}
