import 'dart:convert';

import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';

/// Implementacion concreta del repositorio de proyectos.
///
/// Fuente de verdad:
/// - La carpeta real en disco (`folderPath`) define si un proyecto existe.
/// - SQLite solo persiste metadatos (alias, color, uso, default).
class ProjectRepository implements IProjectRepository {
  /// Crea una instancia de [ProjectRepository].
  ProjectRepository({
    required StorageService storageService,
    required FileSystemService fileSystemService,
  }) : _storage = storageService,
       _fileSystem = fileSystemService;

  static const String _projectsKey = 'projects';
  static const int _maxProjects = 3;
  static const List<int> _colorPalette = <int>[
    0xFF1E88E5,
    0xFF43A047,
    0xFFFB8C00,
    0xFF8E24AA,
    0xFF00897B,
    0xFF546E7A,
  ];

  final StorageService _storage;
  final FileSystemService _fileSystem;

  @override
  Future<List<ProjectEntity>> getProjects() async {
    return reconcileWithDisk();
  }

  @override
  Future<List<ProjectEntity>> reconcileWithDisk() async {
    await _storage.reloadFromDisk();
    final rawMaps = _storage.getMapList(_projectsKey);

    var projects = _hydrateProjects(rawMaps, legacyRootFolder: null);
    projects = await _filterExistingFolders(projects);
    projects = _dedupeByPath(projects);
    projects = _limitToThree(projects);
    projects = _normalizeDefaultFlags(projects);
    projects = _ensureDistinctColors(projects);

    if (_hasPersistedDifference(rawMaps, projects)) {
      await _saveAll(projects);
    }

    return projects;
  }

  @override
  Future<ProjectEntity?> addOrActivateFolder(String folderPath) async {
    final normalizedTarget = _normalizePath(folderPath);
    if (normalizedTarget.isEmpty) return null;

    final exists = await _fileSystem.directoryExists(normalizedTarget);
    if (!exists) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final projects = await reconcileWithDisk();
    final index = projects.indexWhere(
      (project) => _samePath(project.folderPath, normalizedTarget),
    );

    if (index >= 0) {
      final updated = List<ProjectEntity>.from(projects);
      final current = updated[index];
      updated[index] = current.copyWith(
        name: _nameFromPath(normalizedTarget),
        folderPath: normalizedTarget,
        usageCount: current.usageCount + 1,
        lastUsedAt: now,
        isDefault: true,
      );
      for (var i = 0; i < updated.length; i++) {
        if (i == index) continue;
        if (updated[i].isDefault) {
          updated[i] = updated[i].copyWith(isDefault: false);
        }
      }

      final normalized = _ensureDistinctColors(_normalizeDefaultFlags(updated));
      await _saveAll(normalized);
      return normalized.firstWhere((project) => project.id == current.id);
    }

    final next = _buildProjectFromFolder(
      folderPath: normalizedTarget,
      color: _nextAvailableColor(projects),
      nowEpoch: now,
      isDefault: true,
    );

    final updated = List<ProjectEntity>.from(projects);
    if (updated.length < _maxProjects) {
      updated.add(next);
    } else {
      final replaceIndex = _resolveLeastUsedIndex(updated);
      updated[replaceIndex] = next;
    }

    for (var i = 0; i < updated.length; i++) {
      final shouldDefault = updated[i].id == next.id;
      if (updated[i].isDefault != shouldDefault) {
        updated[i] = updated[i].copyWith(isDefault: shouldDefault);
      }
    }

    final normalized = _ensureDistinctColors(_normalizeDefaultFlags(updated));
    await _saveAll(normalized);
    return normalized.firstWhere((project) => project.id == next.id);
  }

  @override
  Future<ProjectEntity?> replaceProjectAt({
    required int slotIndex,
    required String folderPath,
  }) async {
    final normalizedTarget = _normalizePath(folderPath);
    if (normalizedTarget.isEmpty) return null;

    final exists = await _fileSystem.directoryExists(normalizedTarget);
    if (!exists) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final targetIndex = slotIndex.clamp(0, _maxProjects - 1);
    final projects = await reconcileWithDisk();
    final updated = List<ProjectEntity>.from(projects);

    final existingIndex = updated.indexWhere(
      (project) => _samePath(project.folderPath, normalizedTarget),
    );
    if (existingIndex >= 0) {
      final existing = updated
          .removeAt(existingIndex)
          .copyWith(
            name: _nameFromPath(normalizedTarget),
            folderPath: normalizedTarget,
          );
      final insertAt = targetIndex.clamp(0, updated.length);
      updated.insert(insertAt, existing);

      final normalized = _ensureDistinctColors(
        _normalizeDefaultFlags(
          updated.take(_maxProjects).toList(growable: false),
        ),
      );
      await _saveAll(normalized);
      if (normalized.isEmpty) return null;
      final resolvedIndex = insertAt.clamp(0, normalized.length - 1);
      return normalized[resolvedIndex];
    }

    final replacingExisting = targetIndex < updated.length;
    final keepDefault =
        updated.isEmpty ||
        (replacingExisting && updated[targetIndex].isDefault);

    final colorCandidatePool = List<ProjectEntity>.from(updated);
    if (replacingExisting) {
      colorCandidatePool.removeAt(targetIndex);
    }

    final replacement = _buildProjectFromFolder(
      folderPath: normalizedTarget,
      color: _nextAvailableColor(colorCandidatePool),
      nowEpoch: now,
      isDefault: keepDefault,
    );

    if (replacingExisting) {
      updated[targetIndex] = replacement;
    } else if (updated.length < _maxProjects) {
      updated.add(replacement);
    } else {
      updated[_maxProjects - 1] = replacement;
    }

    final normalized = _ensureDistinctColors(
      _normalizeDefaultFlags(
        updated.take(_maxProjects).toList(growable: false),
      ),
    );
    await _saveAll(normalized);

    if (normalized.isEmpty) return null;
    final resolvedIndex = targetIndex.clamp(0, normalized.length - 1);
    return normalized[resolvedIndex];
  }

  @override
  Future<void> markProjectUsed(String projectId) async {
    final projects = await reconcileWithDisk();
    final index = projects.indexWhere((project) => project.id == projectId);
    if (index < 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = List<ProjectEntity>.from(projects);
    final project = updated[index];
    updated[index] = project.copyWith(
      usageCount: project.usageCount + 1,
      lastUsedAt: now,
    );

    await _saveAll(_ensureDistinctColors(updated));
  }

  @override
  Future<ProjectEntity> createProject(ProjectEntity project) async {
    // Compatibilidad temporal para pruebas/llamadas legacy.
    final selected = await addOrActivateFolder(project.folderPath);
    if (selected == null) {
      return project;
    }

    final projects = await reconcileWithDisk();
    final index = projects.indexWhere((item) => item.id == selected.id);
    if (index < 0) return selected;

    final updated = List<ProjectEntity>.from(projects);
    updated[index] = updated[index].copyWith(
      alias: project.alias,
      color: project.color,
      isDefault: project.isDefault,
    );
    if (project.isDefault) {
      for (var i = 0; i < updated.length; i++) {
        if (i == index) continue;
        if (updated[i].isDefault) {
          updated[i] = updated[i].copyWith(isDefault: false);
        }
      }
    }

    final normalized = _ensureDistinctColors(_normalizeDefaultFlags(updated));
    await _saveAll(normalized);
    return normalized[index];
  }

  @override
  Future<void> updateProject(ProjectEntity project) async {
    final projects = await reconcileWithDisk();
    final index = projects.indexWhere((item) => item.id == project.id);
    if (index < 0) return;

    final existing = projects[index];
    final resolvedName = _nameFromPath(existing.folderPath);
    final updated = List<ProjectEntity>.from(projects);
    updated[index] = existing.copyWith(
      name: resolvedName,
      alias: project.alias,
      color: project.color,
      isDefault: project.isDefault,
    );

    if (project.isDefault) {
      for (var i = 0; i < updated.length; i++) {
        if (i == index) continue;
        if (updated[i].isDefault) {
          updated[i] = updated[i].copyWith(isDefault: false);
        }
      }
    }

    final normalized = _ensureDistinctColors(_normalizeDefaultFlags(updated));
    await _saveAll(normalized);
  }

  @override
  Future<ProjectEntity?> getDefaultProject() async {
    final projects = await reconcileWithDisk();
    for (final project in projects) {
      if (project.isDefault) return project;
    }
    return projects.isEmpty ? null : projects.first;
  }

  @override
  Future<void> setDefaultProject(String projectId) async {
    final projects = await reconcileWithDisk();
    if (projects.isEmpty) return;

    final updated = projects
        .map((project) => project.copyWith(isDefault: project.id == projectId))
        .toList(growable: false);
    await _saveAll(_ensureDistinctColors(_normalizeDefaultFlags(updated)));
  }

  List<ProjectEntity> _hydrateProjects(
    List<Map<String, dynamic>> maps, {
    required String? legacyRootFolder,
  }) {
    final projects = <ProjectEntity>[];
    for (var i = 0; i < maps.length; i++) {
      final map = maps[i];
      final parsed = _fromMap(
        map,
        indexSeed: i,
        legacyRootFolder: legacyRootFolder,
      );
      if (parsed != null) {
        projects.add(parsed);
      }
    }
    return projects;
  }

  ProjectEntity? _fromMap(
    Map<String, dynamic> map, {
    required int indexSeed,
    required String? legacyRootFolder,
  }) {
    final legacyName = (map['name'] as String? ?? '').trim();
    var folderPath = (map['folderPath'] as String? ?? '').trim();
    if (folderPath.isEmpty &&
        legacyRootFolder != null &&
        legacyRootFolder.trim().isNotEmpty &&
        legacyName.isNotEmpty) {
      folderPath = '${legacyRootFolder.trim()}/$legacyName';
    }

    final normalizedFolder = _normalizePath(folderPath);
    if (normalizedFolder.isEmpty) return null;

    final resolvedName = _nameFromPath(normalizedFolder);
    final idRaw = (map['id'] as String? ?? '').trim();
    final id = idRaw.isEmpty
        ? 'project_${_sanitizeId(normalizedFolder)}'
        : idRaw;

    return ProjectEntity(
      id: id,
      name: resolvedName,
      folderPath: normalizedFolder,
      alias: _normalizeAlias(
        (map['alias'] as String? ?? '').trim(),
        fallbackName: resolvedName,
      ),
      color: (map['color'] as int?) ?? _colorByIndex(indexSeed),
      isDefault: (map['isDefault'] as bool?) ?? false,
      usageCount: _parseInt(map['usageCount']) ?? 0,
      lastUsedAt: _parseInt(map['lastUsedAt']) ?? 0,
    );
  }

  Future<List<ProjectEntity>> _filterExistingFolders(
    List<ProjectEntity> projects,
  ) async {
    final filtered = <ProjectEntity>[];
    for (final project in projects) {
      if (await _fileSystem.directoryExists(project.folderPath)) {
        filtered.add(
          project.copyWith(
            name: _nameFromPath(project.folderPath),
          ),
        );
      }
    }
    return filtered;
  }

  List<ProjectEntity> _dedupeByPath(List<ProjectEntity> projects) {
    final byPath = <String, ProjectEntity>{};
    for (final project in projects) {
      final key = _normalizePath(project.folderPath).toLowerCase();
      final existing = byPath[key];
      if (existing == null) {
        byPath[key] = project;
        continue;
      }

      final merged = existing.copyWith(
        isDefault: existing.isDefault || project.isDefault,
        usageCount: existing.usageCount > project.usageCount
            ? existing.usageCount
            : project.usageCount,
        lastUsedAt: existing.lastUsedAt > project.lastUsedAt
            ? existing.lastUsedAt
            : project.lastUsedAt,
      );
      byPath[key] = merged;
    }
    return byPath.values.toList(growable: false);
  }

  List<ProjectEntity> _limitToThree(List<ProjectEntity> projects) {
    if (projects.length <= _maxProjects) {
      return projects;
    }

    final sorted = List<ProjectEntity>.from(projects)
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }

        final usage = b.usageCount.compareTo(a.usageCount);
        if (usage != 0) return usage;

        final recent = b.lastUsedAt.compareTo(a.lastUsedAt);
        if (recent != 0) return recent;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sorted.take(_maxProjects).toList(growable: false);
  }

  int _resolveLeastUsedIndex(List<ProjectEntity> projects) {
    var candidateIndex = 0;
    for (var i = 1; i < projects.length; i++) {
      final candidate = projects[candidateIndex];
      final current = projects[i];

      if (current.usageCount < candidate.usageCount) {
        candidateIndex = i;
        continue;
      }
      if (current.usageCount > candidate.usageCount) {
        continue;
      }

      if (current.lastUsedAt < candidate.lastUsedAt) {
        candidateIndex = i;
      }
    }
    return candidateIndex;
  }

  List<ProjectEntity> _normalizeDefaultFlags(List<ProjectEntity> projects) {
    if (projects.isEmpty) return projects;

    var defaultIndex = projects.indexWhere((project) => project.isDefault);
    if (defaultIndex < 0) defaultIndex = 0;

    return projects
        .asMap()
        .entries
        .map((entry) {
          final shouldDefault = entry.key == defaultIndex;
          final project = entry.value;
          if (project.isDefault == shouldDefault) {
            return project;
          }
          return project.copyWith(isDefault: shouldDefault);
        })
        .toList(growable: false);
  }

  Future<void> _saveAll(List<ProjectEntity> projects) async {
    await _storage.setMapList(
      _projectsKey,
      projects.map(_toMap).toList(growable: false),
    );
  }

  bool _hasPersistedDifference(
    List<Map<String, dynamic>> persisted,
    List<ProjectEntity> next,
  ) {
    final nextMaps = next.map(_toMap).toList(growable: false);
    return jsonEncode(persisted) != jsonEncode(nextMaps);
  }

  Map<String, dynamic> _toMap(ProjectEntity project) {
    return <String, dynamic>{
      'id': project.id,
      'name': project.name,
      'folderPath': project.folderPath,
      'alias': project.alias,
      'color': project.color,
      'isDefault': project.isDefault,
      'usageCount': project.usageCount,
      'lastUsedAt': project.lastUsedAt,
    };
  }

  ProjectEntity _buildProjectFromFolder({
    required String folderPath,
    required int color,
    required int nowEpoch,
    required bool isDefault,
  }) {
    final name = _nameFromPath(folderPath);
    return ProjectEntity(
      id: 'project_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      folderPath: folderPath,
      alias: _buildAlias(name),
      color: color,
      isDefault: isDefault,
      usageCount: 1,
      lastUsedAt: nowEpoch,
    );
  }

  List<ProjectEntity> _ensureDistinctColors(List<ProjectEntity> projects) {
    if (projects.isEmpty) return projects;

    final used = <int>{};
    final updated = <ProjectEntity>[];

    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      var color = project.color;
      if (used.contains(color)) {
        color = _nextAvailableColor(updated);
      }
      used.add(color);
      if (color == project.color) {
        updated.add(project);
      } else {
        updated.add(project.copyWith(color: color));
      }
    }

    return updated;
  }

  int _nextAvailableColor(List<ProjectEntity> existingProjects) {
    for (final color in _colorPalette) {
      final alreadyUsed = existingProjects.any(
        (project) => project.color == color,
      );
      if (!alreadyUsed) return color;
    }
    return _colorByIndex(existingProjects.length);
  }

  String _normalizePath(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(r'\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _nameFromPath(String path) {
    final normalized = _normalizePath(path);
    final pieces = normalized.split('/');
    if (pieces.isEmpty) return normalized;
    final name = pieces.last.trim();
    return name.isEmpty ? normalized : name;
  }

  bool _samePath(String left, String right) {
    return _normalizePath(left).toLowerCase() ==
        _normalizePath(right).toLowerCase();
  }

  int? _parseInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _normalizeAlias(String alias, {required String fallbackName}) {
    final cleanAlias = alias.trim().toUpperCase();
    if (cleanAlias.length >= 2 && cleanAlias.length <= 4) {
      return cleanAlias;
    }
    return _buildAlias(fallbackName);
  }

  String _buildAlias(String name) {
    final clean = name.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return 'PRY';
    final size = clean.length < 3 ? clean.length : 3;
    return clean.substring(0, size).toUpperCase();
  }

  String _sanitizeId(String value) {
    return value.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
  }

  int _colorByIndex(int index) {
    return _colorPalette[index % _colorPalette.length];
  }
}
