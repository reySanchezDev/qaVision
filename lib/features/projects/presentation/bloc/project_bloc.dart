import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';

/// BLoC para la gestión de proyectos.
///
/// Maneja la carga, creación, edición y establecimiento
/// de proyectos como predeterminados (§5).
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  /// Crea una instancia de [ProjectBloc].
  ProjectBloc({required IProjectRepository repository})
    : _repository = repository,
      super(const ProjectInitial()) {
    on<ProjectsLoaded>(_onLoaded);
    on<ProjectCreated>(_onCreated);
    on<ProjectUpdated>(_onUpdated);
    on<ProjectSetDefault>(_onSetDefault);
  }

  final IProjectRepository _repository;

  Future<void> _onLoaded(
    ProjectsLoaded event,
    Emitter<ProjectState> emit,
  ) async {
    emit(const ProjectLoading());
    try {
      final projects = await _repository.getProjects();
      emit(ProjectLoadSuccess(projects));
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
      final projects = await _repository.getProjects();
      emit(ProjectLoadSuccess(projects));
    } on Exception catch (e) {
      emit(ProjectError('Error al crear proyecto: $e', exception: e));
    }
  }

  Future<void> _onUpdated(
    ProjectUpdated event,
    Emitter<ProjectState> emit,
  ) async {
    try {
      await _repository.updateProject(event.project);
      final projects = await _repository.getProjects();
      emit(ProjectLoadSuccess(projects));
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
      final projects = await _repository.getProjects();
      emit(ProjectLoadSuccess(projects));
    } on Exception catch (e) {
      emit(
        ProjectError(
          'Error al establecer predeterminado: $e',
          exception: e,
        ),
      );
    }
  }
}
