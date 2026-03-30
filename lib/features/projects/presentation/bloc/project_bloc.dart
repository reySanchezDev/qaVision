import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/projects/data/services/project_folder_watch_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';

/// BLoC para la gestión de proyectos.
///
/// Maneja la carga, creación, edición y establecimiento
/// de proyectos como predeterminados (§5).
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  /// Crea una instancia de [ProjectBloc].
  ProjectBloc({
    required IProjectRepository repository,
    Stream<void>? externalChanges,
    ProjectFolderWatchService? folderWatchService,
  }) : _repository = repository,
       _folderWatchService = folderWatchService,
       super(const ProjectInitial()) {
    on<ProjectsLoaded>(_onLoaded);
    on<ProjectsStorageSynced>(_onStorageSynced);
    on<ProjectsFilesystemSynced>(_onFilesystemSynced);
    on<ProjectFolderSelected>(_onFolderSelected);
    on<ProjectFolderReplacedAt>(_onFolderReplacedAt);
    on<ProjectFolderMovedDetected>(_onFolderMovedDetected);
    on<ProjectCreated>(_onCreated);
    on<ProjectUpdated>(_onUpdated);
    on<ProjectSetDefault>(_onSetDefault);

    if (externalChanges != null) {
      _externalChangesSubscription = externalChanges.listen((_) {
        add(const ProjectsStorageSynced());
      });
    }

    final watchService = _folderWatchService;
    if (watchService != null) {
      _filesystemChangesSubscription = watchService.changes.listen((change) {
        if (change.type == ProjectFolderChangeType.moved &&
            change.oldPath != null &&
            change.newPath != null) {
          add(
            ProjectFolderMovedDetected(
              oldPath: change.oldPath!,
              newPath: change.newPath!,
            ),
          );
          return;
        }
        add(const ProjectsFilesystemSynced());
      });
    }
  }

  final IProjectRepository _repository;
  final ProjectFolderWatchService? _folderWatchService;
  StreamSubscription<void>? _externalChangesSubscription;
  StreamSubscription<ProjectFolderChangeEvent>? _filesystemChangesSubscription;

  @override
  Future<void> close() async {
    await _externalChangesSubscription?.cancel();
    await _filesystemChangesSubscription?.cancel();
    await _folderWatchService?.dispose();
    return super.close();
  }

  Future<void> _onLoaded(
    ProjectsLoaded event,
    Emitter<ProjectState> emit,
  ) async {
    emit(const ProjectLoading());
    try {
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(ProjectError('Error al cargar proyectos: $e', exception: e));
    }
  }

  Future<void> _onCreated(
    ProjectCreated event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.createProject(event.project);
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(ProjectError('Error al crear proyecto: $e', exception: e));
    }
  }

  Future<void> _onStorageSynced(
    ProjectsStorageSynced event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      final projects = await _repository.reconcileWithDisk();
      final currentState = state;
      if (currentState is ProjectLoadSuccess &&
          listEquals(currentState.projects, projects)) {
        await _restartFilesystemWatch(projects);
        return;
      }
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      if (state is! ProjectLoadSuccess) {
        emit(ProjectError('Error al sincronizar proyectos: $e', exception: e));
      }
    }
  }

  Future<void> _onFilesystemSynced(
    ProjectsFilesystemSynced event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      final projects = await _repository.reconcileWithDisk();
      final currentState = state;
      if (currentState is ProjectLoadSuccess &&
          listEquals(currentState.projects, projects)) {
        await _restartFilesystemWatch(projects);
        return;
      }
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      if (state is! ProjectLoadSuccess) {
        emit(ProjectError('Error al sincronizar filesystem: $e', exception: e));
      }
    }
  }

  Future<void> _onFolderSelected(
    ProjectFolderSelected event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.addOrActivateFolder(event.folderPath);
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(ProjectError('Error al seleccionar carpeta: $e', exception: e));
    }
  }

  Future<void> _onFolderReplacedAt(
    ProjectFolderReplacedAt event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.replaceProjectAt(
        slotIndex: event.slotIndex,
        folderPath: event.folderPath,
      );
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(ProjectError('Error al reemplazar carpeta: $e', exception: e));
    }
  }

  Future<void> _onFolderMovedDetected(
    ProjectFolderMovedDetected event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.reconcileWithDisk();
      await _repository.addOrActivateFolder(event.newPath);
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      if (state is! ProjectLoadSuccess) {
        emit(ProjectError('Error al aplicar rename/move: $e', exception: e));
      }
    }
  }

  Future<void> _onUpdated(
    ProjectUpdated event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.updateProject(event.project);
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(ProjectError('Error al actualizar proyecto: $e', exception: e));
    }
  }

  Future<void> _onSetDefault(
    ProjectSetDefault event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.setDefaultProject(event.projectId);
      final projects = await _repository.reconcileWithDisk();
      emit(ProjectLoadSuccess(projects));
      await _restartFilesystemWatch(projects);
    } on Exception catch (e) {
      emit(
        ProjectError(
          'Error al establecer predeterminado: $e',
          exception: e,
        ),
      );
    }
  }

  Future<void> _restartFilesystemWatch(List<ProjectEntity> projects) async {
    final watchService = _folderWatchService;
    if (watchService == null) return;

    final paths = <String>[for (final project in projects) project.folderPath];
    await watchService.updateTrackedFolders(paths);
  }
}
