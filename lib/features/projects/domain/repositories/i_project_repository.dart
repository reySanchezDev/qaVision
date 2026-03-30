import 'package:qavision/features/projects/domain/entities/project_entity.dart';

/// Interfaz del repositorio de proyectos.
///
/// Define el contrato para el CRUD de proyectos y
/// la gestión de carpetas físicas asociadas (§5).
abstract class IProjectRepository {
  /// Obtiene la lista de todos los proyectos.
  Future<List<ProjectEntity>> getProjects();

  /// Agrega/activa una carpeta como proyecto.
  ///
  /// Si la carpeta ya existe como proyecto, la activa y actualiza su uso.
  /// Si no existe y hay 3 proyectos, reemplaza el menos usado.
  Future<ProjectEntity?> addOrActivateFolder(String folderPath);

  /// Reemplaza o asigna una carpeta en un slot especifico (0..2).
  ///
  /// Mantiene un maximo de 3 proyectos y respeta el orden de slots.
  Future<ProjectEntity?> replaceProjectAt({
    required int slotIndex,
    required String folderPath,
  });

  /// Reconciliar proyectos persistidos con el filesystem.
  ///
  /// Debe podar carpetas inexistentes y normalizar el estado.
  Future<List<ProjectEntity>> reconcileWithDisk();

  /// Registra uso de un proyecto al capturar.
  Future<void> markProjectUsed(String projectId);

  /// Crea un nuevo proyecto y su carpeta física.
  ///
  /// Obsoleto: se mantiene por compatibilidad temporal.
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
