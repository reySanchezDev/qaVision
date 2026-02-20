import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Interfaz del repositorio de proyectos.
///
/// Define el contrato para el CRUD de proyectos y
/// la gestión de carpetas físicas asociadas (§5).
abstract class IProjectRepository {
  /// Obtiene la lista de todos los proyectos.
  Future<List<ProjectEntity>> getProjects();

  /// Crea un nuevo proyecto y su carpeta física.
  Future<ProjectEntity> createProject(ProjectEntity project);

  /// Actualiza un proyecto existente.
  ///
  /// Si el nombre cambia, la carpeta física se renombra.
  Future<void> updateProject(ProjectEntity project);

  /// Obtiene el proyecto predeterminado actual.
  Future<ProjectEntity?> getDefaultProject();

  /// Establece un proyecto como predeterminado.
  Future<void> setDefaultProject(String projectId);
}
