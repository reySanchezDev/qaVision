import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';

/// Implementación concreta del repositorio de proyectos.
///
/// Persiste proyectos en JSON local y crea/renombra
/// carpetas físicas en disco (§5).
class ProjectRepository implements IProjectRepository {
  /// Crea una instancia de [ProjectRepository].
  ProjectRepository({
    required StorageService storageService,
    required FileSystemService fileSystemService,
    required ISettingsRepository settingsRepository,
  }) : _storage = storageService,
       _fileSystem = fileSystemService,
       _settingsRepo = settingsRepository;

  final StorageService _storage;
  final FileSystemService _fileSystem;
  final ISettingsRepository _settingsRepo;

  static const String _projectsKey = 'projects';

  @override
  Future<List<ProjectEntity>> getProjects() async {
    final maps = _storage.getMapList(_projectsKey);
    return maps.map(_fromMap).toList();
  }

  @override
  Future<ProjectEntity> createProject(ProjectEntity project) async {
    // Crear carpeta física dentro de la carpeta raíz
    final settings = await _settingsRepo.loadSettings();
    if (settings.rootFolder != null) {
      await _fileSystem.createDirectory(
        '${settings.rootFolder}/${project.name}',
      );
    }

    // Persistir en storage
    final projects = await getProjects();
    // Si es predeterminado, quitar flag de los demás
    final updatedProjects = [
      if (project.isDefault)
        ...projects.map((p) => p.copyWith(isDefault: false))
      else
        ...projects,
      project,
    ];
    await _saveAll(updatedProjects);

    return project;
  }

  @override
  Future<void> updateProject(ProjectEntity project) async {
    final projects = await getProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index == -1) return;

    final oldProject = projects[index];

    // Renombrar carpeta si cambió el nombre
    if (oldProject.name != project.name) {
      final settings = await _settingsRepo.loadSettings();
      if (settings.rootFolder != null) {
        await _fileSystem.renameDirectory(
          '${settings.rootFolder}/${oldProject.name}',
          '${settings.rootFolder}/${project.name}',
        );
      }
    }

    // Si es predeterminado, quitar flag de los demás
    final updatedProjects = project.isDefault
        ? projects
              .map(
                (p) =>
                    p.id == project.id ? project : p.copyWith(isDefault: false),
              )
              .toList()
        : projects.map((p) => p.id == project.id ? project : p).toList();

    await _saveAll(updatedProjects);
  }

  @override
  Future<ProjectEntity?> getDefaultProject() async {
    final projects = await _projects;
    for (final project in projects) {
      if (project.isDefault) return project;
    }
    return projects.isNotEmpty ? projects.first : null;
  }

  /// Getter privado para simplificar acceso a proyectos cargados.
  Future<List<ProjectEntity>> get _projects => getProjects();

  @override
  Future<void> setDefaultProject(String projectId) async {
    final projects = await getProjects();
    final updatedProjects = projects
        .map(
          (p) => p.copyWith(isDefault: p.id == projectId),
        )
        .toList();
    await _saveAll(updatedProjects);
  }

  Future<void> _saveAll(List<ProjectEntity> projects) async {
    await _storage.setMapList(
      _projectsKey,
      projects.map(_toMap).toList(),
    );
  }

  ProjectEntity _fromMap(Map<String, dynamic> map) {
    return ProjectEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      alias: map['alias'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF1E88E5,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toMap(ProjectEntity project) {
    return {
      'id': project.id,
      'name': project.name,
      'alias': project.alias,
      'color': project.color,
      'isDefault': project.isDefault,
    };
  }
}
