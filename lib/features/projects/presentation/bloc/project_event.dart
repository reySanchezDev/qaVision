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

/// Evento interno para refrescar proyectos por cambios externos en storage.
final class ProjectsStorageSynced extends ProjectEvent {
  /// Crea una instancia de [ProjectsStorageSynced].
  const ProjectsStorageSynced();
}

/// Evento interno para refrescar proyectos por cambios del filesystem.
final class ProjectsFilesystemSynced extends ProjectEvent {
  /// Crea una instancia de [ProjectsFilesystemSynced].
  const ProjectsFilesystemSynced();
}

/// Evento para seleccionar/agregar una carpeta como proyecto.
final class ProjectFolderSelected extends ProjectEvent {
  /// Crea una instancia de [ProjectFolderSelected].
  const ProjectFolderSelected(this.folderPath);

  /// Ruta absoluta de la carpeta elegida.
  final String folderPath;

  @override
  List<Object?> get props => [folderPath];
}

/// Evento para reemplazar una carpeta en un slot especifico (0..2).
final class ProjectFolderReplacedAt extends ProjectEvent {
  /// Crea una instancia de [ProjectFolderReplacedAt].
  const ProjectFolderReplacedAt({
    required this.slotIndex,
    required this.folderPath,
  });

  /// Slot destino (0..2).
  final int slotIndex;

  /// Ruta absoluta de la carpeta elegida.
  final String folderPath;

  @override
  List<Object?> get props => [slotIndex, folderPath];
}

/// Evento para notificar movimiento/renombre detectado por watcher.
final class ProjectFolderMovedDetected extends ProjectEvent {
  /// Crea una instancia de [ProjectFolderMovedDetected].
  const ProjectFolderMovedDetected({
    required this.oldPath,
    required this.newPath,
  });

  /// Ruta anterior reportada.
  final String oldPath;

  /// Ruta nueva reportada.
  final String newPath;

  @override
  List<Object?> get props => [oldPath, newPath];
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
